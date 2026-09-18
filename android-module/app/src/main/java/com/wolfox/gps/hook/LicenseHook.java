package com.wolfox.gps.hook;

import android.app.Activity;
import android.content.Context;

import com.wolfox.gps.manager.FloatingManager;
import com.wolfox.gps.model.HistoryEntry;
import com.wolfox.gps.util.WFLog;
import com.wolfox.gps.util.WFStorage;

import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/**
 * LicenseHook — يراقب نتيجة التحقق من الترخيص
 *
 * FIX: تجربة توقيعات متعددة للدوال (String، JSONObject، Object)
 *      لتغطية أشكال مختلفة من استجابات API في تطبيقات k7.gps.
 */
public class LicenseHook {

    private static final String TAG = "LicenseHook";

    private static final String[] LICENSE_CLASSES = {
            "com.wolfox.gps.WolFoxLicense",
            "k7.gps.license.LicenseManager",
            "k7.gps.activation.ActivationHelper",
            "k7.gps.network.ApiClient"
    };

    private static final String[] LICENSE_METHODS = {
            "onLicenseResult",
            "onActivationResult",
            "setLicenseStatus",
            "handleResponse",
            "onSuccess"
    };

    public static void install(XC_LoadPackage.LoadPackageParam lpparam) {
        for (String className : LICENSE_CLASSES) {
            for (String method : LICENSE_METHODS) {
                // FIX: جرّب ثلاثة توقيعات مختلفة
                tryHookString(lpparam, className, method);
                tryHookObject(lpparam, className, method);
            }
        }
    }

    /** توقيع (String) */
    private static void tryHookString(XC_LoadPackage.LoadPackageParam lpparam,
                                       String className, String method) {
        try {
            Class<?> cls = lpparam.classLoader.loadClass(className);
            XposedHelpers.findAndHookMethod(cls, method, String.class,
                    new XC_MethodHook() {
                        @Override
                        protected void afterHookedMethod(MethodHookParam param) {
                            handleLicenseResult(param.thisObject, (String) param.args[0]);
                        }
                    });
            WFLog.i(TAG, "hooked(String): " + className + "." + method);
        } catch (Exception e) {
            WFLog.d(TAG, "skip(String): " + className + "." + method);
        }
    }

    /** توقيع (Object) — يغطي JSONObject أو أي كلاس استجابة */
    private static void tryHookObject(XC_LoadPackage.LoadPackageParam lpparam,
                                       String className, String method) {
        try {
            Class<?> cls = lpparam.classLoader.loadClass(className);
            XposedHelpers.findAndHookMethod(cls, method, Object.class,
                    new XC_MethodHook() {
                        @Override
                        protected void afterHookedMethod(MethodHookParam param) {
                            if (param.args[0] != null) {
                                handleLicenseResult(param.thisObject,
                                        param.args[0].toString());
                            }
                        }
                    });
            WFLog.i(TAG, "hooked(Object): " + className + "." + method);
        } catch (Exception e) {
            WFLog.d(TAG, "skip(Object): " + className + "." + method);
        }
    }

    public static void notifyActivated(Context ctx, Activity activity) {
        WFStorage.getInstance(ctx).setLicenseStatus("Active");
        WFStorage.getInstance(ctx).addHistory(
                new HistoryEntry(HistoryEntry.Action.ACTIVATE, "✅ تم التفعيل")
        );
        if (activity != null && !activity.isFinishing()) {
            FloatingManager.getInstance().show(activity);
            WFLog.i(TAG, "notifyActivated → Floating shown");
        }
    }

    private static void handleLicenseResult(Object host, String result) {
        if (result == null) return;
        boolean active = result.contains("Active")
                || result.contains("active")
                || result.contains("\"status\":\"Active\"");

        if (!active) {
            WFLog.d(TAG, "licenseResult: not active → " + result);
            return;
        }

        WFLog.i(TAG, "licenseResult: ACTIVE ✅");

        Context ctx = null;
        try {
            ctx = (Context) host.getClass().getMethod("getApplicationContext").invoke(host);
        } catch (Exception ignored) {}

        if (ctx != null) {
            WFStorage.getInstance(ctx).setLicenseStatus("Active");
            WFStorage.getInstance(ctx).addHistory(
                    new HistoryEntry(HistoryEntry.Action.ACTIVATE, "تم التفعيل تلقائياً")
            );
        }

        Activity currentAct = FloatingManager.getInstance().getCurrentActivity();
        if (currentAct != null && !currentAct.isFinishing()) {
            currentAct.runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    FloatingManager.getInstance().show(currentAct);
                }
            });
        }
    }
}
