package com.wolfox.gps.ui;

import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.*;

import com.wolfox.gps.manager.FloatingManager;
import com.wolfox.gps.manager.GPSMockManager;
import com.wolfox.gps.model.HistoryEntry;
import com.wolfox.gps.model.WFLocation;
import com.wolfox.gps.service.AzanService;
import com.wolfox.gps.util.WFStorage;

public class WolFoxPanel {

    private static final int C_BG    = 0xFF070B18;
    private static final int C_GOLD  = 0xFFC9A227;
    private static final int C_WHITE = 0xFFFFFFFF;
    private static final int C_CARD  = 0xFF0E1428;
    private static final int C_GREEN = 0xFF22C55E;
    private static final int C_RED   = 0xFFEF4444;
    private static final int C_NAVY3 = 0xFF1A2040;

    private static Dialog currentDialog;

    public static void show(Activity act) {
        if (act == null || act.isFinishing()) return;
        act.runOnUiThread(() -> {
            if (currentDialog != null && currentDialog.isShowing()) currentDialog.dismiss();
            currentDialog = build(act);
            currentDialog.show();
        });
    }

    private static Dialog build(Activity act) {
        Dialog d = new Dialog(act, android.R.style.Theme_Material_Dialog);
        d.requestWindowFeature(Window.FEATURE_NO_TITLE);
        d.setCancelable(true);
        Window w = d.getWindow();
        if (w != null) {
            w.setBackgroundDrawableResource(android.R.color.transparent);
            w.setLayout(
                (int)(act.getResources().getDisplayMetrics().widthPixels * 0.92),
                ViewGroup.LayoutParams.WRAP_CONTENT);
            w.setGravity(Gravity.CENTER);
        }
        ScrollView sv = new ScrollView(act);
        sv.addView(content(act, d));
        d.setContentView(sv);
        d.setOnDismissListener(x -> currentDialog = null);
        return d;
    }

    private static LinearLayout content(Activity act, Dialog d) {
        LinearLayout root = new LinearLayout(act);
        root.setOrientation(LinearLayout.VERTICAL);
        roundBg(root, C_BG, 20);
        root.setPadding(dp(act,14), dp(act,14), dp(act,14), dp(act,14));

        // ── رأس ──
        root.addView(header(act, d));

        // ── مؤشر الحالة ──
        root.addView(statusBanner(act));
        space(root, act, 8);

        // ── التزييف ──
        root.addView(label(act, "\uD83D\uDCCD التزييف"));
        root.addView(row(act,
            btn(act, "▶ ابدأ", C_GREEN, v -> {
                if (!GPSMockManager.getInstance().hasMockLocation()) {
                    toast(act, "❗ حدد موقعاً أولاً من الخريطة");
                    return;
                }
                GPSMockManager.getInstance().startMocking();
                WFStorage.getInstance(act).addHistory(
                    new HistoryEntry(HistoryEntry.Action.START_MOCK, "بدء التزييف"));
                MapDialog.refreshStatus();
                d.dismiss();
                toast(act, "✅ التزييف نشط الآن");
            }),
            btn(act, "⏹ إيقاف", C_RED, v -> {
                GPSMockManager.getInstance().stopMocking();
                WFStorage.getInstance(act).addHistory(
                    new HistoryEntry(HistoryEntry.Action.STOP_MOCK, "إيقاف التزييف"));
                MapDialog.refreshStatus();
                d.dismiss();
                toast(act, "⏹ تم إيقاف التزييف");
            })
        ));
        root.addView(row(act,
            btn(act, "🗺 الخريطة", C_CARD, v -> { d.dismiss(); MapDialog.show(act); }),
            btn(act, "🔍 بحث",     C_CARD, v -> { d.dismiss(); SearchDialog.show(act); })
        ));
        space(root, act, 6);

        // ── المواقع ──
        root.addView(label(act, "🗂 المواقع"));
        root.addView(row(act,
            btn(act, "⭐ المفضلة", C_CARD, v -> { d.dismiss(); FavoritesDialog.show(act); }),
            btn(act, "🕐 السجل",   C_CARD, v -> { d.dismiss(); HistoryDialog.show(act); })
        ));
        space(root, act, 6);

        // ── الأذان ──
        root.addView(label(act, "🕌 الأذان"));
        root.addView(row(act,
            btn(act, "▶ تشغيل الأذان", 0xFF14532D, v -> {
                act.startService(new Intent(act, AzanService.class));
                d.dismiss();
                toast(act, "🕌 الأذان يُشغَّل الآن");
            }),
            btn(act, "⏹ إيقاف الأذان", 0xFF4A0000, v -> {
                Intent i = new Intent(act, AzanService.class);
                i.setAction("STOP");
                act.startService(i);
                toast(act, "⏹ تم إيقاف الأذان");
            })
        ));
        space(root, act, 6);

        // ── الأيقونة ──
        root.addView(label(act, "👁 الأيقونة العائمة"));
        root.addView(row(act,
            btn(act, "إخفاء الأيقونة", C_NAVY3, v -> {
                d.dismiss();
                FloatingManager.getInstance().hide();
                showHideGuide(act);
            }),
            btn(act, "⚙ إعدادات", C_CARD, v -> { d.dismiss(); SettingsDialog.show(act); })
        ));

        return root;
    }

    // ── بانر الحالة ──────────────────────────────────────────────────────────

    private static View statusBanner(Activity act) {
        boolean mock = GPSMockManager.getInstance().isMocking();
        WFLocation loc = GPSMockManager.getInstance().getLocation();

        LinearLayout card = new LinearLayout(act);
        card.setOrientation(LinearLayout.HORIZONTAL);
        card.setGravity(Gravity.CENTER_VERTICAL);
        roundBg(card, C_CARD, 12);
        card.setPadding(dp(act,12), dp(act,10), dp(act,12), dp(act,10));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0,0,0,dp(act,2));
        card.setLayoutParams(lp);

