package com.wolfox.gps.ui;

import android.app.Activity;
import android.app.Dialog;
import android.os.Handler;
import android.os.Looper;
import android.view.ViewGroup;
import android.view.Window;
import android.webkit.*;
import android.widget.Toast;

import com.wolfox.gps.manager.GPSMockManager;
import com.wolfox.gps.model.FavoriteLocation;
import com.wolfox.gps.model.HistoryEntry;
import com.wolfox.gps.model.WFLocation;
import com.wolfox.gps.util.WFLog;
import com.wolfox.gps.util.WFStorage;

import org.json.JSONObject;

public class MapDialog {

    private static final String TAG = "MapDialog";
    private static Dialog   currentDialog;
    private static WebView  mapWebView;
    private static Activity currentActivity;

    public static void show(Activity activity) {
        if (activity == null || activity.isFinishing()) return;
        currentActivity = activity;
        activity.runOnUiThread(() -> buildAndShow(activity));
    }

    @SuppressWarnings("SetJavaScriptEnabled")
    private static void buildAndShow(Activity activity) {
        if (currentDialog != null && currentDialog.isShowing()) currentDialog.dismiss();

        Dialog dialog = new Dialog(activity,
                android.R.style.Theme_Black_NoTitleBar_Fullscreen);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        dialog.setCancelable(true);
        Window w = dialog.getWindow();
        if (w != null)
            w.setLayout(ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT);

        WebView wv = new WebView(activity);
        mapWebView = wv;

        WebSettings s = wv.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setGeolocationEnabled(true);
        s.setAllowFileAccessFromFileURLs(true);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        s.setUserAgentString("WolFoxGPS/4.0 Android");

        wv.addJavascriptInterface(new Bridge(activity, dialog), "WolFoxAndroid");

        wv.setWebViewClient(new WebViewClient() {
            @Override public void onPageFinished(WebView view, String url) {
                syncStatus(view);
                // أرسل الموقع الحقيقي للخريطة
                sendRealLocation(view);
            }
        });

        wv.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onGeolocationPermissionsShowPrompt(String o,
                    GeolocationPermissions.Callback cb) { cb.invoke(o,true,false); }
        });

        wv.loadUrl("file:///android_asset/wolfox_map.html");
        dialog.setContentView(wv);
        dialog.setOnDismissListener(d -> { mapWebView = null; currentDialog = null; });
        currentDialog = dialog;
        dialog.show();
    }

    // ─── مزامنة حالة التزييف مع الخريطة ─────────────────────────────────────

    public static void syncStatus(WebView view) {
        if (view == null) return;
        boolean mock = GPSMockManager.getInstance().isMocking();
        WFLocation loc = GPSMockManager.getInstance().getLocation();
        double lat = loc != null ? loc.getLatitude()  : 0;
        double lng = loc != null ? loc.getLongitude() : 0;
        String js = "wolfoxBridge.setMockStatus(" + mock + "," + lat + "," + lng + ");";
        new Handler(Looper.getMainLooper()).post(() -> view.evaluateJavascript(js, null));
    }

    public static void refreshStatus() {
        if (mapWebView != null) syncStatus(mapWebView);
    }

    // ─── إرسال الموقع الحقيقي (النقطة الزرقاء) ───────────────────────────────

    private static void sendRealLocation(WebView view) {
        // نستخدم GPS الجهاز الحقيقي لإرسال إحداثياته للخريطة
        try {
            android.location.LocationManager lm = (android.location.LocationManager)
                    currentActivity.getSystemService(android.content.Context.LOCATION_SERVICE);
            if (lm == null) return;
            android.location.Location last = null;
            try { last = lm.getLastKnownLocation(
                    android.location.LocationManager.GPS_PROVIDER); } catch (Exception ignored) {}
            if (last == null) try { last = lm.getLastKnownLocation(
                    android.location.LocationManager.NETWORK_PROVIDER); } catch (Exception ignored) {}
            if (last != null) {
                final double lat = last.getLatitude();
                final double lng = last.getLongitude();
                String js = "wolfoxBridge.realLocation(" + lat + "," + lng + ");";
                new Handler(Looper.getMainLooper()).post(() ->
                        view.evaluateJavascript(js, null));
            }
        } catch (Exception e) { WFLog.e(TAG, "sendRealLocation: " + e.getMessage()); }
    }

    // ─── Toast داخل الخريطة ──────────────────────────────────────────────────

    public static void showMapToast(String type, String msg) {
        if (mapWebView == null) return;
        String js = "wolfoxBridge.showToast('" + type + "','" +
                msg.replace("'","\\'") + "');";
        new Handler(Looper.getMainLooper()).post(() ->
                mapWebView.evaluateJavascript(js, null));
    }

    // ─── Bridge ──────────────────────────────────────────────────────────────

    public static class Bridge {
        private final Activity activity;
        private final Dialog   dialog;

        Bridge(Activity a, Dialog d) { activity = a; dialog = d; }

        @JavascriptInterface
        public void onMapEvent(String action, String jsonData) {
            WFLog.i(TAG, "Bridge[" + action + "] " + jsonData);
            try {
                JSONObject data = new JSONObject(jsonData);
                switch (action) {

                    case "apply": {
                        double lat   = data.getDouble("lat");
                        double lng   = data.getDouble("lng");
                        String label = data.optString("label", "");
                        WFLocation loc = new WFLocation(lat, lng, label);
                        GPSMockManager.getInstance().setLocation(loc);
                        WFStorage.getInstance(activity).addHistory(
                            new HistoryEntry(HistoryEntry.Action.CHANGE_LOCATION,
                                lat, lng, "تحديد من الخريطة: " + label));
                        activity.runOnUiThread(() ->
                            Toast.makeText(activity,
                                "📍 تم تحديد الموقع — اضغط ابدأ",
                                Toast.LENGTH_SHORT).show());
                        break;
                    }

                    case "start": {
                        if (!GPSMockManager.getInstance().hasMockLocation()) {
                            showMapToast("error",
                                "<i class='fa-solid fa-ban'></i> لم يُحدد موقع");
                            return;
                        }
                        GPSMockManager.getInstance().startMocking();
                        WFLocation loc = GPSMockManager.getInstance().getLocation();
                        WFStorage.getInstance(activity).addHistory(
                            new HistoryEntry(HistoryEntry.Action.START_MOCK,
                                loc.getLatitude(), loc.getLongitude(), "تزييف من الخريطة"));
                        // أرسل التحديث للخريطة
                        syncStatus(mapWebView);
                        activity.runOnUiThread(() ->
                            Toast.makeText(activity, "✅ التزييف نشط",
                                Toast.LENGTH_SHORT).show());
                        break;
                    }

                    case "stop": {
                        GPSMockManager.getInstance().stopMocking();
                        WFStorage.getInstance(activity).addHistory(
                            new HistoryEntry(HistoryEntry.Action.STOP_MOCK, "إيقاف من الخريطة"));
                        syncStatus(mapWebView);
                        // أرسل الموقع الحقيقي بعد الإيقاف
                        sendRealLocation(mapWebView);
                        break;
                    }

                    case "save_favorite": {
                        double lat   = data.getDouble("lat");
                        double lng   = data.getDouble("lng");
                        String label = data.optString("label", "موقع محفوظ");
                        FavoriteLocation fav = new FavoriteLocation(label, lat, lng);
                        WFStorage.getInstance(activity).addFavorite(fav);
                        activity.runOnUiThread(() ->
                            Toast.makeText(activity, "⭐ تم الحفظ: " + label,
                                Toast.LENGTH_SHORT).show());
                        break;
                    }

                    case "pin":
                        WFLog.d(TAG, "pin placed: " + jsonData);
                        break;

                    case "status_changed":
                        // الخريطة أبلغت Android بتغيير الحالة — FloatingManager يُحدَّث
                        WFLog.d(TAG, "status_changed");
                        break;
                }
            } catch (Exception e) {
                WFLog.e(TAG, "Bridge error: " + e.getMessage());
                showMapToast("error", "<i class='fa-solid fa-bug'></i> خطأ داخلي");
            }
        }
    }
}
