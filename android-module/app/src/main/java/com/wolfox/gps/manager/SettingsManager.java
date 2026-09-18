package com.wolfox.gps.manager;

import android.content.Context;

import com.wolfox.gps.util.WFStorage;

/**
 * SettingsManager — إدارة إعدادات الموديول
 * Facade فوق WFStorage لعمليات الإعدادات.
 */
public class SettingsManager {

    private static SettingsManager instance;
    private Context ctx;

    private SettingsManager() {}

    public static synchronized SettingsManager getInstance() {
        if (instance == null) instance = new SettingsManager();
        return instance;
    }

    public void init(Context ctx) { this.ctx = ctx.getApplicationContext(); }

    // ─── نوع الخريطة ──────────────────────────────────────────────────────────
    public String getMapType()              { return store().getMapType(); }
    public void   setMapType(String type)   { store().setMapType(type); }

    // ─── الترخيص ──────────────────────────────────────────────────────────────
    public String  getLicenseStatus()       { return store().getLicenseStatus(); }
    public boolean isLicenseActive()        { return store().isLicenseActive(); }
    public void    setLicenseStatus(String s){ store().setLicenseStatus(s); }

    // ─── حالة التزييف ─────────────────────────────────────────────────────────
    public boolean isMocking()              { return store().isMocking(); }
    public void    setMocking(boolean b)    { store().setMocking(b); }

    private WFStorage store() { return WFStorage.getInstance(ctx); }
}
