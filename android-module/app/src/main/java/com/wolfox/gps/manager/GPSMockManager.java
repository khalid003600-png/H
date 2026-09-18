package com.wolfox.gps.manager;

import android.content.Context;
import android.location.Location;
import android.location.LocationManager;
import android.os.Build;
import android.os.SystemClock;

import com.wolfox.gps.model.WFLocation;
import com.wolfox.gps.util.WFLog;
import com.wolfox.gps.util.WFStorage;

/**
 * GPSMockManager — مدير التزييف عبر الهوكات
 *
 * FIX: setIsFromMockProvider(false) لإخفاء علامة المحاكاة
 * FIX: getAppContext() مُضافة لاستخدامها في PendingIntent hook
 * FIX: استعادة accuracy/altitude/speed من WFStorage عند init
 */
public class GPSMockManager {

    private static final String TAG = "GPSMockManager";

    private static GPSMockManager instance;

    private volatile WFLocation currentLocation;
    private volatile boolean    mocking = false;
    private Context             appContext;

    private GPSMockManager() {}

    public static synchronized GPSMockManager getInstance() {
        if (instance == null) instance = new GPSMockManager();
        return instance;
    }

    public void init(Context ctx) {
        if (this.appContext != null || ctx == null) return;
        this.appContext = ctx.getApplicationContext();

        WFStorage store = WFStorage.getInstance(appContext);
        if (store.isMocking()) {
            WFLocation last = store.getLastLocation();
            if (last != null) {
                // FIX: استعادة accuracy/altitude/speed المحفوظة
                last.setAccuracy(store.getSavedAccuracy());
                last.setAltitude(store.getSavedAltitude());
                last.setSpeed(store.getSavedSpeed());
                this.currentLocation = last;
                this.mocking = true;
                WFLog.i(TAG, "استعادة جلسة: " + last);
            }
        }
    }

    public Context getAppContext() { return appContext; }

    public void setLocation(WFLocation loc) {
        if (loc == null || !loc.isValid()) { WFLog.w(TAG, "موقع غير صالح"); return; }
        // FIX: نطبّق الإعدادات المحفوظة على الموقع الجديد إذا لم تُحدَّد
        if (appContext != null) {
            WFStorage store = WFStorage.getInstance(appContext);
            if (loc.getAccuracy() == 1.0f) loc.setAccuracy(store.getSavedAccuracy());
            if (loc.getAltitude() == 0.0)  loc.setAltitude(store.getSavedAltitude());
            if (loc.getSpeed() == 0.0f)    loc.setSpeed(store.getSavedSpeed());
        }
        this.currentLocation = loc;
        if (appContext != null) WFStorage.getInstance(appContext).saveLastLocation(loc);
        WFLog.i(TAG, "setLocation: " + loc);
    }

    public WFLocation getLocation()    { return currentLocation; }
    public boolean hasMockLocation()   { return currentLocation != null && currentLocation.isValid(); }

    public void startMocking() {
        if (!hasMockLocation()) { WFLog.w(TAG, "لا يوجد موقع محدد"); return; }
        mocking = true;
        if (appContext != null) WFStorage.getInstance(appContext).setMocking(true);
        WFLog.i(TAG, "▶ بدء التزييف: " + currentLocation);
    }

    public void stopMocking() {
        mocking = false;
        if (appContext != null) WFStorage.getInstance(appContext).setMocking(false);
        WFLog.i(TAG, "⏹ إيقاف التزييف");
    }

    public boolean isMocking() { return mocking; }

    /**
     * بناء Location — FIX: setIsFromMockProvider(false)
     */
    public Location buildLocation(String provider, WFLocation wfLoc) {
        Location loc = new Location(provider != null ? provider : LocationManager.GPS_PROVIDER);
        loc.setLatitude(wfLoc.getLatitude());
        loc.setLongitude(wfLoc.getLongitude());
        loc.setAltitude(wfLoc.getAltitude());
        loc.setAccuracy(wfLoc.getAccuracy());
        loc.setSpeed(wfLoc.getSpeed());
        loc.setBearing(wfLoc.getBearing());
        loc.setTime(System.currentTimeMillis());

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            loc.setElapsedRealtimeNanos(SystemClock.elapsedRealtimeNanos());
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            loc.setVerticalAccuracyMeters(1.0f);
            loc.setSpeedAccuracyMetersPerSecond(0.0f);
            loc.setBearingAccuracyDegrees(0.0f);
        }

        // FIX: إخفاء علامة mock
        try { loc.setIsFromMockProvider(false); }
        catch (NoSuchMethodError | Exception ignored) {}

        return loc;
    }
}
