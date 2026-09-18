package com.wolfox.gps.manager;

import android.app.Activity;
import android.webkit.WebView;

import com.wolfox.gps.model.WFLocation;
import com.wolfox.gps.ui.MapDialog;
import com.wolfox.gps.util.WFLog;
import com.wolfox.gps.util.WFStorage;

/**
 * MapController — التحكم في الخريطة
 *
 * يتعامل مع WebView الخاص بـ wolfox_map.html
 * ويوفر دوال JavaScript bridge للخريطة.
 */
public class MapController {

    private static final String TAG = "MapController";

    private static MapController instance;
    private WebView activeWebView;

    private MapController() {}

    public static synchronized MapController getInstance() {
        if (instance == null) instance = new MapController();
        return instance;
    }

    // ─── ربط WebView ─────────────────────────────────────────────────────────

    public void setWebView(WebView wv) {
        this.activeWebView = wv;
    }

    // ─── تمركز الخريطة ───────────────────────────────────────────────────────

    public void centerOn(double lat, double lng) {
        runJs("if(typeof centerMap==='function') centerMap(" + lat + "," + lng + ");");
    }

    public void centerOnCurrentMock() {
        WFLocation loc = GPSManager.getInstance().getLocation();
        if (loc != null) centerOn(loc.getLatitude(), loc.getLongitude());
    }

    // ─── تغيير نوع الخريطة ───────────────────────────────────────────────────

    public void setMapType(String type) {
        WFStorage.getInstance(getContext()).setMapType(type);
        runJs("if(typeof setMapType==='function') setMapType('" + type + "');");
    }

    // ─── إضافة علامة ─────────────────────────────────────────────────────────

    public void addMarker(double lat, double lng, String label) {
        String safeLabel = label != null ? label.replace("'", "\\'") : "";
        runJs("if(typeof addMarker==='function') addMarker("
            + lat + "," + lng + ",'" + safeLabel + "');");
    }

    // ─── فتح نافذة الخريطة ───────────────────────────────────────────────────

    public void showMapDialog(Activity activity) {
        MapDialog.show(activity);
    }

    // ─── JS Helper ───────────────────────────────────────────────────────────

    private void runJs(String js) {
        if (activeWebView == null) {
            WFLog.w(TAG, "No active WebView");
            return;
        }
        try {
            activeWebView.post(() -> activeWebView.evaluateJavascript(js, null));
        } catch (Exception e) {
            WFLog.e(TAG, "runJs: " + e.getMessage());
        }
    }

    private android.content.Context getContext() {
        return activeWebView != null ? activeWebView.getContext() : null;
    }
}
