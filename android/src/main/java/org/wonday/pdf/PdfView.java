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
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Paint;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;

import android.view.View;
import android.view.ViewGroup;
import android.util.Log;
import android.graphics.PointF;
import android.net.Uri;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.graphics.Canvas;
import javax.annotation.Nullable;


import com.github.barteksc.pdfviewer.PDFView;
import com.github.barteksc.pdfviewer.listener.OnLongPressListener;
import com.github.barteksc.pdfviewer.listener.OnPageChangeListener;
import com.github.barteksc.pdfviewer.listener.OnLoadCompleteListener;
import com.github.barteksc.pdfviewer.listener.OnErrorListener;
import com.github.barteksc.pdfviewer.listener.OnRenderListener;
import com.github.barteksc.pdfviewer.listener.OnTapListener;
import com.github.barteksc.pdfviewer.listener.OnDrawListener;
import com.github.barteksc.pdfviewer.listener.OnPageScrollListener;
import com.github.barteksc.pdfviewer.util.FitPolicy;
import com.github.barteksc.pdfviewer.util.Constants;

import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.facebook.react.uimanager.events.RCTEventEmitter;
import com.facebook.react.common.MapBuilder;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.common.logging.FLog;
import com.facebook.react.common.ReactConstants;

import static java.lang.String.format;

import java.io.IOException;
import java.io.InputStream;
import java.lang.ClassCastException;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Timer;
import java.util.TimerTask;

import com.github.barteksc.pdfviewer.util.Util;
import com.shockwave.pdfium.PdfDocument;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.shockwave.pdfium.util.SizeF;


public class PdfView extends PDFView implements OnPageChangeListener,OnLoadCompleteListener,OnErrorListener,OnTapListener,OnDrawListener,OnPageScrollListener,OnLongPressListener {
    private ThemedReactContext context;
    private int page = 1;               // start from 1
    private boolean horizontal = false;
    private float scale = 1;
    private float minScale = 1;
    private float maxScale = 3;
    private String asset;
    private String path;
    private int spacing = 10;
    private String password = "";
    private boolean enableAntialiasing = true;
    private boolean enableAnnotationRendering = true;

    private boolean enablePaging = false;
    private boolean enableDarkMode = false;
    private boolean autoSpacing = false;
    private boolean pageFling = false;
    private boolean pageSnap = false;
    private FitPolicy fitPolicy = FitPolicy.WIDTH;

    private static PdfView instance = null;

    private float [] pageWidths;
    private float [] pageHeights;

    private float maxWidth;
    private float maxHeight;
    private TextPaint textPaint;
    private Paint paint;

   // private boolean loadComplete = false;
   // private long lastLoadingTime = 0;
   private String lastPath;
    private PdfViewState savedViewState = null;

    static class MyTimerTask extends TimerTask {
        WritableMap event;
        ReactContext reactContext;
        int tagId;

        public void setData(WritableMap event, ReactContext reactContext, int tagId) {
            this.event = event;
            this.reactContext = reactContext;
            this.tagId = tagId;
        }


