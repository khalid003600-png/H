package com.wolfox.gps.manager;

import android.content.Context;

import com.wolfox.gps.model.FavoriteLocation;
import com.wolfox.gps.util.WFStorage;

import java.util.List;

/**
 * FavoritesManager — إدارة المفضلة
 * Facade فوق WFStorage لعمليات المفضلة.
 */
public class FavoritesManager {

    private static FavoritesManager instance;
    private Context ctx;

    private FavoritesManager() {}

    public static synchronized FavoritesManager getInstance() {
        if (instance == null) instance = new FavoritesManager();
        return instance;
    }

    public void init(Context ctx)                           { this.ctx = ctx.getApplicationContext(); }
    public List<FavoriteLocation> getAll()                  { return store().getFavorites(); }
    public void add(FavoriteLocation fav)                   { store().addFavorite(fav); }
    public void update(FavoriteLocation fav)                { store().updateFavorite(fav); }
    public void delete(long id)                             { store().deleteFavorite(id); }
    public String exportJson()                              { return store().exportFavoritesJson(); }
    public boolean importJson(String json)                  { return store().importFavoritesJson(json); }

    public void add(String name, double lat, double lng) {
        add(new FavoriteLocation(name, lat, lng));
    }

    public FavoriteLocation getById(long id) {
        for (FavoriteLocation f : getAll()) {
            if (f.getId() == id) return f;
        }
        return null;
    }

    private WFStorage store() { return WFStorage.getInstance(ctx); }
}
