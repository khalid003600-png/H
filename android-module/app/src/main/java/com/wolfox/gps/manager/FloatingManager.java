package com.wolfox.gps.manager;

import android.animation.ObjectAnimator;
import android.app.Activity;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.drawable.GradientDrawable;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import com.wolfox.gps.ui.WolFoxPanel;
import com.wolfox.gps.util.WFLog;

public class FloatingManager {

    private static final String TAG              = "FloatingManager";
    private static final int    SIZE_DP          = 58;
    private static final float  SHAKE_THRESHOLD  = 13f;
    private static final int    SHAKE_COUNT_NEED = 3;
    private static final long   SHAKE_WINDOW_MS  = 1400;
    private static final long   CLICK_MS         = 200;

    private static FloatingManager instance;

    private Activity currentActivity;
    private View     floatingBtn;
    private boolean  visible  = false;
    private boolean  attached = false;

    private SensorManager       sensorMgr;
    private SensorEventListener shakeListener;
    private int  shakeCnt   = 0;
    private long firstShake = 0;

    private float ix, iy, itx, ity;
    private long  downMs;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private FloatingManager() {}

    public static synchronized FloatingManager getInstance() {
        if (instance == null) instance = new FloatingManager();
        return instance;
    }

    // ─── Activity lifecycle ───────────────────────────────────────────────────

    public void onActivityResumed(Activity act) {
        currentActivity = act;
        registerShake(act);
        if (visible && !attached) { attachTo(act); }
        else if (visible)         { detach(); attachTo(act); }
    }

    public void onActivityPaused()   { unregisterShake(); }
    public void onActivityDestroyed(){ detach(); unregisterShake(); currentActivity = null; }

    // ─── Show / Hide ──────────────────────────────────────────────────────────

    public void show(Activity act) {
        currentActivity = act;
        visible = true;
        mainHandler.post(() -> {
            if (currentActivity != null && !currentActivity.isFinishing()) attachTo(currentActivity);
        });
    }

    public void hide() {
        visible = false;
        mainHandler.post(this::detach);
    }

    public Activity getCurrentActivity() { return currentActivity; }
    public boolean  isVisible()          { return visible; }

    // ─── Shake ───────────────────────────────────────────────────────────────

    private void registerShake(Activity act) {
        if (sensorMgr != null) return;
        sensorMgr = (SensorManager) act.getSystemService(Context.SENSOR_SERVICE);
        if (sensorMgr == null) return;
        Sensor accel = sensorMgr.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        if (accel == null) return;
        shakeListener = new SensorEventListener() {
            @Override public void onSensorChanged(SensorEvent e) {
                double mag = Math.sqrt(e.values[0]*e.values[0]
                           + e.values[1]*e.values[1]
                           + e.values[2]*e.values[2]) - SensorManager.GRAVITY_EARTH;
                if (mag > SHAKE_THRESHOLD) {
                    long now = System.currentTimeMillis();
                    if (shakeCnt == 0) firstShake = now;
                    if (now - firstShake < SHAKE_WINDOW_MS) {
                        if (++shakeCnt >= SHAKE_COUNT_NEED) {
                            shakeCnt = 0;
                            mainHandler.post(() -> {
                                if (!visible && currentActivity != null)
                                    show(currentActivity);
                                else if (currentActivity != null && !currentActivity.isFinishing())
                                    WolFoxPanel.show(currentActivity);
                            });
                        }
                    } else { shakeCnt = 1; firstShake = now; }
                }
            }
            @Override public void onAccuracyChanged(Sensor s, int a) {}
        };
        sensorMgr.registerListener(shakeListener, accel, SensorManager.SENSOR_DELAY_UI);
    }

    private void unregisterShake() {
        if (sensorMgr != null && shakeListener != null)
            sensorMgr.unregisterListener(shakeListener);
        sensorMgr = null; shakeListener = null;
    }

    // ─── Floating Button ─────────────────────────────────────────────────────

    private View buildBtn(Context ctx) {
        int size = dpToPx(ctx, SIZE_DP);
        FrameLayout container = new FrameLayout(ctx);

        // خلفية دائرية ذهبية
        GradientDrawable bg = new GradientDrawable();
        bg.setShape(GradientDrawable.OVAL);
        bg.setColor(0xFFC9A227);
        bg.setStroke(dpToPx(ctx,2), 0xFF070B18);
        container.setBackground(bg);
        container.setLayoutParams(new FrameLayout.LayoutParams(size, size));

        // نص أيقونة GPS
        android.widget.TextView ico = new android.widget.TextView(ctx);
        ico.setText("⊕");
        ico.setTextColor(0xFF070B18);
        ico.setTextSize(24);
        ico.setGravity(Gravity.CENTER);
        container.addView(ico, new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT));

