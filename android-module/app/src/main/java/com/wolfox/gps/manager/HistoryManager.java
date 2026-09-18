package com.wolfox.gps.manager;

import android.content.Context;

import com.wolfox.gps.model.HistoryEntry;
import com.wolfox.gps.util.WFStorage;

import java.util.List;

/**
 * HistoryManager — إدارة سجل العمليات
 * Facade فوق WFStorage لعمليات السجل.
 */
public class HistoryManager {

    private static HistoryManager instance;
    private Context ctx;

    private HistoryManager() {}

    public static synchronized HistoryManager getInstance() {
        if (instance == null) instance = new HistoryManager();
        return instance;
    }

    public void init(Context ctx)           { this.ctx = ctx.getApplicationContext(); }
    public List<HistoryEntry> getAll()      { return store().getHistory(); }
    public void add(HistoryEntry entry)     { store().addHistory(entry); }
    public void clear()                     { store().clearHistory(); }

    public void log(HistoryEntry.Action action, String detail) {
        add(new HistoryEntry(action, detail));
    }

    public void log(HistoryEntry.Action action, double lat, double lng, String detail) {
        add(new HistoryEntry(action, lat, lng, detail));
    }

    private WFStorage store() { return WFStorage.getInstance(ctx); }
}
