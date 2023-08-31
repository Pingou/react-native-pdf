/**
 * Copyright (c) 2017-present, Wonday (@wonday.org)
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

'use strict';
import React, {Component} from 'react';
import PropTypes from 'prop-types';
import { ViewPropTypes } from 'deprecated-react-native-prop-types'; 
import {
    requireNativeComponent,
    NativeModules,
    View,
    Platform,
    ProgressBarAndroid,
    StyleSheet,
    Dimensions
} from 'react-native';

import ReactNativeBlobUtil from 'react-native-blob-util'

const SHA1 = require('crypto-js/sha1');
import resolveAssetSource from 'react-native/Libraries/Image/resolveAssetSource';
import PdfView from './PdfView';
import { UIManager, findNodeHandle } from "react-native"


export default class Pdf extends Component {

    static propTypes = {
        ...ViewPropTypes,
        source: PropTypes.oneOfType([
            PropTypes.shape({
                uri: PropTypes.string,
                cache: PropTypes.bool,
                expiration: PropTypes.number,
            }),
            // Opaque type returned by require('./test.pdf')
            PropTypes.number,
        ]).isRequired,
        singlePage: PropTypes.bool,
        page: PropTypes.number,
        scale: PropTypes.number,
        minScale: PropTypes.number,
        maxScale: PropTypes.number,
        horizontal: PropTypes.bool,
        spacing: PropTypes.number,
        password: PropTypes.string,
        progressBarColor: PropTypes.string,
        activityIndicator: PropTypes.any,
        activityIndicatorProps: PropTypes.any,
        enableAntialiasing: PropTypes.bool,
        enableAnnotationRendering: PropTypes.bool,
        enablePaging: PropTypes.bool,
        enableRTL: PropTypes.bool,
        fitPolicy: PropTypes.number,
	
        onLoadComplete: PropTypes.func,
        onPageChanged: PropTypes.func,
        onError: PropTypes.func,
        onPageSingleTap: PropTypes.func,
        onScaleChanged: PropTypes.func,
        onPositionChanged:  PropTypes.func,
        onIosPositionChanged:  PropTypes.func,
        onAnnotationClicked:  PropTypes.func,
        onLongClick:  PropTypes.func,
        restoreViewState: PropTypes.string,
    onPressLink: PropTypes.func,
        // Props that are not available in the earlier react native version, added to prevent crashed on android
        accessibilityLabel: PropTypes.string,
        importantForAccessibility: PropTypes.string,
        renderToHardwareTextureAndroid: PropTypes.string,
        testID: PropTypes.string,
        onLayout: PropTypes.bool,
        accessibilityLiveRegion: PropTypes.string,
        accessibilityComponentType: PropTypes.string,
        annotations: PropTypes.array,
        highlightLines: PropTypes.array,
        chartStart: PropTypes.string,
        chartEnd: PropTypes.string,
        showPagesNav: PropTypes.bool,
        enableDarkMode: PropTypes.bool,
        drawings: PropTypes.array,
        chartHighlights: PropTypes.array,
    };

    static defaultProps = {
        password: "",
        scale: 1,
        minScale: 1,
        maxScale: 3,
        spacing: 10,
        fitPolicy: 2, //fit both
        horizontal: false,
        singlePage: false,
        page: 1,
        enableAntialiasing: true,
        enableAnnotationRendering: true,
        enablePaging: false,
        enableDarkMode: false,
        enableRTL: false,
        activityIndicatorProps: {color: '#009900', progressTintColor: '#009900'},
        restoreViewState: "",
        annotations: [],
        drawings: [],
        highlightLines: [],
        chartHighlights: [],
        chartStart: "",
        chartEnd: "",
        showPagesNav: false,
        chartHighlights: [],
        onLoadProgress: (percent) => {
        },
        onLoadComplete: (numberOfPages, path, dims, annotationsDisabled) => {
        },
        onPageChanged: (page, numberOfPages) => {
        },
        onError: (error) => {
        },
        onPageSingleTap: (page, x, y) => {
        },
        onScaleChanged: (scale) => {
        },

        onPositionChanged: (currentPage, pageFocusX, pageFocusY, zoom, positionOffset) => {
        },

        onIosPositionChanged: (currentPage, x, y, width, height, zoom) => {
        },

        onAnnotationClicked: (uniqueIdOnClient) => {

        },
        onLongClick: (x, y, page, canAddAnnotation) => {
        },
        onSimpleClick: (x, y, page) => {
        },
    onPressLink: (url) => {
        },
    };



    


    constructor(props) {

        super(props);
        this.state = {
            path: '',
            isDownloaded: false,
            progress: 0,
            isSupportPDFKit: -1
        };

        this.lastRNBFTask = null;

    }

    componentWillReceiveProps(nextProps) {

        const nextSource = resolveAssetSource(nextProps.source);
        const curSource = resolveAssetSource(this.props.source);

        if ((nextSource.uri !== curSource.uri)) {
            // if has download task, then cancel it.
            if (this.lastRNBFTask) {
                this.lastRNBFTask.cancel(err => {
                    this._loadFromSource(nextProps.source);
                });
                this.lastRNBFTask = null;
            } else {
                this._loadFromSource(nextProps.source);
            }
        }
    }

    componentDidMount() {
        if (Platform.OS === "ios") {
            const PdfViewManagerNative = require('react-native').NativeModules.PdfViewManager;
            PdfViewManagerNative.supportPDFKit((isSupportPDFKit) => {
                this.setState({isSupportPDFKit: isSupportPDFKit ? 1 : 0});
            });
        }
        this._loadFromSource(this.props.source);
    }

    componentWillUnmount() {

        if (this.lastRNBFTask) {
            this.lastRNBFTask.cancel(err => {
            });
            this.lastRNBFTask = null;
        }

    }

    _loadFromSource = (newSource) => {

        const source = resolveAssetSource(newSource) || {};

        let uri = source.uri || '';

        // first set to initial state
        this.setState({isDownloaded: false, path: '', progress: 0});

        const cacheFile = ReactNativeBlobUtil.fs.dirs.CacheDir + '/' + SHA1(uri) + '.pdf';

        if (source.cache) {
            ReactNativeBlobUtil.fs
                .stat(cacheFile)
                .then(stats => {
                    if (!Boolean(source.expiration) || (source.expiration * 1000 + stats.lastModified) > (new Date().getTime())) {
                        this.setState({path: cacheFile, isDownloaded: true});
                    } else {
                        // cache expirated then reload it
                        this._prepareFile(source);
                    }
                })
                .catch(() => {
                    this._prepareFile(source);
                })

        } else {
            this._prepareFile(source);
        }
    };

    _prepareFile = async (source) => {

        try {
            if (source.uri) {
                let uri = source.uri || '';

                const isNetwork = !!(uri && uri.match(/^https?:\/\//));
                const isAsset = !!(uri && uri.match(/^bundle-assets:\/\//));
                const isBase64 = !!(uri && uri.match(/^data:application\/pdf;base64/));

                const cacheFile = ReactNativeBlobUtil.fs.dirs.CacheDir + '/' + SHA1(uri) + '.pdf';

                // delete old cache file
                this._unlinkFile(cacheFile);

                if (isNetwork) {
                    this._downloadFile(source, cacheFile);
                } else if (isAsset) {
                    ReactNativeBlobUtil.fs
                        .cp(uri, cacheFile)
                        .then(() => {
                            this.setState({path: cacheFile, isDownloaded: true, progress: 1});
                        })
                        .catch(async (error) => {
                            this._unlinkFile(cacheFile);
                            this._onError(error);
                        })
                } else if (isBase64) {
                    let data = uri.replace(/data:application\/pdf;base64,/i, '');
                    ReactNativeBlobUtil.fs
                        .writeFile(cacheFile, data, 'base64')
                        .then(() => {
                            this.setState({path: cacheFile, isDownloaded: true, progress: 1});
                        })
                        .catch(async (error) => {
                            this._unlinkFile(cacheFile);
                            this._onError(error)
                        });
                } else {
                    this.setState({
                        path: uri.replace(/file:\/\//i, ''),
                        isDownloaded: true,
                    });
                }
            } else {
                this._onError(new Error('no pdf source!'));
            }
        } catch (e) {
            this._onError(e)
        }


    };

    _downloadFile = async (source, cacheFile) => {

        if (this.lastRNBFTask) {
            this.lastRNBFTask.cancel(err => {
            });
            this.lastRNBFTask = null;
        }

        const tempCacheFile = cacheFile + '.tmp';
        this._unlinkFile(tempCacheFile);

        this.lastRNBFTask = ReactNativeBlobUtil.config({
            // response data will be saved to this path if it has access right.
            path: tempCacheFile,
            trusty: true,
        })
            .fetch(
                source.method ? source.method : 'GET',
                source.uri,
                source.headers ? source.headers : {},
                source.body ? source.body : ""
            )
            // listen to download progress event
            .progress((received, total) => {
                this.props.onLoadProgress && this.props.onLoadProgress(received / total);
                this.setState({progress: received / total});
            });

        this.lastRNBFTask
            .then(async (res) => {

                this.lastRNBFTask = null;

                if (res && res.respInfo && res.respInfo.headers && !res.respInfo.headers["Content-Encoding"] && !res.respInfo.headers["Transfer-Encoding"] && res.respInfo.headers["Content-Length"]) {
                    const expectedContentLength = res.respInfo.headers["Content-Length"];
                    let actualContentLength;

                    try {
                        const fileStats = await ReactNativeBlobUtil.fs.stat(res.path());

                        if (!fileStats || !fileStats.size) {
                            throw new Error("FileNotFound:" + url);
                        }

                        actualContentLength = fileStats.size;
                    } catch (error) {
                        throw new Error("DownloadFailed:" + url);
                    }

                    if (expectedContentLength != actualContentLength) {
                        throw new Error("DownloadFailed:" + url);
                    }
                }

                this._unlinkFile(cacheFile);
                ReactNativeBlobUtil.fs
                    .cp(tempCacheFile, cacheFile)
                    .then(() => {
                        this.setState({path: cacheFile, isDownloaded: true, progress: 1});
                        this._unlinkFile(tempCacheFile);
                    })
                    .catch(async (error) => {
                        throw error;
                    });
            })
            .catch(async (error) => {
                this._unlinkFile(tempCacheFile);
                this._unlinkFile(cacheFile);
                this._onError(error);
            });

    };

    _unlinkFile = async (file) => {
        try {
            await ReactNativeBlobUtil.fs.unlink(file);
        } catch (e) {

        }
    }

    setNativeProps = nativeProps => {
        if (this._root){
            this._root.setNativeProps(nativeProps);
        }
    };

    setPage( pageNumber ) {
        if ( (pageNumber === null) || (isNaN(pageNumber)) ) {
            throw new Error('Specified pageNumber is not a number');
        }
        this.setNativeProps({
            page: pageNumber
        });
    }

    getConvertedPoints(pointsIn, callback) {


        if (Platform.OS === "ios") {
            const PdfViewManagerNative = require('react-native').NativeModules.PdfViewManager;
             PdfViewManagerNative.getConvertedPoints(pointsIn, (points) => {
               // alert(JSON.stringify(points))
                callback(points)
            });
        }
        else {
             UIManager.dispatchViewManagerCommand(
                    findNodeHandle(this._root),
                    UIManager.RCTPdf.Commands.getConvertedPoints,
                    [pointsIn],
                );
        }
    
        
       
    }

    setHighlighterPos(isVertical, posPercent, pageNb) {
        if (Platform.OS === "ios") {
            const PdfViewManagerNative = require('react-native').NativeModules.PdfViewManager;
             PdfViewManagerNative.setHighlighterPos(isVertical, posPercent, pageNb);
        }
        else {
             UIManager.dispatchViewManagerCommand(
                    findNodeHandle(this._root),
                    UIManager.RCTPdf.Commands.setHighlighterPos,
                    [isVertical, posPercent, pageNb],
                );
        }
    }

    _onChange = (event) => {

        let message = event.nativeEvent.message.split('|');

       
        __DEV__ && console.log("onChange: " + message);
        if (message.length > 0) {



            if (message[0] === 'pointsConverted') {

                  //  console.log("positionChanged", Number(message[1]), Number(message[2]), Number(message[3]), Number(message[4]), Number(message[5]))
                 this.props.onPointsConverted && this.props.onPointsConverted(message[1]);
               // alert(message[1])
            }
            if (message[0] === 'positionChanged') {

                  //  console.log("positionChanged", Number(message[1]), Number(message[2]), Number(message[3]), Number(message[4]), Number(message[5]))
                 this.props.onPositionChanged && this.props.onPositionChanged(Number(message[1]), Number(message[2]), Number(message[3]), Number(message[4]), Number(message[5]), Number(message[6]), Number(message[7]), Number(message[8]), Number(message[9]), Number(message[10]), Number(message[11]));
               // alert(message[1])
            }
            else if (message[0] === 'iosPositionChanged') {
                    console.log('iosPositionChanged', message)
                    this.props.onIosPositionChanged && this.props.onIosPositionChanged(Number(message[1]), Number(message[2]), Number(message[3]), Number(message[4]), Number(message[5]), Number(message[6]), Number(message[7]), Number(message[8]), Number(message[9]), Number(message[10]), Number(message[11]) );
                }
            else {
                if (message.length > 5 && message[0] !== 'loadComplete') {
                    message[4] = message.splice(4).join('|');
                }

                if (message[0] === 'loadComplete') {

                    var title = {}
                    if (message[5]) {
                        try {
                            title = JSON.parse(message[5])
                        }
                        catch {
                  
                        }
                    }
                   
                    this.props.onLoadComplete && this.props.onLoadComplete(Number(message[1]), this.state.path, {
                        width: Number(message[2]),
                        height: Number(message[3]),
                    },
                    message[4]&&Number(message[4]),
                    message[5]&&title);
                } else if (message[0] === 'pageChanged') {
                    this.props.onPageChanged && this.props.onPageChanged(Number(message[1]), Number(message[2]));
                } else if (message[0] === 'error') {
                    this._onError(new Error(message[1]));
                } else if (message[0] === 'pageSingleTap') {
                    this.props.onPageSingleTap && this.props.onPageSingleTap(Number(message[1]), Number(message[2]), Number(message[3]));
                } else if (message[0] === 'scaleChanged') {
                    this.props.onScaleChanged && this.props.onScaleChanged(message[1]);
                }
                else if (message[0] === 'longClick') {
                    
                    var canAddAnnotation = true
                    if (message.length > 4) {
                        canAddAnnotation = Number(message[4]) != 1 ? false : true
                    }
                    this.props.onLongClick && this.props.onLongClick(Number(message[1]), Number(message[2]), Number(message[3]), canAddAnnotation);
                }
                else if (message[0] === 'onSwitchPage') {
                    this.props.onSwitchPage && this.props.onSwitchPage(Number(message[1]));
                }
                else if (message[0] === 'onEditChart') {
                    this.props.onEditChart && this.props.onEditChart(message[1]);
                }
                
                 else if (message[0] === 'simpleClick') {
                    this.props.onSimpleClick && this.props.onSimpleClick(Number(message[1]), Number(message[2]), Number(message[3]), Number(message[4]));
                }

                else if (message[0] === 'annotationClicked') {

                   // alert(1)
                    this.props.onAnnotationClicked && this.props.onAnnotationClicked(message[1]);
                }
         else if (message[0] === 'linkPressed') {
                this.props.onPressLink && this.props.onPressLink(message[1]);
            }




            }
        }

    };

    _onError = (error) => {

        this.props.onError && this.props.onError(error);

    };

    render() {


        var style
        var translationStyle = {}

        if (this.props.rotated && this.props.myViewWidth > 0) {

         var viewWidth = this.props.myViewWidth
         var viewHeight = this.props.myViewHeight


            style = [{width: viewWidth , height: viewHeight, margin: 0, padding:0
          , overflow: 'hidden'}]

          translationStyle = { width: viewHeight , height: viewWidth, transform: [
          
          { rotate: "90deg" },

          { translateY: ((viewHeight / 2) - (viewWidth / 2))  },
          { translateX: ((viewHeight / 2) - (viewWidth / 2))  },


          ]}
        }
        else {
        //attention ne pas mettre flex 1 ici ou dessous ca fout la merde quand on tourne
            style = [this.props.style,{overflow: 'hidden'}]
        }


        if (Platform.OS === "android" || Platform.OS === "ios") {
                return (
                    <View style={style}>
                        {!this.state.isDownloaded?
                            (<View
                                style={styles.progressContainer}
                            >
                                {this.props.activityIndicator
                                    ? this.props.activityIndicator
                                    : Platform.OS === 'android'
                                        ? <ProgressBarAndroid
                                            progress={this.state.progress}
                                            indeterminate={false}
                                            styleAttr="Horizontal"
                                            style={styles.progressBar}
                                            {...this.props.activityIndicatorProps}
                                        />
                                        : <View></View>}
                            </View>):(
                                Platform.OS === "android"?(
                                        <PdfCustom
                                            ref={component => (this._root = component)}
                                            {...this.props}
                                            style={[{backgroundColor: '#EEE',overflow: 'hidden'}, style, translationStyle]}
                                            path={this.state.path}
                                            onChange={this._onChange}
                                        />
                                    ):(
                                        this.state.isSupportPDFKit === 1?(
                                                <PdfCustom
                                                    ref={component => (this._root = component)}
                                                    {...this.props}
                                                    style={[{backgroundColor: '#EEE',overflow: 'hidden'}, style, translationStyle]}
                                                    path={this.state.path}
                                                    onChange={this._onChange}
                                                />
                                            ):(<PdfView
                                                {...this.props}
                                                style={[{backgroundColor: '#EEE',overflow: 'hidden'}, style, translationStyle]}
                                                path={this.state.path}
                                                onLoadComplete={this.props.onLoadComplete}
                                                onPageChanged={this.props.onPageChanged}
                                                onError={this._onError}
                                                onPageSingleTap={this.props.onPageSingleTap}
                                                onScaleChanged={this.props.onScaleChanged}
                        onPressLink={this.props.onPressLink}
                                            />)
                                    )
                                )}
                    </View>);
        } else {
            return (null);
        }


    }
}


if (Platform.OS === "android") {
    var PdfCustom = requireNativeComponent('RCTPdf', Pdf, {
        nativeOnly: {path: true, onChange: true},
    })
} else if (Platform.OS === "ios") {
    var PdfCustom = requireNativeComponent('RCTPdfView', Pdf, {
        nativeOnly: {path: true, onChange: true},
    })
}


const styles = StyleSheet.create({
    progressContainer: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center'
    },
    progressBar: {
        width: 200,
        height: 2
    }
});
