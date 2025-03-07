/**
 * Copyright (c) 2017-present, Wonday (@wonday.org)
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

package org.wonday.pdf;

import java.io.File;

import android.content.Context;
import android.view.ViewGroup;
import android.util.Log;
import android.graphics.PointF;
import android.net.Uri;

import androidx.annotation.Nullable;

import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.facebook.react.uimanager.events.RCTEventEmitter;
import com.facebook.react.common.MapBuilder;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import static java.lang.String.format;

import java.io.IOException;
import java.lang.ClassCastException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.github.barteksc.pdfviewer.util.FitPolicy;

public class RCTPdfManager extends SimpleViewManager<PdfView> {
    private static final String REACT_CLASS = "RCTPdf";
    private Context context;
    private PdfView pdfView;
    public static final int COMMAND_CONVERT_POINTS = 9549211;

    public static final int COMMAND_SET_HIGHLIGHTER_POS = 9549212;

    public static final int COMMAND_CONVERT_POINTS_ARRAY = 9549213;

    public static final int COMMAND_SET_DRAWINGS_DYNAMICALLY = 9549214;

    public RCTPdfManager(ReactApplicationContext reactContext){
        this.context = reactContext;
    }

    @Override
    public String getName() {
        return REACT_CLASS;
    }

    @Override
    public PdfView createViewInstance(ThemedReactContext context) {
        this.pdfView = new PdfView(context,null);
        return pdfView;
    }

    @Override
    public void onDropViewInstance(PdfView pdfView) {
        pdfView = null;
    }
/*
    @ReactProp(name = "getConvertedPoints")
    public void setSaveImageFileInExtStorage(PdfView view, String jsonInput) {
        //String output = view.convertPoints(jsonInput);
    }
*/
    @Override
    public Map<String,Integer> getCommandsMap() {

        HashMap map = new HashMap<String, Integer>();
        map.put("getConvertedPoints", COMMAND_CONVERT_POINTS);
        map.put("getConvertedPointsArray", COMMAND_CONVERT_POINTS_ARRAY);
        map.put("setHighlighterPos", COMMAND_SET_HIGHLIGHTER_POS);
        map.put("setDrawingsDynamically", COMMAND_SET_DRAWINGS_DYNAMICALLY);

        return map;
        //Log.d("React"," View manager getCommandsMap:");
      /*  return MapBuilder.of(
                "getConvertedPoints",
                COMMAND_CONVERT_POINTS);*/
    }

    @Override
    public void receiveCommand(
            PdfView view,
            int commandType,
            @Nullable ReadableArray args) {


        switch (commandType) {
            case COMMAND_CONVERT_POINTS: {
                view.convertPoints(args.getString(0));
                return;
            }
            case COMMAND_CONVERT_POINTS_ARRAY: {
                view.convertPointsArray(args.getString(0));
                return;
            }
            case COMMAND_SET_HIGHLIGHTER_POS: {
                view.setHighlighterPos(args.getInt(0), (float)args.getDouble(1), args.getInt(2));
                return;
            }
            case COMMAND_SET_DRAWINGS_DYNAMICALLY: {
                view.setDrawingsDynamically(args.getArray(0));
                return;
            }

            default:
                throw new IllegalArgumentException(String.format(
                        "Unsupported command %d received by %s.",
                        commandType,
                        getClass().getSimpleName()));
        }
    }

