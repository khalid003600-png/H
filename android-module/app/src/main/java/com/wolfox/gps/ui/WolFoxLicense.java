package com.wolfox.gps.ui;

import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.*;

import com.wolfox.gps.hook.LicenseHook;
import com.wolfox.gps.manager.FloatingManager;
import com.wolfox.gps.model.HistoryEntry;
import com.wolfox.gps.util.WFLog;
import com.wolfox.gps.util.WFStorage;

import org.json.JSONObject;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * WolFoxLicense — واجهة التفعيل
 *
 * FIX: إضافة حارس isShowing لمنع تكرار عرض الـ Dialog في كل onResume.
 * FIX: تنظيف المرجع عند الإغلاق لضمان إعادة الفتح إذا رفض المستخدم.
 */
public class WolFoxLicense {

    private static final String TAG = "WolFoxLicense";

    private static final int C_BG    = 0xFF070B18;
    private static final int C_GOLD  = 0xFFC9A227;
    private static final int C_WHITE = 0xFFFFFFFF;
    private static final int C_CARD  = 0xFF0E1428;
    private static final int C_GREEN = 0xFF388E3C;
    private static final int C_RED   = 0xFFD32F2F;

    private static final String ACTIVATE_URL = "https://p3nd.fun/api/activate.php";
    private static final ExecutorService executor = Executors.newSingleThreadExecutor();

    // FIX: حارس لمنع التكرار
    private static Dialog currentDialog = null;

    public static void show(Activity activity) {
        if (activity == null || activity.isFinishing()) return;
        if (WFStorage.getInstance(activity).isLicenseActive()) {
            FloatingManager.getInstance().show(activity);
            return;
        }
        activity.runOnUiThread(() -> buildAndShow(activity));
    }

    /**
     * FIX: checkAndShowIfNeeded — تتحقق من isShowing قبل الفتح
     */
    public static void checkAndShowIfNeeded(Activity activity) {
        if (activity == null || activity.isFinishing()) return;
        if (WFStorage.getInstance(activity).isLicenseActive()) {
            FloatingManager.getInstance().show(activity);
            return;
        }
        // FIX: لا تُعيد الفتح إذا الـ Dialog مُعروض بالفعل
        if (currentDialog != null && currentDialog.isShowing()) return;
        show(activity);
    }

    private static void buildAndShow(Activity activity) {
        // FIX: حارس ثانٍ على الـ UI thread
        if (currentDialog != null && currentDialog.isShowing()) return;

        Dialog dialog = new Dialog(activity, android.R.style.Theme_Material_Dialog);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        dialog.setCancelable(false);
        Window w = dialog.getWindow();
        if (w != null) {
            w.setBackgroundDrawableResource(android.R.color.transparent);
            w.setLayout(
                (int)(activity.getResources().getDisplayMetrics().widthPixels * 0.90),
                ViewGroup.LayoutParams.WRAP_CONTENT
            );
            w.setGravity(Gravity.CENTER);
        }

        LinearLayout root = new LinearLayout(activity);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(C_BG);
        root.setPadding(dp(activity,20), dp(activity,24), dp(activity,20), dp(activity,20));

        TextView logo = new TextView(activity);
        logo.setText("🦊");
        logo.setTextSize(48);
        logo.setGravity(Gravity.CENTER);
        root.addView(logo);

        TextView title = new TextView(activity);
        title.setText("WolFox GPS");
        title.setTextColor(C_GOLD);
        title.setTextSize(22);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        title.setGravity(Gravity.CENTER);
        root.addView(title);

        TextView sub = new TextView(activity);
        sub.setText("أدخل كود التفعيل للمتابعة");
        sub.setTextColor(0xFF888888);
        sub.setTextSize(13);
        sub.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        subLp.setMargins(0, dp(activity,4), 0, dp(activity,20));
        sub.setLayoutParams(subLp);
        root.addView(sub);

        EditText codeEt = new EditText(activity);
        codeEt.setHint("XXXX-XXXX-XXXX-XXXX");
        codeEt.setHintTextColor(0xFF444444);
        codeEt.setTextColor(C_WHITE);
        codeEt.setTextSize(16);
        codeEt.setGravity(Gravity.CENTER);
        codeEt.setBackgroundColor(C_CARD);
        codeEt.setPadding(dp(activity,14), dp(activity,12), dp(activity,14), dp(activity,12));
        codeEt.setInputType(android.text.InputType.TYPE_CLASS_TEXT
            | android.text.InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS);
        LinearLayout.LayoutParams etLp = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        etLp.setMargins(0, 0, 0, dp(activity,12));
        codeEt.setLayoutParams(etLp);
        root.addView(codeEt);

        TextView statusTxt = new TextView(activity);
        statusTxt.setTextSize(13);
        statusTxt.setGravity(Gravity.CENTER);
        statusTxt.setVisibility(View.GONE);
        LinearLayout.LayoutParams stLp = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        stLp.setMargins(0, 0, 0, dp(activity,10));
        statusTxt.setLayoutParams(stLp);
        root.addView(statusTxt);

        ProgressBar progress = new ProgressBar(activity);
        progress.setVisibility(View.GONE);
        LinearLayout.LayoutParams pbLp = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        pbLp.gravity = Gravity.CENTER_HORIZONTAL;
        pbLp.setMargins(0, 0, 0, dp(activity,10));
        progress.setLayoutParams(pbLp);
        root.addView(progress);

        Button activateBtn = new Button(activity);
        activateBtn.setText("تفعيل");
        activateBtn.setTextColor(C_BG);
        activateBtn.setBackgroundColor(C_GOLD);
        activateBtn.setTextSize(15);
        activateBtn.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        activateBtn.setLayoutParams(new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(activity,48)));
        root.addView(activateBtn);