        @Override
        public void run() {
            reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                    tagId,
                    "topChange",
                    event
            );
            // You can do anything you want with param
        }
    }

    public static class PdfAnnotation {
        public double x;
        public double y;
        public int pageNb;
        public String title;
        public String color;
        public String icon;
        public int size;

        public PdfAnnotation() {

        }
        public PdfAnnotation(double x, double y, int pageNb) {
            this.x = x;
            this.y = y;
            this.pageNb = pageNb;
        }
        public PdfAnnotation(double x, double y, int pageNb, String title, String color, String icon, int size) {
            this.x = x;
            this.y = y;
            this.pageNb = pageNb;

            this.title = title;
            this.color = color;
            this.icon = icon;
            this.size = size;
        }
    }

    public static class PdfHighlightLine {
        public double startX;
        public double startY;
        public double endX;
        public double endY;
        public int pageNb;
        public int size;
        public int isVertical;
        public String color;

        public PdfHighlightLine() {

        }

        public PdfHighlightLine(double startX, double startY, double endX, double endY, int pageNb, int size, int isVertical, String color) {
            this.startX = startX;
            this.startY = startY;
            this.endX = endX;
            this.endY = endY;
            this.pageNb = pageNb;

            this.size = size;
            this.isVertical = isVertical;
            this.color = color;
        }
    }


    public List<PdfAnnotation> pdfAnnotations;
    public List<PdfHighlightLine> highlightLines;

    private Bitmap annotationBitmapZoom1;
    private Bitmap annotationBitmapZoom2;
    private Bitmap annotationBitmapZoom3;
    private MyTimerTask timerTask;


    public PdfView(ThemedReactContext context, AttributeSet set){
        super(context,set);
        this.context = context;
        this.instance = this;

        this.createPaints();
        //loadAnnotationBitmap();
    }


    private void createPaints() {
        textPaint = new TextPaint();



        paint = new Paint();
        paint.setStyle(Paint.Style.FILL);
        paint.setAlpha(50);
    }

    public PdfAnnotation createAnnotation(int x, int y, int pageNb) {
        PdfAnnotation annotation = new PdfAnnotation();
        annotation.x = x;
        annotation.y = y;
        annotation.pageNb = pageNb;
        return annotation;
    }

    public void addAnnotation(PdfAnnotation annotation) {
        if (this.pdfAnnotations == null)
            this.pdfAnnotations = new ArrayList<>();

        this.pdfAnnotations.add(annotation);
    }


    public void setAnnotations(List<PdfView.PdfAnnotation> pdfAnnotations) {
        this.pdfAnnotations = pdfAnnotations;
    }

    public void setHighlightLines(List<PdfView.PdfHighlightLine> pdfHighlightLines) {
        this.highlightLines = pdfHighlightLines;
    }

    private void loadAnnotationBitmap() {
       /* Bitmap bitmap = BitmapFactory.decodeResource(
                getResources(),
                R.drawable.
        );*/

        try {
            InputStream bit = this.context.getAssets().open("star.png");
            Bitmap bitmap =BitmapFactory.decodeStream(bit);

            this.annotationBitmapZoom1 = Bitmap.createScaledBitmap(bitmap, 60, 60, false);
            this.annotationBitmapZoom2 = Bitmap.createScaledBitmap(bitmap, 60, 60, false);
            this.annotationBitmapZoom3 = Bitmap.createScaledBitmap(bitmap, 80, 80, false);

        } catch (IOException e1) {
            // TODO Auto-generated catch block
            e1.printStackTrace();
        }



    }


    public Bitmap getAnnotationBitmap(int zoom) {
        Log.d("plop zoom", " " + zoom);

        if (zoom > 2)
            return this.annotationBitmapZoom3;
        else if (zoom > 1)
            return this.annotationBitmapZoom2;
        else
            return this.annotationBitmapZoom1;

    }

    @Override
    public void onPageChanged(int page, int numberOfPages) {
        // pdf lib page start from 0, convert it to our page (start from 1)
        page = page+1;
        this.page = page;
        showLog(format("%s %s / %s", path, page, numberOfPages));

        WritableMap event = Arguments.createMap();
        event.putString("message", "pageChanged|"+page+"|"+numberOfPages);
        ReactContext reactContext = (ReactContext)this.getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
            this.getId(),
            "topChange",
            event
         );

        sendCurrentViewState();
    }

    @Override
    public void loadComplete(int numberOfPages) {
        float width = this.getWidth();
        float height = this.getHeight();



        for (int i = 0; i < numberOfPages; i++) {
           SizeF val = this.getPageSize(i);

           if (val.getHeight() > this.maxHeight)
               this.maxHeight = val.getHeight();
            if (val.getWidth() > this.maxWidth)
                this.maxWidth = val.getWidth();
        }
        this.pageWidths = new float[numberOfPages];
        this.pageHeights = new float[numberOfPages];
        this.zoomTo(this.scale);
        WritableMap event = Arguments.createMap();


       // this.lastLoadingTime = new Date().getTime();
        showLog("ploup load complete");
       // this.loadComplete = true;
        //create a new jason Object for the TableofContents
        Gson gson = new Gson();
        event.putString("message", "loadComplete|"+numberOfPages+"|"+width+"|"+height+"|"+gson.toJson(this.getTableOfContents()));
        ReactContext reactContext = (ReactContext)this.getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
            this.getId(),
            "topChange",
            event
         );
        
        //Log.e("ReactNative", gson.toJson(this.getTableOfContents()));

    }

    @Override
    public void onError(Throwable t){
        WritableMap event = Arguments.createMap();
        if (t.getMessage().contains("Password required or incorrect password")) {
            event.putString("message", "error|Password required or incorrect password.");
        } else {
            event.putString("message", "error|"+t.getMessage());
        }

        ReactContext reactContext = (ReactContext)this.getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
            this.getId(),
            "topChange",
            event
         );
    }

    @Override
    public void onPageScrolled(int page, float positionOffset){

        // maybe change by other instance, restore zoom setting
        Constants.Pinch.MINIMUM_ZOOM = this.minScale;
        Constants.Pinch.MAXIMUM_ZOOM = this.maxScale;


        sendCurrentViewState();
    }

    @Override
    public void onLongPress(MotionEvent e) {

        if (instance != null) {
            PdfAnnotation annotation = getAnnotationAtPos(e.getX(), e.getY());


            Log.d("plop onLongPress", " " + annotation.x + " " + annotation.y);
            //addAnnotation(annotation);


            WritableMap event = Arguments.createMap();

            event.putString("message", "longClick|"+annotation.x+"|"+annotation.y+"|"+annotation.pageNb);

            ReactContext reactContext = (ReactContext)this.getContext();
            reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                    this.getId(),
                    "topChange",
                    event
            );

           // instance.redraw();
        }
    }

    @Override
    public boolean onTap(MotionEvent e){

        // maybe change by other instance, restore zoom setting
        //Constants.Pinch.MINIMUM_ZOOM = this.minScale;
        //Constants.Pinch.MAXIMUM_ZOOM = this.maxScale;

        if (instance != null) {
            PdfAnnotation annotation = getAnnotationAtPos(e.getX(), e.getY());


            Log.d("plop onLongPress", " " + annotation.x + " " + annotation.y);

            WritableMap event = Arguments.createMap();

            event.putString("message", "simpleClick|"+annotation.x+"|"+annotation.y+"|"+annotation.pageNb);

            ReactContext reactContext = (ReactContext)this.getContext();
            reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                    this.getId(),
                    "topChange",
                    event
            );


        }
        // process as tap
         return true;

    }

    @Override
    public void onLayerDrawn(Canvas canvas, float pageWidth, float pageHeight, int displayedPage){


        if (this.pageWidths[displayedPage] >0 && this.pageHeights[displayedPage]>0 && (pageWidth!=this.pageWidths[displayedPage] || pageHeight!=this.pageHeights[displayedPage])) {

            // maybe change by other instance, restore zoom setting
            Constants.Pinch.MINIMUM_ZOOM = this.minScale;
            Constants.Pinch.MAXIMUM_ZOOM = this.maxScale;

            WritableMap event = Arguments.createMap();
            event.putString("message", "scaleChanged|"+(pageWidth/this.pageWidths[displayedPage]));

            ReactContext reactContext = (ReactContext)this.getContext();
            reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                this.getId(),
                "topChange",
                event
             );

            sendCurrentViewState();
        }

        this.pageWidths[displayedPage] = pageWidth;
        this.pageHeights[displayedPage] = pageHeight;

        if (instance != null && highlightLines != null) {
            for (PdfHighlightLine highlightLine : highlightLines) {

                if (highlightLine.pageNb == displayedPage || highlightLine.pageNb == displayedPage - 1 || highlightLine.pageNb == displayedPage + 1) {

                    //Log.d("plop drawing at", " " + pageWidth * pdfAnnotation.x / 100);

                    paint.setColor(Color.parseColor((this.enableDarkMode ? "#88" : "#55") + highlightLine.color.replace("#", "")));


                    float paddingX = 0.0f;

                    try {
                        if (instance.isSwipeVertical()) {
                            paddingX = instance.getSecondaryPageOffset(highlightLine.pageNb, this.getZoom());
                        } else {
                            paddingX = instance.getPageOffset(highlightLine.pageNb, this.getZoom());
                        }
                    }
                    catch (Exception e) {
                        continue;
                    }


                    double startX = pageWidth * (highlightLine.startX / 100.0f) + paddingX;
                    double startY = pageHeight * (highlightLine.startY / 100.0f);

                    double endX = pageWidth * (highlightLine.endX / 100.0f) + paddingX;
                    double endY = pageHeight * (highlightLine.endY / 100.0f);

                    if (highlightLine.pageNb == displayedPage + 1) {
                        startY += pageHeight + Util.getDP(getContext(), this.spacing);
                        endY += pageHeight + Util.getDP(getContext(), this.spacing);
                    }
                    else if (highlightLine.pageNb == displayedPage - 1) {
                        startY -= pageHeight + Util.getDP(getContext(), this.spacing);
                        endY -= pageHeight + Util.getDP(getContext(), this.spacing);
                    }

                    float size = (float)Util.getDP(getContext(), highlightLine.size) * this.getZoom();


                    size = size / 2;
                    if (highlightLine.isVertical == 1) {
                        startX = startX - (size / 2);
                        endX = startX + (size / 2);

                    }
                    else {
                        startY = startY - (size / 2);
                        endY = startY + size;
                    }


                    // draw text to the Canvas center
                    //canvas.save();
                    // canvas.translate(x, y);

                    canvas.drawRect((float)startX, (float)startY, (float)endX, (float)endY,
                            paint);

                    // textLayout.draw(canvas);
                    //canvas.restore();


                }
            }
        }

        if (instance != null && pdfAnnotations != null) {
            for (PdfAnnotation pdfAnnotation : pdfAnnotations) {

                if (pdfAnnotation.pageNb == displayedPage || pdfAnnotation.pageNb == displayedPage - 1 || pdfAnnotation.pageNb == displayedPage + 1) {

                    //Log.d("plop drawing at", " " + pageWidth * pdfAnnotation.x / 100);

                    float paddingX = 0.0f;

                    try {
                        if (instance.isSwipeVertical()) {
                            paddingX = instance.getSecondaryPageOffset(pdfAnnotation.pageNb, this.getZoom());
                        } else {
                            paddingX = instance.getPageOffset(pdfAnnotation.pageNb, this.getZoom());
                        }
                    }
                    catch (Exception e) {
                        continue;
                    }


                    /*
                    Bitmap bitmap = getAnnotationBitmap((int) instance.getZoom());
                    canvas.drawBitmap(bitmap
                            , pageWidth * (pdfAnnotation.x / 100.0f) - (bitmap.getWidth() / 2) + paddingX
                            , pageHeight * (pdfAnnotation.y / 100.0f) - (bitmap.getHeight() / 2)
                            , null);
                    */
                    textPaint.setColor(Color.parseColor(pdfAnnotation.color));

                    float multiple = 1.0f;
                    if (pdfAnnotation.size <= 10)
                        multiple = 0.7f;
                    else if (pdfAnnotation.size > 16)
                        multiple = 1.4f;
                    if(getResources().getConfiguration().orientation == Configuration.ORIENTATION_PORTRAIT)
                        textPaint.setTextSize(25 * instance.getZoom() * multiple);
                    else
                        textPaint.setTextSize(15 * instance.getZoom() * multiple);

                    int textWidth = (int)((canvas.getWidth() - (int) (canvas.getWidth() * (pdfAnnotation.x / 100.0f))) * instance.getZoom());

                    //Log.d("PdfView canvaswidth=", canvas.getWidth() + ": pageWidth=" + pageWidth + " x=" + pdfAnnotation.x + " textwidth:" + textWidth );
                    if (textWidth < 40)
                        textWidth = 40;
                    // init StaticLayout for text
                    StaticLayout textLayout = new StaticLayout(
                            pdfAnnotation.icon + " " + pdfAnnotation.title, textPaint, textWidth, Layout.Alignment.ALIGN_NORMAL, 1.0f, 0.0f, false);

                    // get height of multiline text
                    int textHeight = textLayout.getHeight();


                    // get position of text's top left corner
                    double x = pageWidth * (pdfAnnotation.x / 100.0f) + paddingX;
                    double y = pageHeight * (pdfAnnotation.y / 100.0f);

                    if (pdfAnnotation.pageNb == displayedPage + 1)
                        y += pageHeight + Util.getDP(getContext(), this.spacing);
                    else if (pdfAnnotation.pageNb == displayedPage - 1)
                        y -= pageHeight + Util.getDP(getContext(), this.spacing);

                    // draw text to the Canvas center
                    canvas.save();
                    canvas.translate((float)x, (float)y);
                    textLayout.draw(canvas);
                    canvas.restore();


                }
            }
        }


    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        if (this.isRecycled())
            this.drawPdf();
    }

    private PdfAnnotation getAnnotationAtPos(float x, float y) {
        int pageNb = instance.getCurrentPage();
        PdfAnnotation results = getPercentPosForPage(x, y, pageNb);

        if (results.y > 100) {
            pageNb += 1;
            results = getPercentPosForPage(x, y, pageNb);
        }
        else if (results.y < 0) {
            pageNb -= 1;
            results = getPercentPosForPage(x, y, pageNb);
        }

        return results;
    }

    private PdfAnnotation getPercentPosForPage(float x, float y, int page) {
        float xPer = 0;
        float yPer = 0;
        try {
            float xPositionInRealScale = instance.toRealScale(-instance.getCurrentXOffset() + x);
            float yPositionInRealScale = instance.toRealScale(-instance.getCurrentYOffset() + y);

            if (instance.isSwipeVertical()) {
                xPositionInRealScale = xPositionInRealScale - instance.getSecondaryPageOffset(page, 1);
                yPositionInRealScale = yPositionInRealScale - instance.getPageOffset(page, 1);
            } else {
                xPositionInRealScale = xPositionInRealScale - instance.getPageOffset(page, 1);
                yPositionInRealScale = yPositionInRealScale - instance.getSecondaryPageOffset(page, 1);
            }

            xPer = xPositionInRealScale / instance.getPageSize(page).getWidth() * 100;
            yPer = yPositionInRealScale / instance.getPageSize(page).getHeight() * 100;
        }
        catch (Exception e) {

        }
        return new PdfAnnotation(xPer, yPer, page);
    }

    public void drawPdf() {


      //  this.loadComplete = false;
        showLog(format("ploup drawPdf path:%s %s ", this.path, this.page));


        if (this.path != null){

            if (this.savedViewState != null && this.path.equals(this.lastPath))
                this.setRestoredState(this.savedViewState);
            this.lastPath = this.path;
            // set scale
            this.setMinZoom(this.minScale);
            this.setMaxZoom(this.maxScale);
            this.setMidZoom((this.maxScale)/3);
            Constants.Pinch.MINIMUM_ZOOM = this.minScale;
            Constants.Pinch.MAXIMUM_ZOOM = this.maxScale;

            this.fromUri(getURI(this.path))
                .defaultPage(this.page-1)
                .swipeHorizontal(this.horizontal)
                .onPageChange(this)
                .onLoad(this)
                .onError(this)
                .onTap(this)
                .onLongPress(this)
                .onDraw(this)
                .onPageScroll(this)
                .spacing(this.spacing)
                .password(this.password)
                .enableAntialiasing(this.enableAntialiasing)
                .pageFitPolicy(this.fitPolicy)
                .pageSnap(this.pageSnap)
                .autoSpacing(this.autoSpacing)
                .pageFling(this.pageFling)
                .enableAnnotationRendering(this.enableAnnotationRendering)
                .nightMode(this.enableDarkMode)
                .load();

        }
    }

    public void setPath(String path) {
        this.path = path;
    }

    // page start from 1
    public void setPage(int page) {
        this.page = page>1?page:1;
    }

    public void setScale(float scale) {
        this.scale = scale;
    }

    public void setMinScale(float minScale) {
        this.minScale = minScale;
    }

    public void setMaxScale(float maxScale) {
        this.maxScale = maxScale;
    }

    public void setHorizontal(boolean horizontal) {
        this.horizontal = horizontal;
    }

    public void setSpacing(int spacing) {
        this.spacing = spacing;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public void setEnableAntialiasing(boolean enableAntialiasing) {
        this.enableAntialiasing = enableAntialiasing;
    }

    public void setEnableAnnotationRendering(boolean enableAnnotationRendering) {
        this.enableAnnotationRendering = enableAnnotationRendering;
    }

    public void setEnablePaging(boolean enablePaging) {
        this.enablePaging = enablePaging;
        if (this.enablePaging) {
            this.autoSpacing = true;
            this.pageFling = true;
            this.pageSnap = true;
        } else {
            this.autoSpacing = false;
            this.pageFling = false;
            this.pageSnap = false;
        }
    }

    public void setEnableDarkMode(boolean enableDarkMode) {
        this.enableDarkMode = enableDarkMode;
    }

    public void setFitPolicy(int fitPolicy) {
        switch(fitPolicy){
            case 0:
                this.fitPolicy = FitPolicy.WIDTH;
                break;
            case 1:
                this.fitPolicy = FitPolicy.HEIGHT;
                break;
            case 2:
            default:
            {
                this.fitPolicy = FitPolicy.BOTH;
                break;
            }
        }

    }

    public void sendCurrentViewState() {

      //  if (this.lastLoadingTime + 2000 > new Date().getTime())
       //     return;
      //  showLog("ploup sendCurrentViewState plop" + this.loadComplete);
        this.savedViewState = this.getCurrentViewState();

        if (this.savedViewState == null)
            return;
        WritableMap event = Arguments.createMap();

        event.putString("message", "positionChanged|"+this.savedViewState.currentPage+"|"+this.savedViewState.pageFocusX+"|"+this.savedViewState.pageFocusY+"|"+this.savedViewState.zoom + "|" + this.getPositionOffset()
                + "|" + this.pageWidths[this.savedViewState.currentPage] + "|" + this.pageHeights[this.savedViewState.currentPage] + "|" + this.maxWidth + "|" + this.maxHeight);

        ReactContext reactContext = (ReactContext)this.getContext();
/*
        if (this.timerTask != null)
            this.timerTask.cancel();

        this.timerTask = new MyTimerTask() {
            @Override
            public void run()
            {
                //do something
                this.reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                        tagId,
                        "topChange",
                        event
                );
            }
        };

        this.timerTask.setData(event, reactContext, getId());
        Timer timer = new Timer("Timer");

        timer.schedule(this.timerTask, 500);*/
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                this.getId(),
                "topChange",
                event
        );

    }

    public void restoreViewState(int currentPage, float pageFocusX, float pageFocusY, float zoom) {
        showLog("ploup restoreViewState");
        this.savedViewState = new PdfViewState(currentPage, pageFocusX, pageFocusY, zoom);

        this.setRestoredState(this.savedViewState);
    }

    private void showLog(final String str) {
        Log.d("PdfView", str);
    }

    private Uri getURI(final String uri) {
        Uri parsed = Uri.parse(uri);

        if (parsed.getScheme() == null || parsed.getScheme().isEmpty()) {
          return Uri.fromFile(new File(uri));
        }
        return parsed;
    }
}
