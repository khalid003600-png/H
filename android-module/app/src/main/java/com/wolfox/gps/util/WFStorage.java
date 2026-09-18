package com.wolfox.gps.util;

import android.content.Context;
import android.content.SharedPreferences;

import com.wolfox.gps.model.FavoriteLocation;
import com.wolfox.gps.model.HistoryEntry;
import com.wolfox.gps.model.WFLocation;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class WFStorage {

    private static final String PREF_NAME          = "wolfox_gps_prefs";
    private static final String KEY_FAVORITES      = "favorites";
    private static final String KEY_HISTORY        = "history";
    private static final String KEY_LAST_LAT_BITS  = "last_lat_bits";
    private static final String KEY_LAST_LNG_BITS  = "last_lng_bits";
    private static final String KEY_LAST_ALT       = "last_alt";
    private static final String KEY_LAST_ACCURACY  = "last_accuracy";
    private static final String KEY_LAST_SPEED     = "last_speed";
    private static final String KEY_IS_MOCKING     = "is_mocking";
    private static final String KEY_MAP_TYPE       = "map_type";
    private static final String KEY_LICENSE_STATUS = "license_status";
    private static final int    MAX_HISTORY        = 200;

    private static WFStorage instance;
    private final SharedPreferences prefs;

    private WFStorage(Context context) {
        prefs = context.getApplicationContext()
                       .getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
    }

    public static synchronized WFStorage getInstance(Context context) {
        if (instance == null) instance = new WFStorage(context);
        return instance;
    }

    // ─── الموقع الأخير (double precision) ────────────────────────────────────

    public void saveLastLocation(WFLocation loc) {
        if (loc == null) return;
        prefs.edit()
             .putLong(KEY_LAST_LAT_BITS, Double.doubleToLongBits(loc.getLatitude()))
             .putLong(KEY_LAST_LNG_BITS, Double.doubleToLongBits(loc.getLongitude()))
             .putLong(KEY_LAST_ALT,      Double.doubleToLongBits(loc.getAltitude()))
             .putFloat(KEY_LAST_ACCURACY, loc.getAccuracy())
             .putFloat(KEY_LAST_SPEED,    loc.getSpeed())
             .apply();
    }

    public WFLocation getLastLocation() {
        if (!prefs.contains(KEY_LAST_LAT_BITS)) return null;
        double lat = Double.longBitsToDouble(prefs.getLong(KEY_LAST_LAT_BITS, 0L));
        double lng = Double.longBitsToDouble(prefs.getLong(KEY_LAST_LNG_BITS, 0L));
        if (lat == 0.0 && lng == 0.0) return null;
        WFLocation loc = new WFLocation(lat, lng);
        loc.setAltitude(Double.longBitsToDouble(prefs.getLong(KEY_LAST_ALT, 0L)));
        loc.setAccuracy(prefs.getFloat(KEY_LAST_ACCURACY, 1.0f));
        loc.setSpeed(prefs.getFloat(KEY_LAST_SPEED, 0.0f));
        return loc;
    }

    // ─── إعدادات الموقع الدائمة ───────────────────────────────────────────────

    public void saveLocationSettings(float accuracy, double altitude, float speed) {
        prefs.edit()
             .putFloat(KEY_LAST_ACCURACY, accuracy)
             .putLong(KEY_LAST_ALT, Double.doubleToLongBits(altitude))
             .putFloat(KEY_LAST_SPEED, speed)
             .apply();
    }

    public float  getSavedAccuracy() { return prefs.getFloat(KEY_LAST_ACCURACY, 1.0f); }
    public double getSavedAltitude() { return Double.longBitsToDouble(prefs.getLong(KEY_LAST_ALT, 0L)); }
    public float  getSavedSpeed()    { return prefs.getFloat(KEY_LAST_SPEED, 0.0f); }

    // ─── حالة التزييف ─────────────────────────────────────────────────────────

    public void setMocking(boolean active) { prefs.edit().putBoolean(KEY_IS_MOCKING, active).apply(); }
    public boolean isMocking()             { return prefs.getBoolean(KEY_IS_MOCKING, false); }

    // ─── نوع الخريطة ──────────────────────────────────────────────────────────

    public void   setMapType(String type) { prefs.edit().putString(KEY_MAP_TYPE, type).apply(); }
    public String getMapType()            { return prefs.getString(KEY_MAP_TYPE, "roadmap"); }

    // ─── حالة الترخيص ─────────────────────────────────────────────────────────

    public void    setLicenseStatus(String s) { prefs.edit().putString(KEY_LICENSE_STATUS, s).apply(); }
    public String  getLicenseStatus()         { return prefs.getString(KEY_LICENSE_STATUS, ""); }
    public boolean isLicenseActive()          { return "Active".equalsIgnoreCase(getLicenseStatus()); }

    // ─── المفضلة ──────────────────────────────────────────────────────────────

    public List<FavoriteLocation> getFavorites() {
        List<FavoriteLocation> list = new ArrayList<>();
        String json = prefs.getString(KEY_FAVORITES, "[]");
        try {
            JSONArray arr = new JSONArray(json);
            for (int i = 0; i < arr.length(); i++)
                list.add(FavoriteLocation.fromJson(arr.getJSONObject(i)));
        } catch (JSONException e) { WFLog.e("WFStorage", "getFavorites: " + e.getMessage()); }
        return list;
    }

    public void saveFavorites(List<FavoriteLocation> list) {
        JSONArray arr = new JSONArray();
        for (FavoriteLocation f : list) {
            try { arr.put(f.toJson()); } catch (JSONException ignored) {}
        }
        prefs.edit().putString(KEY_FAVORITES, arr.toString()).apply();
    }

    public void addFavorite(FavoriteLocation fav) {
        fav.setId(System.currentTimeMillis());
        List<FavoriteLocation> list = getFavorites();
        list.add(fav);
        saveFavorites(list);
    }

    public void updateFavorite(FavoriteLocation fav) {
        List<FavoriteLocation> list = getFavorites();
        for (int i = 0; i < list.size(); i++) {
            if (list.get(i).getId() == fav.getId()) {
                fav.setUpdatedAt(System.currentTimeMillis());
                list.set(i, fav);
                break;
            }
        }
        saveFavorites(list);
    }

    public void deleteFavorite(long id) {
        List<FavoriteLocation> list = getFavorites();
        for (int i = list.size() - 1; i >= 0; i--) {
            if (list.get(i).getId() == id) { list.remove(i); break; }
        }
        saveFavorites(list);
    }

    // ─── السجل ────────────────────────────────────────────────────────────────

    public List<HistoryEntry> getHistory() {
        List<HistoryEntry> list = new ArrayList<>();
        String json = prefs.getString(KEY_HISTORY, "[]");
        try {
            JSONArray arr = new JSONArray(json);
            for (int i = 0; i < arr.length(); i++)
                list.add(HistoryEntry.fromJson(arr.getJSONObject(i)));
        } catch (JSONException e) { WFLog.e("WFStorage", "getHistory: " + e.getMessage()); }
        return list;
    }

    public void addHistory(HistoryEntry entry) {
        entry.setId(System.currentTimeMillis());
        List<HistoryEntry> list = getHistory();
        list.add(0, entry);
        if (list.size() > MAX_HISTORY) list = list.subList(0, MAX_HISTORY);
        JSONArray arr = new JSONArray();
        for (HistoryEntry h : list) {
            try { arr.put(h.toJson()); } catch (JSONException ignored) {}
        }
        prefs.edit().putString(KEY_HISTORY, arr.toString()).apply();
    }

    public void clearHistory() { prefs.edit().putString(KEY_HISTORY, "[]").apply(); }

    // ─── تصدير / استيراد ──────────────────────────────────────────────────────

    public String  exportFavoritesJson() { return prefs.getString(KEY_FAVORITES, "[]"); }

    public boolean importFavoritesJson(String json) {
        try {
            JSONArray arr = new JSONArray(json);
            prefs.edit().putString(KEY_FAVORITES, arr.toString()).apply();
            return true;
        } catch (JSONException e) {
            WFLog.e("WFStorage", "importFavorites: " + e.getMessage());
            return false;
        }
    }
}
