package com.wolfox.gps.receiver;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import com.wolfox.gps.util.WFStorage;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            // استعادة حالة التزييف بعد إعادة التشغيل تلقائياً
            WFStorage.getInstance(context).isMocking(); // يُهيّئ الـ store
        }
    }
}
