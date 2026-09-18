package com.wolfox.gps.service;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.os.Build;
import android.os.IBinder;

import com.wolfox.gps.util.WFLog;

/**
 * AzanService — خدمة الأذان في الخلفية
 * آمنة 100%: Foreground Service عادية، لا تحتاج روت.
 */
public class AzanService extends Service {

    private static final String TAG       = "AzanService";
    private static final String CH_ID     = "wolfox_azan_ch";
    private static final int    NOTIF_ID  = 1001;

    public static boolean isRunning = false;

    private MediaPlayer player;

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && "STOP".equals(intent.getAction())) {
            stopSelf();
            return START_NOT_STICKY;
        }

        createNotificationChannel();
        startForeground(NOTIF_ID, buildNotification());
        isRunning = true;

        playAzan();
        WFLog.i(TAG, "▶ أذان بدأ");
        return START_STICKY;
    }

    private void playAzan() {
        try {
            if (player != null) { player.release(); player = null; }

            // الأذان من رابط مفتوح — بدون DRM
            player = new MediaPlayer();
            player.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build());

            // رابط أذان مكة من الإذاعة العامة (مفتوح)
            player.setDataSource("https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3");
            player.setLooping(false);
            player.prepareAsync();
            player.setOnPreparedListener(MediaPlayer::start);
            player.setOnCompletionListener(mp -> {
                isRunning = false;
                stopSelf();
            });
            player.setOnErrorListener((mp, what, extra) -> {
                WFLog.e(TAG, "Error: " + what + "/" + extra);
                stopSelf();
                return true;
            });
        } catch (Exception e) {
            WFLog.e(TAG, "playAzan: " + e.getMessage());
            stopSelf();
        }
    }

    @Override
    public void onDestroy() {
        isRunning = false;
        if (player != null) {
            try { if (player.isPlaying()) player.stop(); } catch (Exception ignored) {}
            player.release();
            player = null;
        }
        WFLog.i(TAG, "⏹ أذان توقف");
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent) { return null; }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(
                    CH_ID, "WolFox أذان", NotificationManager.IMPORTANCE_LOW);
            ch.setDescription("تشغيل الأذان في الخلفية");
            getSystemService(NotificationManager.class).createNotificationChannel(ch);
        }
    }

    private Notification buildNotification() {
        Intent stopIntent = new Intent(this, AzanService.class);
        stopIntent.setAction("STOP");
        PendingIntent stopPi = PendingIntent.getService(this, 0, stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Notification.Builder builder = new Notification.Builder(this);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder = new Notification.Builder(this, CH_ID);
        }
        return builder
                .setContentTitle("🕌 WolFox — الأذان")
                .setContentText("يُشغَّل الأذان الآن")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .addAction(android.R.drawable.ic_media_pause, "إيقاف", stopPi)
                .build();
    }
}
