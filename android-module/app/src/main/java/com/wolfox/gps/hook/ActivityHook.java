package com.wolfox.gps.hook;

import android.app.Activity;
import android.content.Context;

import com.wolfox.gps.manager.FavoritesManager;
import com.wolfox.gps.manager.FloatingManager;
import com.wolfox.gps.manager.GPSManager;
import com.wolfox.gps.manager.HistoryManager;
import com.wolfox.gps.manager.SettingsManager;
import com.wolfox.gps.ui.WolFoxUI;
import com.wolfox.gps.util.WFLog;

import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/**
 * ActivityHook — يعترض دورة حياة Activity
 *
 * FIX: onResume يستدعي FloatingManager.onActivityResumed(act) لإعادة
 *      ربط الأيقونة بالـ Activity الجديد بشكل صحيح — كان ينقصه هذا.
 */
public class ActivityHook {

    private static final String TAG = "ActivityHook";

    public static void install(XC_LoadPackage.LoadPackageParam lpparam) {

        // ─ onCreate ──────────────────────────────────────────────────────────
        try {
            XposedHelpers.findAndHookMethod(
                Activity.class.getName(), lpparam.classLoader, "onCreate",
                android.os.Bundle.class,
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        Activity act = (Activity) param.thisObject;
                        Context ctx  = act.getApplicationContext();
                        GPSManager.getInstance().init(ctx);
                        FavoritesManager.getInstance().init(ctx);
                        HistoryManager.getInstance().init(ctx);
                        SettingsManager.getInstance().init(ctx);
                        WFLog.d(TAG, "onCreate: managers initialized");
                    }
                }
            );
        } catch (Exception e) { WFLog.e(TAG, "hook onCreate: " + e.getMessage()); }

        // ─ onResume ──────────────────────────────────────────────────────────
        try {
            XposedHelpers.findAndHookMethod(
                Activity.class.getName(), lpparam.classLoader, "onResume",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        Activity act = (Activity) param.thisObject;
                        WFLog.d(TAG, "onResume: " + act.getClass().getSimpleName());
                        // FIX: إبلاغ FloatingManager بالـ Activity الحالي أولاً
                        FloatingManager.getInstance().onActivityResumed(act);
                        // ثم قرار الواجهة
                        WolFoxUI.onAppReady(act);
                    }
                }
            );
        } catch (Exception e) { WFLog.e(TAG, "hook onResume: " + e.getMessage()); }

        // ─ onPause ───────────────────────────────────────────────────────────
        try {
            XposedHelpers.findAndHookMethod(
                Activity.class.getName(), lpparam.classLoader, "onPause",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        FloatingManager.getInstance().onActivityPaused();
                    }
                }
            );
        } catch (Exception e) { WFLog.e(TAG, "hook onPause: " + e.getMessage()); }

        // ─ onDestroy ─────────────────────────────────────────────────────────
        try {
            XposedHelpers.findAndHookMethod(
                Activity.class.getName(), lpparam.classLoader, "onDestroy",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        FloatingManager.getInstance().onActivityDestroyed();
                    }
                }
            );
        } catch (Exception e) { WFLog.e(TAG, "hook onDestroy: " + e.getMessage()); }
    }
}