        // أيقونة GPS
        TextView ico = new TextView(act);
        ico.setText(mock ? "●" : "●");
        ico.setTextColor(mock ? C_GREEN : C_RED);
        ico.setTextSize(22);
        LinearLayout.LayoutParams icoLp = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        icoLp.setMargins(0,0,dp(act,10),0);
        ico.setLayoutParams(icoLp);
        card.addView(ico);

        // نصوص
        LinearLayout col = new LinearLayout(act);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setLayoutParams(new LinearLayout.LayoutParams(0,
            LinearLayout.LayoutParams.WRAP_CONTENT,1f));

        TextView statusTxt = new TextView(act);
        statusTxt.setText(mock ? "التزييف نشط ✅" : "التزييف متوقف ❌");
        statusTxt.setTextColor(mock ? C_GREEN : C_RED);
        statusTxt.setTextSize(14);
        statusTxt.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        col.addView(statusTxt);

        if (loc != null) {
            TextView coordTxt = new TextView(act);
            coordTxt.setText(String.format("📍 %.6f ، %.6f",
                loc.getLatitude(), loc.getLongitude()));
            coordTxt.setTextColor(0xFFAAAAAA);
            coordTxt.setTextSize(11);
            col.addView(coordTxt);
        } else if (!mock) {
            TextView hint = new TextView(act);
            hint.setText("افتح الخريطة لتحديد موقع");
            hint.setTextColor(0xFF666666);
            hint.setTextSize(11);
            col.addView(hint);
        }
        card.addView(col);
        return card;
    }

    // ── تعليمات الإخفاء ──────────────────────────────────────────────────────

    private static void showHideGuide(Activity act) {
        new android.app.AlertDialog.Builder(act)
            .setTitle("كيف تُعيد إظهار الأيقونة؟")
            .setMessage(
                "① أغلق التطبيق وافتحه من جديد — تظهر تلقائياً\n\n" +
                "② هُز الجهاز 3 مرات متتالية (Shake to Show)\n\n" +
                "③ من مدير المهام — اضغط مطولاً على التطبيق\n\n" +
                "④ الإعدادات ← WolFox GPS ← إعادة إظهار الأيقونة"
            )
            .setPositiveButton("فهمت", null)
            .show();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static View header(Context ctx, Dialog d) {
        LinearLayout r = new LinearLayout(ctx);
        r.setOrientation(LinearLayout.HORIZONTAL);
        r.setGravity(Gravity.CENTER_VERTICAL);

        TextView t = new TextView(ctx);
        t.setText("🦊 WolFox GPS");
        t.setTextColor(C_GOLD);
        t.setTextSize(18);
        t.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        t.setLayoutParams(new LinearLayout.LayoutParams(
            0, LinearLayout.LayoutParams.WRAP_CONTENT,1f));
        r.addView(t);

        Button x = new Button(ctx);
        x.setText("✕");
        x.setTextColor(C_WHITE);
        x.setBackgroundColor(android.graphics.Color.TRANSPARENT);
        x.setTextSize(18);
        x.setOnClickListener(v -> d.dismiss());
        r.addView(x);

        LinearLayout wrap = new LinearLayout(ctx);
        wrap.setOrientation(LinearLayout.VERTICAL);
        wrap.addView(r);
        View div = new View(ctx);
        div.setBackgroundColor(C_GOLD);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(ctx,1));
        lp.setMargins(0,dp(ctx,8),0,dp(ctx,10));
        div.setLayoutParams(lp);
        wrap.addView(div);
        return wrap;
    }

    private static TextView label(Context ctx, String txt) {
        TextView tv = new TextView(ctx);
        tv.setText(txt);
        tv.setTextColor(C_GOLD);
        tv.setTextSize(12);
        tv.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0,0,0,dp(ctx,4));
        tv.setLayoutParams(lp);
        return tv;
    }

    private static LinearLayout row(Context ctx, View... views) {
        LinearLayout r = new LinearLayout(ctx);
        r.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0,0,0,dp(ctx,6));
        r.setLayoutParams(lp);
        for (View v : views) r.addView(v);
        return r;
    }

    private static Button btn(Context ctx, String lbl, int bg,
                               View.OnClickListener l) {
        Button b = new Button(ctx);
        b.setText(lbl);
        b.setTextColor(bg == C_GOLD ? C_BG : C_WHITE);
        b.setBackgroundColor(bg);
        b.setTextSize(12);
        LinearLayout.LayoutParams lp =
            new LinearLayout.LayoutParams(0, dp(ctx,44), 1f);
        lp.setMargins(dp(ctx,3),0,dp(ctx,3),0);
        b.setLayoutParams(lp);
        b.setOnClickListener(l);
        return b;
    }

    private static void roundBg(View v, int color, int r) {
        android.graphics.drawable.GradientDrawable d =
            new android.graphics.drawable.GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(dp(v.getContext(), r));
        v.setBackground(d);
    }

    private static void space(LinearLayout p, Context ctx, int dpVal) {
        View s = new View(ctx);
        s.setLayoutParams(new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(ctx,dpVal)));
        p.addView(s);
    }

    private static void toast(Context ctx, String msg) {
        new Handler(Looper.getMainLooper()).post(() ->
            Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show());
    }

    private static int dp(Context ctx, int v) {
        return Math.round(v * ctx.getResources().getDisplayMetrics().density);
    }
}
