package com.wolfox.gps.hook;

import android.app.PendingIntent;
import android.content.Context;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;

import com.wolfox.gps.manager.GPSMockManager;
import com.wolfox.gps.model.WFLocation;
import com.wolfox.gps.util.WFLog;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/**
 * WolFoxHook — نقطة الدخول للموديول
 *
 * FIX: إضافة هوك LocationManager.requestLocationUpdates(String,long,float,PendingIntent)
 *      — يعترض البديل الثاني من requestLocationUpdates.
 * FIX: LocationResult.getLocations() معترض.
 * FIX: LocationAvailability.isLocationAvailable() → true.
 * FIX: setIsFromMockProvider(false) في GPSMockManager.buildLocation.
 */
public class WolFoxHook implements IXposedHookLoadPackage {

    private static final String TAG = "WolFoxHook";

    @Override
    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam lpparam) {
        WFLog.i(TAG, "LSPatch loaded in: " + lpparam.packageName);

        hookApplicationContext(lpparam);
        hookLocationManager(lpparam);
        hookFusedLocation(lpparam);
        hookWebView(lpparam);
        ActivityHook.install(lpparam);
        LicenseHook.install(lpparam);

        WFLog.i(TAG, "✅ WolFox hooks active");
    }

    // ─── تهيئة السياق ─────────────────────────────────────────────────────────

    private void hookApplicationContext(XC_LoadPackage.LoadPackageParam lpparam) {
        try {
            XposedHelpers.findAndHookMethod(
                "android.app.Application", lpparam.classLoader, "onCreate",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        Context ctx = (Context) param.thisObject;
                        GPSMockManager.getInstance().init(ctx);
                        WFLog.i(TAG, "Context ready ✅");
                    }
                }
            );
        } catch (Exception e) { WFLog.e(TAG, "hookApp: " + e.getMessage()); }
    }

    // ─── LocationManager ──────────────────────────────────────────────────────

    private void hookLocationManager(XC_LoadPackage.LoadPackageParam lpparam) {

        // 1) getLastKnownLocation
        try {
            XposedHelpers.findAndHookMethod(
                LocationManager.class.getName(), lpparam.classLoader,
                "getLastKnownLocation", String.class,
                new XC_MethodHook() {
                    @Override protected void afterHookedMethod(MethodHookParam param) {
                        if (!GPSMockManager.getInstance().isMocking()) return;
                        WFLocation wfl = GPSMockManager.getInstance().getLocation();
                        if (wfl == null) return;
                        param.setResult(GPSMockManager.getInstance()
                            .buildLocation((String) param.args[0], wfl));
                        WFLog.hook("getLastKnownLocation", wfl);
                    }
                }
            );
        } catch (Exception e) { WFLog.d(TAG, "getLastKnownLocation: " + e.getMessage()); }

        // 2) requestLocationUpdates (String, long, float, LocationListener)
        try {
            XposedHelpers.findAndHookMethod(
                LocationManager.class.getName(), lpparam.classLoader,
                "requestLocationUpdates",
                String.class, long.class, float.class, LocationListener.class,
                new XC_MethodHook() {
                    @Override protected void afterHookedMethod(MethodHookParam param) {
                        if (!GPSMockManager.getInstance().isMocking()) return;
                        WFLocation wfl = GPSMockManager.getInstance().getLocation();
                        if (wfl == null) return;
                        LocationListener listener = (LocationListener) param.args[3];
                        if (listener == null) return;
                        try {
                            listener.onLocationChanged(GPSMockManager.getInstance()
                                .buildLocation((String) param.args[0], wfl));
                        } catch (Exception ignored) {}
                        WFLog.hook("LM.requestLocationUpdates→cb", wfl);
                    }
                }
            );
        } catch (Exception e) { WFLog.d(TAG, "LM.requestLocationUpdates: " + e.getMessage()); }

        // 3) FIX: requestLocationUpdates (String, long, float, PendingIntent)
        try {
            XposedHelpers.findAndHookMethod(
                LocationManager.class.getName(), lpparam.classLoader,
                "requestLocationUpdates",
                String.class, long.class, float.class, PendingIntent.class,
                new XC_MethodHook() {
                    @Override protected void afterHookedMethod(MethodHookParam param) {
                        if (!GPSMockManager.getInstance().isMocking()) return;
                        WFLocation wfl = GPSMockManager.getInstance().getLocation();
                        if (wfl == null) return;
                        // PendingIntent تُرسَل بـ broadcast — نُرسل Intent مزيف
                        PendingIntent pi = (PendingIntent) param.args[3];
                        if (pi == null) return;
                        try {
                            android.content.Intent intent = new android.content.Intent();
                            Location loc = GPSMockManager.getInstance()
                                .buildLocation((String) param.args[0], wfl);
                            intent.putExtra(LocationManager.KEY_LOCATION_CHANGED, loc);
                            pi.send(GPSMockManager.getInstance().getAppContext(),
                                    0, intent, null, null);
                        } catch (Exception ex) {
                            WFLog.e(TAG, "PendingIntent send: " + ex.getMessage());
                        }
                        WFLog.hook("LM.requestLocationUpdates(PI)", wfl);
                    }
                }
            );
        } catch (Exception e) { WFLog.d(TAG, "LM.requestLocationUpdates(PI): " + e.getMessage()); }

        // 4) requestSingleUpdate (String, LocationListener, Looper)
        try {
            XposedHelpers.findAndHookMethod(
                LocationManager.class.getName(), lpparam.classLoader,
                "requestSingleUpdate",
                String.class, LocationListener.class, android.os.Looper.class,
                new XC_MethodHook() {
                    @Override protected void afterHookedMethod(MethodHookParam param) {
                        if (!GPSMockManager.getInstance().isMocking()) return;
                        WFLocation wfl = GPSMockManager.getInstance().getLocation();
                        if (wfl == null) return;
                        LocationListener listener = (LocationListener) param.args[1];
                        if (listener == null) return;
                        try {
                            listener.onLocationChanged(GPSMockManager.getInstance()
                                .buildLocation((String) param.args[0], wfl));
                        } catch (Exception ignored) {}
                    }
                }
            );
        } catch (Exception e) { WFLog.d(TAG, "requestSingleUpdate: " + e.getMessage()); }

        // 5) getCurrentLocation (API 30+)
        try {
            XposedHelpers.findAndHookMethod(
                LocationManager.class.getName(), lpparam.classLoader,
                "getCurrentLocation",
                String.class, android.os.CancellationSignal.class,
                java.util.concurrent.Executor.class,
                lpparam.classLoader.loadClass("java.util.function.Consumer"),
                new XC_MethodHook() {
                    @Override protected void beforeHookedMethod(MethodHookParam param) {
                        if (!GPSMockManager.getInstance().isMocking()) return;
                        WFLocation wfl = GPSMockManager.getInstance().getLocation();
                        if (wfl == null) return;
                        try {
                            Object consumer = param.args[3];
                            Location loc = GPSMockManager.getInstance()
                                .buildLocation((String) param.args[0], wfl);
                            consumer.getClass()
                                .getMethod("accept", Object.class).invoke(consumer, loc);
                            param.setResult(null);
                        } catch (Exception ex) {
                            WFLog.e(TAG, "getCurrentLocation: " + ex.getMessage());
                        }
                    }
                }
            );
        } catch (Exception e) { WFLog.d(TAG, "getCurrentLocation(API30+): " + e.getMessage()); }
    }

    // ─── FusedLocationProviderClient ─────────────────────────────────────────

    private void hookFusedLocation(XC_LoadPackage.LoadPackageParam lpparam) {

        // getLastLocation()
        try {
            XposedHelpers.findAndHookMethod(
                "com.google.android.gms.location.FusedLocationProviderClient",
                lpparam.classLoader, "getLastLocation",
                new XC_MethodHook() {
                    @Override protected void afterHookedMethod(MethodHookParam param) {
                        if (!GPSMockManager.getInstance().isMocking()) return;
                        WFLocation wfl = GPSMockManager.getInstance().getLocation();
                        if (wfl == null) return;
                        Location loc = GPSMockManager.getInstance()
                            .buildLocation(LocationManager.GPS_PROVIDER, wfl);
                        Object task = buildFakeTask(loc, lpparam.classLoader);
                        if (task != null) param.setResult(task);
                        WFLog.hook("Fused.getLastLocation", wfl);
                    }
                }
            );
        } catch (Exception e) { WFLog.d(TAG, "Fused.getLastLocation: " + e.getMessage()); }

        // requestLocationUpdates(LocationRequest, LocationCallback, Looper)
        try {
            Class<?> callbackClass = lpparam.classLoader
                .loadClass("com.google.android.gms.location.LocationCallback");
            Class<?> requestClass  = lpparam.classLoader
                .loadClass("com.google.android.gms.location.LocationRequest");

            XposedHelpers.findAndHookMethod(
                "com.google.android.gms.location.FusedLocationProviderClient",
                lpparam.classLoader, "requestLocationUpdates",
                requestClass, callbackClass, android.os.Looper.class,
                new XC_MethodHook() {
                    @Override protected void afterHookedMethod(MethodHookParam param) {
                        if (!GPSMockManager.getInstance().isMocking()) return;
                        WFLocation wfl = GPSMockManager.getInstance().getLocation();
                        if (wfl == null || param.args[1] == null) return;
                        injectFusedCallback(param.args[1], wfl, lpparam.classLoader);
                        WFLog.hook("Fused.requestLocationUpdates→cb", wfl);
                    }
                }
            );
        } catch (Exception e) { WFLog.d(TAG, "Fused.requestLocationUpdates: " + e.getMessage()); }

        // LocationResult.getLastLocation()
        try {
            XposedHelpers.findAndHookMethod(
                "com.google.android.gms.location.LocationResult",
                lpparam.classLoader, "getLastLocation",
                new XC_MethodHook() {
                    @Override protected void afterHookedMethod(MethodHookParam param) {
                        if (!GPSMockManager.getInstance().isMocking()) return;
                        WFLocation wfl = GPSMockManager.getInstance().getLocation();
                        if (wfl == null) return;
                        param.setResult(GPSMockManager.getInstance()
                            .buildLocation(LocationManager.GPS_PROVIDER, wfl));
                    }
                }
            );
        } catch (Exception e) { WFLog.d(TAG, "LocationResult.getLastLocation: " + e.getMessage()); }

        // LocationResult.getLocations()
        try {
            XposedHelpers.findAndHookMethod(
                "com.google.android.gms.location.LocationResult",
                lpparam.classLoader, "getLocations",
                new XC_MethodHook() {
                    @Override protected void afterHookedMethod(MethodHookParam param) {
                        if (!GPSMockManager.getInstance().isMocking()) return;
                        WFLocation wfl = GPSMockManager.getInstance().getLocation();
                        if (wfl == null) return;
                        Location loc = GPSMockManager.getInstance()
                            .buildLocation(LocationManager.GPS_PROVIDER, wfl);
                        java.util.List<Location> list = new java.util.ArrayList<>();
                        list.add(loc);
                        param.setResult(list);
                        WFLog.hook("LocationResult.getLocations", wfl);
                    }
                }
            );
        } catch (Exception e) { WFLog.d(TAG, "LocationResult.getLocations: " + e.getMessage()); }

        // LocationAvailability.isLocationAvailable() → true
        try {
            XposedHelpers.findAndHookMethod(
                "com.google.android.gms.location.LocationAvailability",
                lpparam.classLoader, "isLocationAvailable",
                new XC_MethodHook() {
                    @Override protected void afterHookedMethod(MethodHookParam param) {
                        if (GPSMockManager.getInstance().isMocking()) param.setResult(true);
                    }
                }
            );
        } catch (Exception e) { WFLog.d(TAG, "LocationAvailability: " + e.getMessage()); }
    }

    private void injectFusedCallback(Object callback, WFLocation wfl, ClassLoader cl) {
        try {
            Location loc = GPSMockManager.getInstance()
                .buildLocation(LocationManager.GPS_PROVIDER, wfl);
            java.util.List<Location> locations = new java.util.ArrayList<>();
            locations.add(loc);
            Class<?> resultClass = cl.loadClass("com.google.android.gms.location.LocationResult");
            Object locationResult = resultClass
                .getMethod("create", java.util.List.class).invoke(null, locations);
            callback.getClass()
                .getMethod("onLocationResult", resultClass).invoke(callback, locationResult);
        } catch (Exception e) { WFLog.e(TAG, "injectFusedCallback: " + e.getMessage()); }
    }

    private Object buildFakeTask(Location loc, ClassLoader cl) {
        try {
            Class<?> tasks = cl.loadClass("com.google.android.gms.tasks.Tasks");
            return tasks.getMethod("forResult", Object.class).invoke(null, loc);
        } catch (Exception e) {
            WFLog.e(TAG, "buildFakeTask: " + e.getMessage());
            return null;
        }
    }

    // ─── WebView / navigator.geolocation ─────────────────────────────────────

    private void hookWebView(XC_LoadPackage.LoadPackageParam lpparam) {
        XC_MethodHook geoHook = new XC_MethodHook() {
            @Override protected void afterHookedMethod(MethodHookParam param) {
                injectGeoJs((android.webkit.WebView) param.thisObject);
            }
        };
        try {
            XposedHelpers.findAndHookMethod("android.webkit.WebView",
                lpparam.classLoader, "loadUrl", String.class, geoHook);
        } catch (Exception e) { WFLog.d(TAG, "WebView.loadUrl: " + e.getMessage()); }
        try {
            XposedHelpers.findAndHookMethod("android.webkit.WebView",
                lpparam.classLoader, "loadDataWithBaseURL",
                String.class, String.class, String.class, String.class, String.class, geoHook);
        } catch (Exception e) { WFLog.d(TAG, "WebView.loadData: " + e.getMessage()); }
    }

    private void injectGeoJs(android.webkit.WebView wv) {
        if (wv == null || !GPSMockManager.getInstance().isMocking()) return;
        WFLocation wfl = GPSMockManager.getInstance().getLocation();
        if (wfl == null) return;
        String js = "(function(){"
            + "var pos={coords:{latitude:" + wfl.getLatitude()
            + ",longitude:" + wfl.getLongitude()
            + ",accuracy:1,altitude:0,altitudeAccuracy:null,heading:null,speed:null},"
            + "timestamp:" + System.currentTimeMillis() + "};"
            + "navigator.geolocation={"
            + "getCurrentPosition:function(s){s(pos);},"
            + "watchPosition:function(s){s(pos);return 1;},"
            + "clearWatch:function(){}"
            + "};})();";
        try { wv.evaluateJavascript(js, null); }
        catch (Exception e) { WFLog.e(TAG, "injectGeoJs: " + e.getMessage()); }
    }
}
