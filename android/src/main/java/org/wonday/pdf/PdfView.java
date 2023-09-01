/**
 * Copyright (c) 2017-present, Wonday (@wonday.org)
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

package org.wonday.pdf;

import java.io.File;

import android.app.Activity;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Point;
import android.graphics.Rect;
import android.graphics.drawable.Drawable;
import android.os.Looper;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;

import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.util.Log;
import android.graphics.PointF;
import android.net.Uri;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.graphics.Canvas;
import android.widget.Toast;

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
import com.github.barteksc.pdfviewer.link.LinkHandler;
import com.github.barteksc.pdfviewer.model.LinkTapEvent;

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
import java.util.HashMap;
import java.util.List;
import java.util.Timer;
import java.util.TimerTask;

import com.github.barteksc.pdfviewer.util.Util;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.shockwave.pdfium.PdfDocument;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.shockwave.pdfium.util.SizeF;


public class PdfView extends PDFView implements OnPageChangeListener,OnLoadCompleteListener,OnErrorListener,OnTapListener,OnDrawListener,OnPageScrollListener,OnLongPressListener, LinkHandler {
    private ThemedReactContext context;
    private int page = 1;               // start from 1
    private int originalPage = 1;
    private int totalNumberOfPages = 1;
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
    private boolean singlePage = false;
    private boolean showPagesNav = false;

    public PdfAnnotation chartStart;
    public PdfAnnotation chartEnd;

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
    public PdfViewState savedViewState = null;

    private float highlighterHorizontalPos = -42.0f;
    private int highlighterHorizontalPageNb = -1;
    private float highlighterVerticalPos = -42.0f;
    private int highlighterVerticalPageNb = -1;

    public boolean isWaitingForTimer = false;

    private int lastDrawnPdfVersion = -1;
    private int pdfVersionToDraw = -1;

    private Drawable imgNext = null;
    private Drawable imgPrevious = null;
    private Drawable imgPencil = null;
    private Drawable imgTarget = null;

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

    public static class MyCoordinate {
        public double x;
        public double y;
        public int pageNb;

        public MyCoordinate(double x, double y, int pageNb) {
            this.x = x;
            this.y = y;
            this.pageNb = pageNb;
        }
    }

    public static class ClickableZone {
        public double startX;
        public double startY;
        public double endX;
        public double endY;
        public String action;
        public String param;
        public int pageNb;

        public ClickableZone(double startX, double startY, double endX, double endY, String action, int pageNb, String param) {
            this.startX = startX;
            this.startY = startY;
            this.endX = endX;
            this.endY = endY;
            this.action = action;
            this.pageNb = pageNb;
            this.param = param;
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

    public static class PdfDrawing {
        public double startX;
        public double startY;
        public double endX;
        public double endY;
        public int pageNb;
        public String title;
        public String color;
        public String icon;
        public int size;
        public Bitmap image;

        public PdfDrawing() {

        }
        public PdfDrawing(double startX, double startY, double endX, double endY, int pageNb, String imgPath) {
            this.startX = startX;
            this.startY = startY;
            this.endX = endX;
            this.endY = endY;
            this.pageNb = pageNb;

            this.image = BitmapFactory.decodeFile(imgPath);
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
        public int id;

        public PdfHighlightLine() {

        }

        public PdfHighlightLine(double startX, double startY, double endX, double endY, int pageNb, int size, int isVertical, String color, int id) {
            this.startX = startX;
            this.startY = startY;
            this.endX = endX;
            this.endY = endY;
            this.pageNb = pageNb;

            this.size = size;
            this.isVertical = isVertical;
            this.color = color;

            this.id = id;
        }
    }


    public List<PdfAnnotation> pdfAnnotations;
    public List<PdfDrawing> pdfDrawings;
    public List<PdfHighlightLine> highlightLines;
    public List<ClickableZone> clickableZones;
    public List<PdfHighlightLine> chartHighlights;

    private Bitmap annotationBitmapZoom1;
    private Bitmap annotationBitmapZoom2;
    private Bitmap annotationBitmapZoom3;
    private MyTimerTask timerTask;


    public PdfView(ThemedReactContext context, AttributeSet set){
        super(context,set);
        this.context = context;
        this.instance = this;

        this.createPaints();
        this.clickableZones = new ArrayList<>();

        try {
            this.imgNext = Drawable.createFromResourceStream(getResources(),new TypedValue(), getResources().getAssets().open("forward_blue.png"), null);
            this.imgPrevious = Drawable.createFromResourceStream(getResources(),new TypedValue(), getResources().getAssets().open("back_blue.png"), null);
            this.imgPencil = Drawable.createFromResourceStream(getResources(),new TypedValue(), getResources().getAssets().open("pencil.png"), null);
            this.imgTarget = Drawable.createFromResourceStream(getResources(),new TypedValue(), getResources().getAssets().open("target.png"), null);

        } catch (IOException e) {
            e.printStackTrace();
        }

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

    public void setDrawings(List<PdfView.PdfDrawing> pdfDrawings) {
        this.pdfDrawings = pdfDrawings;
    }

    public void setHighlightLines(List<PdfView.PdfHighlightLine> pdfHighlightLines) {
        this.highlightLines = pdfHighlightLines;
    }

    public void setChartHighlights(List<PdfView.PdfHighlightLine> chartHighlights) {
        this.chartHighlights = chartHighlights;
    }

    private void loadAnnotationBitmap() {
       /* Bitmap bitmap = BitmapFactory.decodeResource(
                getResources(),
                R.drawable.
        );*/

        try {
            InputStream bit = this.context.getAssets().open("star.png");
            Bitmap bitmap = BitmapFactory.decodeStream(bit);

            this.annotationBitmapZoom1 = Bitmap.createScaledBitmap(bitmap, 60, 60, false);
            this.annotationBitmapZoom2 = Bitmap.createScaledBitmap(bitmap, 60, 60, false);
            this.annotationBitmapZoom3 = Bitmap.createScaledBitmap(bitmap, 80, 80, false);

        } catch (IOException e1) {
            // TODO Auto-generated catch block
            e1.printStackTrace();
        }


    }

    private void loadDrawingBitmap(float width, float height) {
        try {
            InputStream bit = this.context.getAssets().open("star.png");
            Bitmap bitmap =BitmapFactory.decodeStream(bit);

           // this.drawing = Bitmap.createScaledBitmap(bitmap, 60, 60, false);


        } catch (IOException e1) {
            // TODO Auto-generated catch block
            e1.printStackTrace();
        }



    }

    public void setHighlighterPos(int isVertical, float posPercent, int pageNb) {

        if (isVertical == 1) {
            highlighterVerticalPos = posPercent;
            highlighterVerticalPageNb = pageNb;
        }
        else {
            highlighterHorizontalPos = posPercent;
            highlighterHorizontalPageNb = pageNb;
        }

    }

    public void convertPoints(String stringInput) {
        Gson gson = new Gson();


        int viewWidth = this.getWidth();
        //Log.d("viewWidth:", " " + viewWidth);

        JsonParser parser = new JsonParser();
        JsonObject rootObj = parser.parse(stringInput).getAsJsonObject();
        JsonArray array = rootObj.getAsJsonArray("points");

        //ArrayList<HashMap<String, Float>> listOut = new ArrayList<HashMap<String, Float>>();

        JsonObject mainObjOut = new JsonObject();
        JsonArray pointArrayOut = new JsonArray();

        int pageNb = instance.getCurrentPage();
        for (JsonElement elem : array) {
            JsonObject obj = elem.getAsJsonObject();
            float x = Util.getDP(getContext(), (int)obj.get("x").getAsFloat());
            float y = Util.getDP(getContext(), (int)obj.get("y").getAsFloat());

            MyCoordinate coordinate = getPercentPosForPage(x, y, pageNb);
           // HashMap<String, Float> values = new HashMap<String, Float>();

           // values.put("x", (float)coordinate.x);
          //  values.put("y", (float)coordinate.y);

            JsonObject pointOut = new JsonObject();

            pointOut.addProperty("x", coordinate.x);
            pointOut.addProperty("y", coordinate.y);
            pointArrayOut.add(pointOut);
        }
        mainObjOut.add("points", pointArrayOut);
        mainObjOut.addProperty("pageNb", pageNb);


        String out = mainObjOut.toString();

        Log.d("points out", " " + out);
        WritableMap event = Arguments.createMap();
        event.putString("message", "pointsConverted|"+ out);
        ReactContext reactContext = (ReactContext)this.getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                this.getId(),
                "topChange",
                event
        );
       // return mainObjOut.getAsString();
    }

    public MyCoordinate convertPoint(float x, float y) {
        int pageNb = instance.getCurrentPage();
        MyCoordinate results = getPercentPosForPage(x, y, pageNb);

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

        if (this.singlePage)
            page = originalPage;
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
    public void loadComplete(int numberOfPages, int totalNumberOfPages) {
        float width = this.getWidth();
        float height = this.getHeight();

        this.totalNumberOfPages = totalNumberOfPages;

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
        event.putString("message", "loadComplete|"+totalNumberOfPages+"|"+width+"|"+height+"|"+gson.toJson(this.getTableOfContents()));
        ReactContext reactContext = (ReactContext)this.getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
            this.getId(),
            "topChange",
            event
         );
        this.sendCurrentViewState();
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


    private double getHighlighterHorizontalPos() {

        if (highlighterHorizontalPageNb == -1)
            return 0;

        float paddingY = 0;
        try {
            if (instance.isSwipeVertical()) {
                paddingY = instance.getPageOffset(highlighterHorizontalPageNb, this.getZoom()) ;
            } else {
                paddingY = instance.getSecondaryPageOffset(highlighterHorizontalPageNb, this.getZoom());
            }
        }
        catch (Exception e) {

        }

        double startY = instance.getPageSize(highlighterHorizontalPageNb).getHeight() * (highlighterHorizontalPos / 100.0f) ;

        //double endX = this.pageWidths[pageNb] * (highlightLine.endX / 100.0f) + paddingX;
        //double endY = this.pageHeights[pageNb] * (highlightLine.endY / 100.0f);


        double offset = -instance.getCurrentYOffset();

        double posY = paddingY - offset + (startY * this.getZoom());


        return posY;
        //Log.d("plop posy", " " + posY);
          //      Toast.makeText(this.getContext(), String.valueOf(posY), Toast.LENGTH_LONG).show();
    }

    private double getHighlighterVerticalPos() {


        if (highlighterVerticalPageNb == -1)
            return 0;
        float paddingX = 0;

        try {
            if (instance.isSwipeVertical()) {
                paddingX = instance.getSecondaryPageOffset(highlighterVerticalPageNb, this.getZoom());

            } else {
                paddingX = instance.getPageOffset(highlighterVerticalPageNb, this.getZoom());

            }
        }
        catch (Exception e) {

        }


        double startX = instance.getPageSize(highlighterVerticalPageNb).getWidth() * (highlighterVerticalPos / 100.0f);

        //double endX = this.pageWidths[pageNb] * (highlightLine.endX / 100.0f) + paddingX;
        //double endY = this.pageHeights[pageNb] * (highlightLine.endY / 100.0f);


        double offset = -instance.getCurrentXOffset();



        double posX = paddingX - offset + (startX * this.getZoom());


        //Log.d("plop posy", " " + posY);
        //Toast.makeText(this.getContext(), String.valueOf(posY), Toast.LENGTH_LONG).show();

        return posX;
    }

    @Override
    public boolean onTap(MotionEvent e){

        // maybe change by other instance, restore zoom setting
        //Constants.Pinch.MINIMUM_ZOOM = this.minScale;
        //Constants.Pinch.MAXIMUM_ZOOM = this.maxScale;

        if (instance != null) {

            //Toast.makeText(this.getContext(), String.valueOf(instance.toRealScale(-instance.getCurrentXOffset() + e.getX())), Toast.LENGTH_LONG);
            PdfAnnotation annotation = getAnnotationAtPos(e.getX(), e.getY());

            //test(annotation.x, annotation.y, annotation.pageNb);

            //Log.d("plop onLongPress", " " + annotation.x + " " + annotation.y + " pos:" + instance.toRealScale(-instance.getCurrentXOffset() + e.getX()) + "secondary offset:" + instance.getSecondaryPageOffset(1, 1));

            WritableMap event = Arguments.createMap();

            event.putString("message", "simpleClick|"+annotation.x+"|"+annotation.y+"|"+annotation.pageNb);

            ReactContext reactContext = (ReactContext)this.getContext();
            reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                    this.getId(),
                    "topChange",
                    event
            );

            if (this.singlePage || clickableZones.size() > 0) {

                int displayedPage = 0;
                float pageWidth = 0;
                float pageHeight = 0;
                if (this.singlePage) {
                    pageWidth = this.pageWidths[0];
                    pageHeight = this.pageHeights[0];
                }
                else {
                    displayedPage = instance.getCurrentPage();
                    pageWidth = this.pageWidths[displayedPage];
                    pageHeight = this.pageHeights[displayedPage];
                }
                MyCoordinate results = getPercentPosForPage(e.getX(), e.getY(), displayedPage);

                double startX = results.x * this.pageWidths[displayedPage] / 100;
                double startY = results.y * this.pageHeights[displayedPage] / 100;
                for (ClickableZone clickableZone : clickableZones) {
                    if (startX > clickableZone.startX && startX < clickableZone.endX
                    && startY > clickableZone.startY && startY < clickableZone.endY) {
                        WritableMap eventChangePage = Arguments.createMap();

                        if (clickableZone.action.equals("nextPage"))
                            eventChangePage.putString("message", "onSwitchPage|"+(this.originalPage + 1));
                        else if (clickableZone.action.equals("previousPage"))
                            eventChangePage.putString("message", "onSwitchPage|"+(this.originalPage - 1));
                        else if (clickableZone.action.equals("edit_chart"))
                            eventChangePage.putString("message", "onEditChart|"+clickableZone.param);

                        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                                this.getId(),
                                "topChange",
                                eventChangePage
                        );
                    }
                }
            }


        }
        // process as tap
         return true;

    }

    @Override
    public void onLayerDrawn(Canvas canvas, float pageWidth, float pageHeight, int displayedPage){

        this.clickableZones.clear();
        int pageNb = displayedPage;
        if (this.singlePage)
            pageNb = originalPage;

        if (this.pageWidths[displayedPage] > 0 && this.pageHeights[displayedPage]> 0 && (pageWidth!=this.pageWidths[displayedPage] || pageHeight!=this.pageHeights[displayedPage])) {

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

        if (instance != null && pdfDrawings != null) {

            for (PdfDrawing pdfDrawing : pdfDrawings) {

                if (pdfDrawing.pageNb == pageNb || pdfDrawing.pageNb == pageNb - 1 || pdfDrawing.pageNb == pageNb + 1) {
                    if (pdfDrawing.pageNb != pageNb && this.singlePage)
                        continue;
                    try {
                        // InputStream bit = this.context.getAssets().open("star.png");
                        // Bitmap bitmap = BitmapFactory.decodeStream(bit);

                        //Bitmap bitmapResized = Bitmap.createScaledBitmap(bitmap, 260, (int) (pageHeight + (pageHeight / 2)), false);

                        float paddingX = 0.0f;
                        try {
                            if (instance.isSwipeVertical()) {
                                paddingX = instance.getSecondaryPageOffset(displayedPage, this.getZoom());
                            } else {
                                paddingX = instance.getPageOffset(displayedPage, this.getZoom());
                            }
                        } catch (Exception e) {

                        }


                        double startX = pageWidth * (pdfDrawing.startX / 100.0f) + paddingX;
                        double startY = pageHeight * (pdfDrawing.startY / 100.0f);
                        double endX = pageWidth * (pdfDrawing.endX / 100.0f) + paddingX;
                        double endY = pageHeight * (pdfDrawing.endY / 100.0f);


                        if (!this.singlePage) {
                            if (pdfDrawing.pageNb == displayedPage + 1) {
                                startY += pageHeight + Util.getDP(getContext(), this.spacing);
                                endY += pageHeight + Util.getDP(getContext(), this.spacing);
                            } else if (pdfDrawing.pageNb == displayedPage - 1) {
                                startY -= pageHeight + Util.getDP(getContext(), this.spacing);
                                endY -= pageHeight + Util.getDP(getContext(), this.spacing);
                            }
                        }

                        /*
                        if (pdfDrawing.pageNb == displayedPage + 1) {
                            startY += pageHeight + Util.getDP(getContext(), this.spacing);
                            endY += pageHeight + Util.getDP(getContext(), this.spacing);
                        }
                        else if (pdfDrawing.pageNb == displayedPage - 1) {
                            startY -= pageHeight + Util.getDP(getContext(), this.spacing);
                            endY -= pageHeight + Util.getDP(getContext(), this.spacing);
                        }
*/
                        Rect rect = new Rect();
                        rect.left = (int) startX;
                        rect.right = (int) endX;
                        rect.top = (int) startY;
                        rect.bottom = (int) endY;


                        canvas.drawBitmap(pdfDrawing.image
                                , null
                                , rect
                                , null);


                    } catch (Exception e) {
                        Log.d("error", e.getMessage());
                    }
                }
            }
        }

        if (instance != null && highlightLines != null) {
            for (PdfHighlightLine highlightLine : highlightLines) {

                if (highlightLine.pageNb == pageNb || highlightLine.pageNb == pageNb - 1 || highlightLine.pageNb == pageNb + 1) {

                    if (highlightLine.pageNb != pageNb && this.singlePage)
                        continue;
                    //Log.d("plop drawing at", " " + pageWidth * pdfAnnotation.x / 100);

                    paint.setColor(Color.parseColor((this.enableDarkMode ? "#88" : "#55") + highlightLine.color.replace("#", "")));


                    float paddingX = 0.0f;

                    try {
                        if (instance.isSwipeVertical()) {
                            paddingX = instance.getSecondaryPageOffset(displayedPage, this.getZoom());
                        } else {
                            paddingX = instance.getPageOffset(displayedPage, this.getZoom());
                        }
                    }
                    catch (Exception e) {
                        continue;
                    }


                    double startX = pageWidth * (highlightLine.startX / 100.0f) + paddingX;
                    double startY = pageHeight * (highlightLine.startY / 100.0f);

                    double endX = pageWidth * (highlightLine.endX / 100.0f) + paddingX;
                    double endY = pageHeight * (highlightLine.endY / 100.0f);

                    if (!this.singlePage) {
                        if (highlightLine.pageNb == displayedPage + 1) {
                            startY += pageHeight + Util.getDP(getContext(), this.spacing);
                            endY += pageHeight + Util.getDP(getContext(), this.spacing);
                        } else if (highlightLine.pageNb == displayedPage - 1) {
                            startY -= pageHeight + Util.getDP(getContext(), this.spacing);
                            endY -= pageHeight + Util.getDP(getContext(), this.spacing);
                        }
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

        if (this.singlePage && instance != null) {
            if (this.chartStart != null)
                addIcon(canvas, pageWidth, pageHeight, (float)chartStart.x, (float)chartStart.y, this.imgTarget, 100, null, null, -1, -1, 0.0f);

            if (this.chartEnd != null)
                drawRect(canvas, pageWidth, pageHeight, (float)chartStart.x, (float)chartStart.y, (float)chartEnd.x, (float)chartEnd.y, "#55228822");

            if (showPagesNav) {
                this.addText(canvas, pageWidth, pageHeight, 50, -(6 / this.getZoom()), (this.originalPage + 1) + " / " + this.totalNumberOfPages, "pageList", -1, -1, 0.0f);
                this.addText(canvas, pageWidth, pageHeight, 50, 100 + (6 / this.getZoom()), (this.originalPage + 1) + " / " + this.totalNumberOfPages, "pageList", -1, -1, 0.0f);
                if (this.originalPage > 0) {
                    this.addIcon(canvas, pageWidth, pageHeight, 36, -(6 / this.getZoom()), this.imgPrevious, 70, "previousPage", null, -1, -1, 0.0f);
                    this.addIcon(canvas, pageWidth, pageHeight, 36, 100 + (6 / this.getZoom()), this.imgPrevious, 70, "previousPage", null, -1, -1, 0.0f);

                }
                if (this.originalPage + 1 < this.totalNumberOfPages) {
                    this.addIcon(canvas, pageWidth, pageHeight, 64, -(6 / this.getZoom()), this.imgNext, 70, "nextPage", null, -1, -1, 0.0f);
                    this.addIcon(canvas, pageWidth, pageHeight, 64, 100 + (6 / this.getZoom()), this.imgNext, 70, "nextPage", null, -1, -1, 0.0f);
                }
            }



        }
        if (instance != null) {


            if (this.chartHighlights != null) {

                float paddingX = 0.0f;
                try {
                    if (instance.isSwipeVertical()) {
                        paddingX = instance.getSecondaryPageOffset(displayedPage, this.getZoom());
                    } else {
                        paddingX = instance.getPageOffset(displayedPage, this.getZoom());
                    }
                } catch (Exception e) {

                }
                for (PdfHighlightLine highlight : this.chartHighlights) {
                    if (highlight.pageNb == pageNb || highlight.pageNb == pageNb - 1 || highlight.pageNb == pageNb + 1) {

                        if (highlight.pageNb != pageNb && this.singlePage)
                            continue;
                        double startX = pageWidth * (highlight.startX / 100.0f) + paddingX;
                        double startY = pageHeight * (highlight.startY / 100.0f);

                        double endX = pageWidth * (highlight.endX / 100.0f) + paddingX;
                        double endY = pageHeight * (highlight.endY / 100.0f);

                        if (!this.singlePage) {
                            if (highlight.pageNb == displayedPage + 1) {
                                startY += pageHeight + Util.getDP(getContext(), this.spacing);
                                endY += pageHeight + Util.getDP(getContext(), this.spacing);
                            } else if (highlight.pageNb == displayedPage - 1) {
                                startY -= pageHeight + Util.getDP(getContext(), this.spacing);
                                endY -= pageHeight + Util.getDP(getContext(), this.spacing);
                            }
                        }
                        paint.setColor(Color.parseColor("#55" + highlight.color.replace("#", "")));

                        canvas.drawRect((float)startX, (float)startY, (float)endX, (float)endY,
                                paint);
                        //drawRect(canvas, pageWidth, pageHeight, (float) highlight.startX, (float) highlight.startY, (float) highlight.endX, (float) highlight.endY, "#55" + highlight.color.replace("#", ""));
                        this.addIcon(canvas, pageWidth, pageHeight, (float) highlight.startX, (float) highlight.startY, this.imgPencil, 45, "edit_chart", String.valueOf(highlight.id), highlight.pageNb, pageNb, paddingX);
                    }
                }
            }
        }



        if (instance != null && pdfAnnotations != null) {
            for (PdfAnnotation pdfAnnotation : pdfAnnotations) {

                if (pdfAnnotation.pageNb == pageNb || pdfAnnotation.pageNb == pageNb - 1 || pdfAnnotation.pageNb == pageNb + 1) {

                    if (pdfAnnotation.pageNb != pageNb && this.singlePage)
                        continue;
                    //Log.d("plop drawing at", " " + pageWidth * pdfAnnotation.x / 100);

                    float paddingX = 0.0f;

                    try {
                        if (instance.isSwipeVertical()) {
                            paddingX = instance.getSecondaryPageOffset(displayedPage, this.getZoom());
                        } else {
                            paddingX = instance.getPageOffset(displayedPage, this.getZoom());
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

                    // get position of text's top left corner
                    double x = pageWidth * (pdfAnnotation.x / 100.0f) + paddingX;
                    double y = pageHeight * (pdfAnnotation.y / 100.0f);

                    if (!this.singlePage) {
                        if (pdfAnnotation.pageNb == displayedPage + 1)
                            y += pageHeight + Util.getDP(getContext(), this.spacing);
                        else if (pdfAnnotation.pageNb == displayedPage - 1)
                            y -= pageHeight + Util.getDP(getContext(), this.spacing);
                    }
                    //y = pageHeight + 100;
                    // draw text to the Canvas center
                    canvas.save();
                    canvas.translate((float)x, (float)y);
                    textLayout.draw(canvas);
                    canvas.restore();


                }
            }
        }


    }

    void drawRect(Canvas canvas, float pageWidth, float pageHeight, float startXPerc, float startYPerc, float endXPerc, float endYPerc, String color) {
        paint.setColor(Color.parseColor(color));

        double startX = pageWidth * (startXPerc / 100.0f);
        double startY = pageHeight * (startYPerc / 100.0f);

        double endX = pageWidth * (endXPerc / 100.0f);
        double endY = pageHeight * (endYPerc / 100.0f);

        canvas.drawRect((float)startX, (float)startY, (float)endX, (float)endY,
                paint);

    }

    void addIcon(Canvas canvas, float pageWidth, float pageHeight, float xPerc, float yPerc, Drawable drawable, int iconSize, String action, String actionParam, int targetPage, int currentPage, float paddingX) {
        double x = pageWidth * (xPerc / 100.0f) + paddingX;
        double y = pageHeight * (yPerc / 100.0f);

        x -= iconSize / 2;
        y -= iconSize / 2;

        if (targetPage != -1) {
            if (targetPage == currentPage + 1) {
                x += pageHeight + Util.getDP(getContext(), this.spacing);
            } else if (targetPage == currentPage - 1) {
                y -= pageHeight + Util.getDP(getContext(), this.spacing);
            }
        }

        drawable.setBounds(0, 0, iconSize, iconSize);
        //y = pageHeight + 100;
        // draw text to the Canvas center
        canvas.save();
        canvas.translate((float)x, (float)y);
        drawable.draw(canvas);
        canvas.restore();

        if (action != null) {
            ClickableZone clickableZone = new ClickableZone(x, y, x + iconSize, y + iconSize, action, targetPage, actionParam);
            clickableZones.add(clickableZone);
        }

    }


    void addText(Canvas canvas, float pageWidth, float pageHeight, float xPerc, float yPerc, String text, String action, int targetPage, int currentPage, float paddingX) {
        double x = pageWidth * (xPerc / 100.0f) + paddingX;
        double y = pageHeight * (yPerc / 100.0f);

        textPaint.setColor(Color.parseColor("#888888"));
        //int textSize = (int)(40 / instance.getZoom());
        //if (textSize > 40)
         int   textSize = 40;
        textPaint.setTextSize(textSize);

        int textWidth = 120;
        int textHeight = 60;
        // init StaticLayout for text
        StaticLayout textLayout = new StaticLayout(
                text, textPaint, textWidth, Layout.Alignment.ALIGN_CENTER, 1.0f, 0.0f, false);

        if (targetPage != -1) {
            if (targetPage == currentPage + 1) {
                x += pageHeight + Util.getDP(getContext(), this.spacing);
            } else if (targetPage == currentPage - 1) {
                y -= pageHeight + Util.getDP(getContext(), this.spacing);
            }
        }
        x -= textWidth / 2;
        y -= textHeight / 3;

        //y = pageHeight + 100;
        // draw text to the Canvas center
        canvas.save();
        canvas.translate((float)x, (float)y);
        textLayout.draw(canvas);

        canvas.restore();

        ClickableZone clickableZone = new ClickableZone(x, y, x + textWidth, y + textWidth, action, targetPage, null);
        clickableZones.add(clickableZone);
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        if (this.isRecycled())
            this.drawPdf();
    }

    private PdfAnnotation getAnnotationAtPos(float x, float y) {
        int pageNb = instance.getCurrentPage();
        PdfAnnotation results = getPercentPosForPageAsAnnotation(x, y, pageNb);

        if (results.y > 100) {
            pageNb += 1;
            results = getPercentPosForPageAsAnnotation(x, y, pageNb);
        }
        else if (results.y < 0) {
            pageNb -= 1;
            results = getPercentPosForPageAsAnnotation(x, y, pageNb);
        }

        return results;
    }

    private MyCoordinate getPercentPosForPage(float x, float y, int page) {
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
        return new MyCoordinate(xPer, yPer, page);
    }
    
    private PdfAnnotation getPercentPosForPageAsAnnotation(float x, float y, int page) {

        MyCoordinate coordinate = this.getPercentPosForPage(x, y, page);

        return new PdfAnnotation(coordinate.x, coordinate.y, coordinate.pageNb);
    }

    public void drawPdf() {


      //  this.loadComplete = false;
        //showLog(format("ploup drawPdf path:%s %s ", this.path, this.page));

        
        Activity currentActivity = this.context.getCurrentActivity();
        if (this.path != null && currentActivity != null && !currentActivity.isDestroyed()){

            if (this.savedViewState != null && this.path.equals(this.lastPath)) {
                this.setRestoredState(this.savedViewState);
                this.lastPath = this.path;

                if (pdfVersionToDraw == lastDrawnPdfVersion) {
                    this.loadPages();
                    return;
                }
            }
            this.lastPath = this.path;
            // set scale
            this.setMinZoom(this.minScale);
            this.setMaxZoom(this.maxScale);
            this.setMidZoom((this.maxScale)/3);
            Constants.Pinch.MINIMUM_ZOOM = this.minScale;
            Constants.Pinch.MAXIMUM_ZOOM = this.maxScale;

            Configurator conf = this.fromUri(getURI(this.path))
                .defaultPage(this.page < 0 ? 0 : this.page)
                .swipeHorizontal(this.horizontal)
                .onPageChange(this)
                .onLoad(this)
                .onError(this)
                .onTap(this)
                .onLongPress(this)
                .onDraw(this)
                .onPageScroll(this)
                .spacing(this.spacing != 0 ? this.spacing : 0)
                .password(this.password)
                .enableAntialiasing(this.enableAntialiasing)
                .pageFitPolicy(this.fitPolicy)
                .pageSnap(this.pageSnap)
                .autoSpacing(false)
                    .spacingTop(this.spacing != 0 ? this.spacing : this.singlePage ? 60 : 0)
                    .spacingBottom(this.spacing != 0 ? this.spacing : this.singlePage ? 60 : 0)
                .pageFling(this.pageFling)
                .enableAnnotationRendering(this.enableAnnotationRendering)
                .nightMode(this.enableDarkMode)
		.linkHandler(this);

                if (this.singlePage)
                    conf.pages(this.page < 0 ? 0 : this.page);

                conf.load();
                   // .pages(this.singlePage ? 0)

            Log.d("android loading page ", String.valueOf(this.page));
                //.load();

                lastDrawnPdfVersion = pdfVersionToDraw;

        }
    }

    public void setPath(String path) {
        this.path = path;
    }

    // page start from 1
    public void setPage(int page) {
        page = page < 0 ? 0 : page;
        this.originalPage = page;
        if (!this.singlePage)
            this.page = page;
        else
            this.page = 0;
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

    public void setIsSinglePage(boolean value) {
        this.singlePage = value;
    }

    public void setShowPagesNav(boolean showPagesNav) {
        this.showPagesNav = showPagesNav;
    }
	
/**
     * @see //github.com/barteksc/AndroidPdfViewer/blob/master/android-pdf-viewer/src/main/java/com/github/barteksc/pdfviewer/link/DefaultLinkHandler.java
     */
    public void handleLinkEvent(LinkTapEvent event) {
        String uri = event.getLink().getUri();
        Integer page = event.getLink().getDestPageIdx();
        if (uri != null && !uri.isEmpty()) {
            handleUri(uri);
        } else if (page != null) {
            handlePage(page);
        }
    }

    /**
     * @see //github.com/barteksc/AndroidPdfViewer/blob/master/android-pdf-viewer/src/main/java/com/github/barteksc/pdfviewer/link/DefaultLinkHandler.java
     */
    private void handleUri(String uri) {
        WritableMap event = Arguments.createMap();
        event.putString("message", "linkPressed|"+uri);

        ReactContext reactContext = (ReactContext)this.getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
            this.getId(),
            "topChange",
            event
        );
    }
    /**
     * @see //github.com/barteksc/AndroidPdfViewer/blob/master/android-pdf-viewer/src/main/java/com/github/barteksc/pdfviewer/link/DefaultLinkHandler.java
     */
    private void handlePage(int page) {
        this.jumpTo(page);
    }

    public void sendCurrentViewState() {

      //  if (this.lastLoadingTime + 2000 > new Date().getTime())
       //     return;
      //  showLog("ploup sendCurrentViewState plop" + this.loadComplete);


        int timeout = highlighterHorizontalPageNb != -1 || highlighterVerticalPageNb != -1 ? 500 : 100;

        if (this.isWaitingForTimer)
            return;
        this.isWaitingForTimer = true;

        final PdfView viewObject = this;
        final Runnable runnable = new Runnable() {
            public void run() {

                viewObject.isWaitingForTimer = false;


                try {
                    viewObject.savedViewState = viewObject.getCurrentViewState();

                    if (viewObject.savedViewState == null)
                        return;
                    WritableMap event = Arguments.createMap();

                    int currentPage = viewObject.savedViewState.currentPage;
                    event.putString("message", "positionChanged|" + currentPage + "|" + viewObject.savedViewState.pageFocusX + "|" + viewObject.savedViewState.pageFocusY + "|" + viewObject.savedViewState.zoom + "|" + viewObject.getPositionOffset()
                            + "|" + viewObject.pageWidths[viewObject.savedViewState.currentPage] + "|" + viewObject.pageHeights[viewObject.savedViewState.currentPage] + "|" + viewObject.maxWidth + "|" + viewObject.maxHeight + "|" + viewObject.getHighlighterHorizontalPos() + "|" + viewObject.getHighlighterVerticalPos());

                    ReactContext reactContext = (ReactContext) viewObject.getContext();

                    reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(
                            viewObject.getId(),
                            "topChange",
                            event
                    );
                }
                catch (Exception e) {
                    Log.d("PdfView error", e.getMessage());
                }


            }
        };

        new android.os.Handler(Looper.getMainLooper()).postDelayed(
                runnable,
                timeout);


    }

    public void restoreViewState(int currentPage, float pageFocusX, float pageFocusY, float zoom, float highlighterVerticalPos, float highlighterHorizontalPos, int highlighterVerticalPageNb, int highlighterHorizontalPageNb, int pdfVersionToDraw) {
        //showLog("ploup restoreViewState");
        this.savedViewState = new PdfViewState(currentPage, pageFocusX, pageFocusY, zoom);

        this.highlighterVerticalPos = highlighterVerticalPos;
        this.highlighterVerticalPageNb = highlighterVerticalPageNb;
        this.highlighterHorizontalPos = highlighterHorizontalPos;
        this.highlighterHorizontalPageNb = highlighterHorizontalPageNb;
        this.pdfVersionToDraw = pdfVersionToDraw;

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

    private void setTouchesEnabled(final boolean enabled) {
        setTouchesEnabled(this, enabled);
    }

    private static void setTouchesEnabled(View v, final boolean enabled) {
        if (enabled) {
            v.setOnTouchListener(null);
        } else {
            v.setOnTouchListener(new View.OnTouchListener() {
                @Override
                public boolean onTouch(View v, MotionEvent event) {
                    return true;
                }
            });
        }

        if (v instanceof ViewGroup) {
            ViewGroup vg = (ViewGroup) v;
            for (int i = 0; i < vg.getChildCount(); i++) {
                View child = vg.getChildAt(i);
                setTouchesEnabled(child, enabled);
            }
        }
    }
}