        // نقطة الحالة (🟢/🔴)
        boolean mock = GPSMockManager.getInstance().isMocking();
        View dot = new View(ctx) {
            @Override protected void onDraw(Canvas canvas) {
                Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
                boolean m = GPSMockManager.getInstance().isMocking();
                p.setColor(m ? 0xFF22C55E : 0xFFEF4444);
                canvas.drawCircle(getWidth()/2f, getHeight()/2f, getWidth()/2f, p);
                p.setColor(Color.WHITE);
                p.setStyle(Paint.Style.STROKE);
                p.setStrokeWidth(2);
                canvas.drawCircle(getWidth()/2f, getHeight()/2f, getWidth()/2f - 1, p);
            }
        };
        int dotSize = dpToPx(ctx, 12);
        FrameLayout.LayoutParams dotLp = new FrameLayout.LayoutParams(dotSize, dotSize);
        dotLp.gravity = Gravity.TOP | Gravity.END;
        dotLp.setMargins(0, dpToPx(ctx,4), dpToPx(ctx,4), 0);
        dot.setLayoutParams(dotLp);
        container.addView(dot);

        // تحديث النقطة كل ثانية
        mainHandler.postDelayed(new Runnable() {
            @Override public void run() {
                if (attached && floatingBtn != null) {
                    dot.invalidate();
                    mainHandler.postDelayed(this, 1000);
                }
            }
        }, 1000);

        container.setOnTouchListener((v, ev) -> {
            switch (ev.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    ix=v.getX(); iy=v.getY();
                    itx=ev.getRawX(); ity=ev.getRawY();
                    downMs=System.currentTimeMillis();
                    return true;
                case MotionEvent.ACTION_MOVE:
                    v.setX(ix+(ev.getRawX()-itx));
                    v.setY(iy+(ev.getRawY()-ity));
                    return true;
                case MotionEvent.ACTION_UP:
                    boolean click = (System.currentTimeMillis()-downMs)<CLICK_MS
                        && Math.abs(ev.getRawX()-itx)<10
                        && Math.abs(ev.getRawY()-ity)<10;
                    if (click) onClick();
                    else snapEdge(v);
                    return true;
            }
            return false;
        });

        return container;
    }

    private void onClick() {
        if (currentActivity == null || currentActivity.isFinishing()) return;
        WolFoxPanel.show(currentActivity);
    }

    // ─── Attach / Detach ─────────────────────────────────────────────────────

    private void attachTo(Activity act) {
        if (act == null || act.isFinishing()) return;
        ViewGroup dec = (ViewGroup) act.getWindow().getDecorView();
        if (dec == null) return;
        safeRemove(floatingBtn);
        floatingBtn = buildBtn(act);
        int size = dpToPx(act, SIZE_DP);
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(size, size);
        lp.gravity = Gravity.END | Gravity.CENTER_VERTICAL;
        lp.rightMargin = dpToPx(act, 14);
        dec.addView(floatingBtn, lp);
        attached = true;
        floatingBtn.setAlpha(0f);
        floatingBtn.animate().alpha(1f).setDuration(300).start();
    }

    private void detach() {
        safeRemove(floatingBtn);
        floatingBtn = null;
        attached = false;
    }

    private void safeRemove(View v) {
        if (v != null && v.getParent() instanceof ViewGroup) {
            try { ((ViewGroup)v.getParent()).removeView(v); } catch (Exception ignored) {}
        }
    }

    private void snapEdge(View v) {
        if (!(v.getParent() instanceof ViewGroup)) return;
        ViewGroup p = (ViewGroup) v.getParent();
        float cx = v.getX() + v.getWidth() / 2f;
        float tx = cx < p.getWidth()/2f
            ? dpToPx(v.getContext(), 8)
            : p.getWidth() - v.getWidth() - dpToPx(v.getContext(), 8);
        ObjectAnimator.ofFloat(v, "x", tx).setDuration(200).start();
    }

    private int dpToPx(Context ctx, int dp) {
        return Math.round(dp * ctx.getResources().getDisplayMetrics().density);
    }
}
