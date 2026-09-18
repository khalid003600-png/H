package com.wolfox.gps.util;

import android.util.Log;
import com.wolfox.gps.model.WFLocation;

public class WFLog {
    private static boolean debug = true;
    private static final String PREFIX = "WolFox";

    public static void setDebug(boolean on) { debug = on; }
    public static void i(String tag, String msg) { if(debug) Log.i(PREFIX+"/"+tag, msg); }
    public static void d(String tag, String msg) { if(debug) Log.d(PREFIX+"/"+tag, msg); }
    public static void w(String tag, String msg) { Log.w(PREFIX+"/"+tag, msg); }
    public static void e(String tag, String msg) { Log.e(PREFIX+"/"+tag, msg); }

    public static void hook(String method, WFLocation loc) {
        if(debug) Log.i(PREFIX+"/Hook",
            method + " → " + String.format("%.6f,%.6f", loc.getLatitude(), loc.getLongitude()));
    }
}