        TextView buyTxt = new TextView(activity);
        buyTxt.setText("لا يوجد كود؟ احصل على ترخيص من p3nd.fun");
        buyTxt.setTextColor(0xFF666666);
        buyTxt.setTextSize(11);
        buyTxt.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams buyLp = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        buyLp.setMargins(0, dp(activity,12), 0, 0);
        buyTxt.setLayoutParams(buyLp);
        root.addView(buyTxt);

        dialog.setContentView(root);

        // FIX: تنظيف المرجع عند الإغلاق
        dialog.setOnDismissListener(d -> currentDialog = null);

        activateBtn.setOnClickListener(v -> {
            String code = codeEt.getText().toString().trim();
            if (code.length() < 8) {
                showStatus(statusTxt, "❌ كود غير صالح", C_RED);
                return;
            }
            activateBtn.setEnabled(false);
            progress.setVisibility(View.VISIBLE);
            statusTxt.setVisibility(View.GONE);
            executor.submit(() -> verifyCode(activity, code, dialog,
                activateBtn, progress, statusTxt));
        });

        currentDialog = dialog;
        dialog.show();
    }

    private static void verifyCode(Activity activity, String code, Dialog dialog,
                                    Button btn, ProgressBar progress, TextView statusTxt) {
        Handler ui = new Handler(Looper.getMainLooper());
        try {
            JSONObject body = new JSONObject();
            body.put("code",    code);
            body.put("package", activity.getPackageName());
            body.put("device",  android.os.Build.MODEL);

            URL url = new URL(ACTIVATE_URL);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setRequestProperty("Accept",       "application/json");
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            conn.setDoOutput(true);

            OutputStream os = conn.getOutputStream();
            os.write(body.toString().getBytes("UTF-8"));
            os.close();

            int httpCode = conn.getResponseCode();
            java.io.InputStream is = (httpCode >= 200 && httpCode < 300)
                ? conn.getInputStream() : conn.getErrorStream();

            java.io.BufferedReader br = new java.io.BufferedReader(
                new java.io.InputStreamReader(is, "UTF-8"));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) sb.append(line);
            br.close();
            conn.disconnect();

            String response = sb.toString();
            WFLog.i(TAG, "License response: " + response);

            JSONObject json = new JSONObject(response);
            String status = json.optString("status", "");

            if ("Active".equalsIgnoreCase(status)) {
                WFStorage.getInstance(activity).setLicenseStatus("Active");
                WFStorage.getInstance(activity).addHistory(
                    new HistoryEntry(HistoryEntry.Action.ACTIVATE,
                        "تفعيل ناجح: " + code));

                ui.post(() -> {
                    progress.setVisibility(View.GONE);
                    showStatus(statusTxt, "✅ تم التفعيل بنجاح!", C_GREEN);
                    btn.setEnabled(false);
                    btn.setText("✅ مفعّل");
                    btn.setBackgroundColor(C_GREEN);
                    new Handler(Looper.getMainLooper()).postDelayed(() -> {
                        dialog.dismiss();
                        LicenseHook.notifyActivated(activity, activity);
                    }, 1200);
                });
            } else {
                String msg = json.optString("message", "كود غير صحيح أو منتهي الصلاحية");
                ui.post(() -> {
                    progress.setVisibility(View.GONE);
                    btn.setEnabled(true);
                    showStatus(statusTxt, "❌ " + msg, C_RED);
                });
            }

        } catch (Exception e) {
            WFLog.e(TAG, "verifyCode: " + e.getMessage());
            ui.post(() -> {
                progress.setVisibility(View.GONE);
                btn.setEnabled(true);
                showStatus(statusTxt, "⚠️ تعذر الاتصال بالسيرفر", 0xFFFF9800);
            });
        }
    }

    private static void showStatus(TextView tv, String msg, int color) {
        tv.setText(msg);
        tv.setTextColor(color);
        tv.setVisibility(View.VISIBLE);
    }

    private static int dp(Context ctx, int dp) {
        return Math.round(dp * ctx.getResources().getDisplayMetrics().density);
    }
}
