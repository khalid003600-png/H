package com.wolfox.gps.ui;

import android.app.Activity;
import android.content.Context;

import com.wolfox.gps.manager.FloatingManager;
import com.wolfox.gps.manager.GPSMockManager;
import com.wolfox.gps.util.WFStorage;

/**
 * WolFoxUI — نقطة التجميع المركزية لواجهات المستخدم
 *
 * FIX: onAppReady لا تُظهر شاشة الترخيص إذا كانت مُعروضة بالفعل —
 *      منع تكرار عرض WolFoxLicense في كل onResume.
 */
public class WolFoxUI {

    /**
     * نقطة الدخول الرئيسية — تُستدعى من ActivityHook.onResume
     *
     * القرار:
     *   ✅ مفعّل  → أظهر الأيقونة العائمة (FloatingManager يتولى ذلك)
     *   ❌ غير مفعّل → أظهر واجهة التفعيل (مرة واحدة فقط)
     */
    public static void onAppReady(Activity activity) {
        if (activity == null || activity.isFinishing()) return;

        if (WFStorage.getInstance(activity).isLicenseActive()) {
            // مفعّل — FloatingManager.onActivityResumed تولّت الأمر في ActivityHook
            // لا نحتاج إضافية هنا
        } else {
            // FIX: checkAndShowIfNeeded تتجنب إعادة العرض إذا كانت مُفتوحة
            WolFoxLicense.checkAndShowIfNeeded(activity);
        }
    }

    /**
     * فتح اللوحة الرئيسية (عند الضغط على الأيقونة العائمة)
     */
    public static void openPanel(Activity activity) {
        if (!WFStorage.getInstance(activity).isLicenseActive()) return;
        WolFoxPanel.show(activity);
    }

    public static void openSearch(Activity activity)    { SearchDialog.show(activity); }
    public static void openFavorites(Activity activity) { FavoritesDialog.show(activity); }
    public static void openHistory(Activity activity)   { HistoryDialog.show(activity); }
    public static void openMap(Activity activity)       { MapDialog.show(activity); }
    public static void openSettings(Activity activity)  { SettingsDialog.show(activity); }

    public static boolean isMocking() {
        return GPSMockManager.getInstance().isMocking();
    }

    public static void startMock(Context ctx) {
        GPSMockManager.getInstance().startMocking();
    }

    public static void stopMock(Context ctx) {
        GPSMockManager.getInstance().stopMocking();
    }
}