/*
    @ReactMethod
    public void getConvertedPoints(String jsonInput, Callback callback) {
        String output = this.pdfView.convertPoints(jsonInput);

        callback.invoke(output);
    }*/

    @ReactProp(name = "path")
    public void setPath(PdfView pdfView, String path) {
        pdfView.setPath(path);
    }

    // page start from 1
    @ReactProp(name = "page")
    public void setPage(PdfView pdfView, int page) {
        pdfView.setPage(page);
    }

    @ReactProp(name = "scale")
    public void setScale(PdfView pdfView, float scale) {
        pdfView.setScale(scale);
    }

    @ReactProp(name = "minScale")
    public void setMinScale(PdfView pdfView, float minScale) {
        pdfView.setMinScale(minScale);
    }

    @ReactProp(name = "maxScale")
    public void setMaxScale(PdfView pdfView, float maxScale) {
        pdfView.setMaxScale(maxScale);
    }

    @ReactProp(name = "horizontal")
    public void setHorizontal(PdfView pdfView, boolean horizontal) {
        pdfView.setHorizontal(horizontal);
    }

    @ReactProp(name = "spacing")
    public void setSpacing(PdfView pdfView, int spacing) {
        pdfView.setSpacing(spacing);
    }

    @ReactProp(name = "password")
    public void setPassword(PdfView pdfView, String password) {
        pdfView.setPassword(password);
    }

    @ReactProp(name = "enableAntialiasing")
    public void setEnableAntialiasing(PdfView pdfView, boolean enableAntialiasing) {
        pdfView.setEnableAntialiasing(enableAntialiasing);
    }

    @ReactProp(name = "enableAnnotationRendering")
    public void setEnableAnnotationRendering(PdfView pdfView, boolean enableAnnotationRendering) {
        pdfView.setEnableAnnotationRendering(enableAnnotationRendering);
    }

    @ReactProp(name = "enablePaging")
    public void setEnablePaging(PdfView pdfView, boolean enablePaging) {
        pdfView.setEnablePaging(enablePaging);
    }

    @ReactProp(name = "enableDarkMode")
    public void setEnableDarkMode(PdfView pdfView, boolean enableDarkMode) {
        pdfView.setEnableDarkMode(enableDarkMode);
    }

    @ReactProp(name = "fitPolicy")
    public void setFitPolycy(PdfView pdfView, int fitPolicy) {
        pdfView.setFitPolicy(fitPolicy);
    }

    @ReactProp(name = "singlePage")
    public void setSinglePage(PdfView pdfView, boolean value) {
        pdfView.setIsSinglePage(value);
    }

    @ReactProp(name = "chartStart")
    public void setChartStart(PdfView pdfView, String values) {
        if (values != null && !values.isEmpty()) {
            String[] valuesTab = values.split("\\|");
            pdfView.chartStart = new PdfView.PdfAnnotation(Float.valueOf(valuesTab[0]), Float.valueOf(valuesTab[1]), 0);
        }
    }

    @ReactProp(name = "chartEnd")
    public void setChartEnd(PdfView pdfView, String values) {
        if (values != null && !values.isEmpty()) {
            String[] valuesTab = values.split("\\|");
            pdfView.chartEnd = new PdfView.PdfAnnotation(Float.valueOf(valuesTab[0]), Float.valueOf(valuesTab[1]), 0);
        }
    }

    @ReactProp(name = "chartHighlights")
    public void setChartHighlights(PdfView pdfView, ReadableArray chartHighlights) {

        List<PdfView.PdfHighlightLine> newList = new ArrayList<>();
        if (chartHighlights != null) {



            for (int i = 0; i < chartHighlights.size(); i++) {
                ReadableMap obj = chartHighlights.getMap(i);

                PdfView.PdfHighlightLine newChartHighlight = new PdfView.PdfHighlightLine(obj.getDouble("startX"), obj.getDouble("startY"), obj.getDouble("endX"), obj.getDouble("endY"),
                        obj.getInt("pageNb"), 0, 0, obj.getString("color"), obj.getInt("id"));
                newList.add(newChartHighlight);
            }
        }
        pdfView.setChartHighlights(newList);

    }

    @ReactProp(name = "showPagesNav")
    public void setShowPagesNag(PdfView pdfView, boolean showPagesNav) {
        pdfView.setShowPagesNav(showPagesNav);
    }

    @ReactProp(name = "restoreViewState")
    public void restoreViewState(PdfView pdfView, String values) {
        Log.d("PdfView", "ploup calling restoreViewState");
        if (values == null || values.length() == 0)
            return;
        String[] valuesTab = values.split("/");

        if (valuesTab.length == 4) {
            pdfView.setHighlighterPos(1, Float.valueOf(valuesTab[0]), Integer.valueOf(valuesTab[2]));
            pdfView.setHighlighterPos(0, Float.valueOf(valuesTab[1]), Integer.valueOf(valuesTab[3]));
        }
        else
            pdfView.restoreViewState(Integer.valueOf(valuesTab[0]), Float.valueOf(valuesTab[1]), Float.valueOf(valuesTab[2]), Float.valueOf(valuesTab[3]), Float.valueOf(valuesTab[5]), Float.valueOf(valuesTab[6]), Integer.valueOf(valuesTab[7]), Integer.valueOf(valuesTab[8]), Integer.valueOf(valuesTab[9]));
    }

    @ReactProp(name = "annotations")
    public void setAnnotations(PdfView pdfView, ReadableArray annotations) {

        List<PdfView.PdfAnnotation> newList = new ArrayList<>();
        if (annotations != null) {



            for (int i = 0; i < annotations.size(); i++) {
                ReadableMap obj = annotations.getMap(i);

                PdfView.PdfAnnotation newAnnotation = new PdfView.PdfAnnotation(obj.getDouble("x"), obj.getDouble("y"), obj.getInt("pageNb"),
                        obj.getString("title"), obj.getString("color"), obj.getString("icon"), obj.getInt("size"));
                newList.add(newAnnotation);
            }
        }
        pdfView.setAnnotations(newList);

    }

    @ReactProp(name = "drawings")
    public void setDrawings(PdfView pdfView, ReadableArray drawings) {

        List<PdfView.PdfDrawing> newList = new ArrayList<>();
        if (drawings != null) {



            for (int i = 0; i < drawings.size(); i++) {
                ReadableMap obj = drawings.getMap(i);

                PdfView.PdfDrawing newDrawing = new PdfView.PdfDrawing(obj.getDouble("startX"), obj.getDouble("startY"),
                        obj.getDouble("endX"), obj.getDouble("endY"), obj.getInt("pageNb"), obj.getString("imgPath"));
                newList.add(newDrawing);
            }
        }
        pdfView.setDrawings(newList);

    }
    @ReactProp(name = "drawingsV2")
    public void setDrawingsV2(PdfView pdfView, ReadableArray drawings) {

        List<PdfView.PdfDrawing> newList = new ArrayList<>();
        if (drawings != null) {
            for (int i = 0; i < drawings.size(); i++) {
                ReadableMap obj = drawings.getMap(i);

                PdfView.PdfDrawing newDrawing = new PdfView.PdfDrawing(obj.getInt("pageNb"), obj.getString("imgPath"));
                newList.add(newDrawing);
            }
        }
        pdfView.setDrawings(newList);

    }

    @ReactProp(name = "highlightLines")
    public void setHighlightLines(PdfView pdfView, ReadableArray highlightLines) {

        List<PdfView.PdfHighlightLine> newList = new ArrayList<>();
        if (highlightLines != null) {



            for (int i = 0; i < highlightLines.size(); i++) {
                ReadableMap obj = highlightLines.getMap(i);

                PdfView.PdfHighlightLine newHighlightLine = new PdfView.PdfHighlightLine(obj.getDouble("startX"), obj.getDouble("startY"), obj.getDouble("endX"), obj.getDouble("endY"),
                         obj.getInt("pageNb"), obj.getInt("size"), obj.getInt("isVertical"), obj.getString("color"), 0);
                newList.add(newHighlightLine);
            }
        }
        pdfView.setHighlightLines(newList);

    }

    @Override
    public void onAfterUpdateTransaction(PdfView pdfView) {
        super.onAfterUpdateTransaction(pdfView);
        pdfView.drawPdf();
    }

}
