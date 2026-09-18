package com.wolfox.gps.manager;

import android.content.Context;
import android.location.Location;

import com.wolfox.gps.model.WFLocation;

/**
 * GPSManager — الواجهة الرسمية لإدارة GPS
 *
 * Facade فوق GPSMockManager.
 * بقية المشروع تتعامل مع GPSManager فقط.
 */
public class GPSManager {

    private static GPSManager instance;
    private final GPSMockManager mock = GPSMockManager.getInstance();

    private GPSManager() {}

    public static synchronized GPSManager getInstance() {
        if (instance == null) instance = new GPSManager();
        return instance;
    }

    public void init(Context ctx)                  { mock.init(ctx); }
    public void setLocation(WFLocation loc)        { mock.setLocation(loc); }
    public WFLocation getLocation()                { return mock.getLocation(); }
    public boolean hasMockLocation()               { return mock.hasMockLocation(); }
    public void startMocking()                     { mock.startMocking(); }
    public void stopMocking()                      { mock.stopMocking(); }
    public boolean isMocking()                     { return mock.isMocking(); }

    public Location buildAndroidLocation(String provider) {
        WFLocation wfl = mock.getLocation();
        if (wfl == null) return null;
        return mock.buildLocation(provider, wfl);
    }
}
