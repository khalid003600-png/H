package com.wolfox.gps.ui;

import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.*;

import com.wolfox.gps.manager.GPSMockManager;
import com.wolfox.gps.model.WFLocation;
import com.wolfox.gps.util.WFLog;
import com.wolfox.gps.util.WFStorage;

/**
 * SettingsDialog
 *
 * FIX: accuracy/altitude/speed تُحفظ الآن في WFStorage عند الضغط "حفظ"
 *      وتُستعاد عند فتح الإعدادات من القيم المحفوظة مسبقاً.
 */
public class SettingsDialog {

    private static final int COLOR_BG    = 0xFF070B18;
    private static final int COLOR_GOLD  = 0xFFC9A227;
    private static final int COLOR_WHITE = 0xFFFFFFFF;
    private static final int COLOR_CARD  = 0xFF0E1428;

    public static void show(Activity activity) {
        if (activity == null || activity.isFinishing()) return;
        activity.runOnUiThread(() -> buildAndShow(activity));
    }

    private static void buildAndShow(Activity activity) {
        Dialog dialog = new Dialog(activity, android.R.style.Theme_Material_Dialog);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        dialog.setCancelable(true);
        Window w = dialog.getWindow();
        if (w != null) {
            w.setBackgroundDrawableResource(android.R.color.transparent);
            w.setLayout(
                    (int)(activity.getResources().getDisplayMetrics().widthPixels * 0.92),
                    ViewGroup.LayoutParams.WRAP_CONTENT);
            w.setGravity(Gravity.CENTER);
        }

        WFStorage store = WFStorage.getInstance(activity);

        // ── استعادة القيم المحفوظة ──
        float  savedAccuracy = store.getSavedAccuracy();
        double savedAltitude = store.getSavedAltitude();
        float  savedSpeed    = store.getSavedSpeed();

        LinearLayout root = new LinearLayout(activity);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(COLOR_BG);
        root.setPadding(dp(activity,16), dp(activity,16), dp(activity,16), dp(activity,16));

        TextView title = new TextView(activity);
        title.setText("⚙ الإعدادات");
        title.setTextColor(COLOR_GOLD);
        title.setTextSize(16);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        root.addView(title);
        addDivider(root, activity);

        // ─ دقة الموقع ─
        root.addView(buildLabel(activity, "دقة الموقع المزيف"));
        SeekBar accuracyBar = new SeekBar(activity);
        accuracyBar.setMax(100);
        accuracyBar.setProgress(Math.round(savedAccuracy));
        root.addView(accuracyBar);

        TextView accuracyVal = new TextView(activity);
        accuracyVal.setText("الدقة: " + Math.round(savedAccuracy) + " متر");
        accuracyVal.setTextColor(COLOR_WHITE);
        accuracyVal.setTextSize(12);
        root.addView(accuracyVal);

        // الحالة الداخلية للـ SeekBar
        final float[] currentAccuracy = {savedAccuracy};
        accuracyBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar s, int prog, boolean user) {
                currentAccuracy[0] = Math.max(1, prog);
                accuracyVal.setText("الدقة: " + Math.round(currentAccuracy[0]) + " متر");
            }
            @Override public void onStartTrackingTouch(SeekBar s) {}
            @Override public void onStopTrackingTouch(SeekBar s) {}
        });

        addSpacing(root, activity, 12);

        // ─ الارتفاع ─
        root.addView(buildLabel(activity, "الارتفاع (Altitude)"));
        EditText altEt = new EditText(activity);
        altEt.setText(savedAltitude == 0.0 ? "" : String.valueOf(savedAltitude));
        altEt.setHint("0.0");
        altEt.setHintTextColor(0xFF666666);
        altEt.setTextColor(COLOR_WHITE);
        altEt.setInputType(android.text.InputType.TYPE_CLASS_NUMBER
                | android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL);
        altEt.setBackgroundColor(COLOR_CARD);
        altEt.setPadding(dp(activity,10), dp(activity,8), dp(activity,10), dp(activity,8));
        root.addView(altEt);

        addSpacing(root, activity, 12);

        // ─ السرعة ─
        root.addView(buildLabel(activity, "السرعة (م/ث)"));
        SeekBar speedBar = new SeekBar(activity);
        speedBar.setMax(200);
        speedBar.setProgress(Math.round(savedSpeed));
        root.addView(speedBar);

        TextView speedVal = new TextView(activity);
        speedVal.setText("السرعة: " + Math.round(savedSpeed) + " م/ث");
        speedVal.setTextColor(COLOR_WHITE);
        speedVal.setTextSize(12);
        root.addView(speedVal);

        final float[] currentSpeed = {savedSpeed};
        speedBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar s, int prog, boolean user) {
                currentSpeed[0] = prog;
                speedVal.setText("السرعة: " + prog + " م/ث");
            }
            @Override public void onStartTrackingTouch(SeekBar s) {}
            @Override public void onStopTrackingTouch(SeekBar s) {}
        });

        addSpacing(root, activity, 12);

        // ─ وضع التصحيح ─
        root.addView(buildLabel(activity, "وضع التصحيح"));
        Switch debugSwitch = new Switch(activity);
        debugSwitch.setText("تفعيل الـ Log");
        debugSwitch.setTextColor(COLOR_WHITE);
        debugSwitch.setChecked(true);
        debugSwitch.setOnCheckedChangeListener((v, checked) -> WFLog.setDebug(checked));
        root.addView(debugSwitch);

        addSpacing(root, activity, 12);

        // ─ معلومات الترخيص ─
        root.addView(buildLabel(activity, "الترخيص"));
        TextView licTxt = new TextView(activity);
        String status = store.getLicenseStatus();
        licTxt.setText("الحالة: " + (status.isEmpty() ? "غير مفعل" : status));
        licTxt.setTextColor("Active".equalsIgnoreCase(status) ? 0xFF4CAF50 : 0xFFFF5252);
        licTxt.setTextSize(13);
        licTxt.setBackgroundColor(COLOR_CARD);
        licTxt.setPadding(dp(activity,10), dp(activity,8), dp(activity,10), dp(activity,8));
        root.addView(licTxt);

        addSpacing(root, activity, 16);

        // ─ أزرار ─
        LinearLayout btnRow = new LinearLayout(activity);
        btnRow.setOrientation(LinearLayout.HORIZONTAL);

        Button saveBtn = new Button(activity);
        saveBtn.setText("حفظ");
        saveBtn.setTextColor(COLOR_BG);
        saveBtn.setBackgroundColor(COLOR_GOLD);
        LinearLayout.LayoutParams saveLp = new LinearLayout.LayoutParams(0, dp(activity,44), 1f);
        saveLp.setMargins(0, 0, dp(activity,8), 0);
        saveBtn.setLayoutParams(saveLp);
        saveBtn.setOnClickListener(v -> {
            // قراءة الارتفاع
            double alt = savedAltitude;
            try { alt = Double.parseDouble(altEt.getText().toString().trim()); }
            catch (Exception ignored) {}

            // FIX: حفظ دائم في WFStorage
            store.saveLocationSettings(currentAccuracy[0], alt, currentSpeed[0]);

            // تطبيق على الموقع الحالي في الذاكرة
            WFLocation loc = GPSMockManager.getInstance().getLocation();
            if (loc != null) {
                loc.setAccuracy(currentAccuracy[0]);
                loc.setAltitude(alt);
                loc.setSpeed(currentSpeed[0]);
            }

            Toast.makeText(activity, "✅ تم الحفظ", Toast.LENGTH_SHORT).show();
            dialog.dismiss();
        });
        btnRow.addView(saveBtn);

        Button closeBtn = new Button(activity);
        closeBtn.setText("إغلاق");
        closeBtn.setTextColor(COLOR_WHITE);
        closeBtn.setBackgroundColor(COLOR_CARD);
        closeBtn.setLayoutParams(new LinearLayout.LayoutParams(0, dp(activity,44), 1f));
        closeBtn.setOnClickListener(v -> dialog.dismiss());
        btnRow.addView(closeBtn);

        root.addView(btnRow);
        dialog.setContentView(root);
        dialog.show();
    }

    private static TextView buildLabel(Context ctx, String text) {
        TextView tv = new TextView(ctx);
        tv.setText(text);
        tv.setTextColor(COLOR_GOLD);
        tv.setTextSize(13);
        tv.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, 0, 0, dp(ctx, 4));
        tv.setLayoutParams(lp);
        return tv;
    }

    private static void addDivider(LinearLayout parent, Context ctx) {
        View d = new View(ctx);
        d.setBackgroundColor(COLOR_GOLD);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(ctx,1));
        lp.setMargins(0, dp(ctx,8), 0, dp(ctx,12));
        d.setLayoutParams(lp);
        parent.addView(d);
    }

    private static void addSpacing(LinearLayout parent, Context ctx, int dpVal) {
        View s = new View(ctx);
        s.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(ctx, dpVal)));
        parent.addView(s);
    }

    private static int dp(Context ctx, int dp) {
        return Math.round(dp * ctx.getResources().getDisplayMetrics().density);
    }
}
