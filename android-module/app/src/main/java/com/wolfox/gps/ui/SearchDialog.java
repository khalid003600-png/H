package com.wolfox.gps.ui;

import android.app.Activity;
import android.app.Dialog;
import android.location.Address;
import android.location.Geocoder;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.*;

import com.wolfox.gps.manager.GPSMockManager;
import com.wolfox.gps.model.HistoryEntry;
import com.wolfox.gps.model.WFLocation;
import com.wolfox.gps.util.WFLog;
import com.wolfox.gps.util.WFStorage;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * SearchDialog — بحث بالعنوان أو الإحداثيات
 *
 * FIX: إضافة Nominatim (OSM) كـ fallback تلقائي عند فشل Geocoder
 *      أو غياب Google Services.
 * FIX: فحص Geocoder.isPresent() قبل استدعائه.
 */
public class SearchDialog {

    private static final String TAG = "SearchDialog";
    private static final int COLOR_BG    = 0xFF070B18;
    private static final int COLOR_GOLD  = 0xFFC9A227;
    private static final int COLOR_WHITE = 0xFFFFFFFF;
    private static final int COLOR_CARD  = 0xFF0E1428;

    private static final Pattern COORD_PATTERN =
            Pattern.compile("(-?\\d+\\.\\d+)[,\\s]+(-?\\d+\\.\\d+)");

    private static final String NOMINATIM_URL =
            "https://nominatim.openstreetmap.org/search?format=json&limit=1&q=";

    private static final ExecutorService executor = Executors.newSingleThreadExecutor();

    public static void show(Activity activity) {
        if (activity == null || activity.isFinishing()) return;
        activity.runOnUiThread(() -> buildAndShow(activity));
    }

    private static void buildAndShow(Activity activity) {
        Dialog dialog = new Dialog(activity, android.R.style.Theme_Material_Dialog);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        dialog.setCancelable(true);
        Window window = dialog.getWindow();
        if (window != null) {
            window.setBackgroundDrawableResource(android.R.color.transparent);
            window.setLayout(
                    (int)(activity.getResources().getDisplayMetrics().widthPixels * 0.92),
                    ViewGroup.LayoutParams.WRAP_CONTENT);
            window.setGravity(Gravity.CENTER);
        }

        LinearLayout root = new LinearLayout(activity);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(COLOR_BG);
        root.setPadding(dp(activity,16), dp(activity,16), dp(activity,16), dp(activity,16));

        TextView title = new TextView(activity);
        title.setText("🔍 بحث عن موقع");
        title.setTextColor(COLOR_GOLD);
        title.setTextSize(16);
        title.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        root.addView(title);

        TextView hint = new TextView(activity);
        hint.setText("أدخل عنواناً أو إحداثيات (lat, lng)");
        hint.setTextColor(0xFFAAAAAA);
        hint.setTextSize(12);
        LinearLayout.LayoutParams hintLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        hintLp.setMargins(0, dp(activity,4), 0, dp(activity,8));
        hint.setLayoutParams(hintLp);
        root.addView(hint);

        EditText input = new EditText(activity);
        input.setHint("مثال: الرياض أو 24.7136, 46.6753");
        input.setHintTextColor(0xFF666666);
        input.setTextColor(COLOR_WHITE);
        input.setBackgroundColor(COLOR_CARD);
        input.setPadding(dp(activity,12), dp(activity,10), dp(activity,12), dp(activity,10));
        LinearLayout.LayoutParams inputLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        inputLp.setMargins(0, 0, 0, dp(activity,8));
        input.setLayoutParams(inputLp);
        root.addView(input);

        TextView resultTxt = new TextView(activity);
        resultTxt.setTextColor(COLOR_WHITE);
        resultTxt.setTextSize(13);
        resultTxt.setVisibility(View.GONE);
        root.addView(resultTxt);

        ProgressBar progress = new ProgressBar(activity);
        progress.setVisibility(View.GONE);
        LinearLayout.LayoutParams pbLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        pbLp.gravity = Gravity.CENTER_HORIZONTAL;
        progress.setLayoutParams(pbLp);
        root.addView(progress);

        LinearLayout btnRow = new LinearLayout(activity);
        btnRow.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams btnRowLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        btnRowLp.setMargins(0, dp(activity,8), 0, 0);
        btnRow.setLayoutParams(btnRowLp);

        Button searchBtn = new Button(activity);
        searchBtn.setText("بحث");
        searchBtn.setTextColor(COLOR_BG);
        searchBtn.setBackgroundColor(COLOR_GOLD);
        LinearLayout.LayoutParams sbLp = new LinearLayout.LayoutParams(0, dp(activity,44), 1f);
        sbLp.setMargins(0, 0, dp(activity,8), 0);
        searchBtn.setLayoutParams(sbLp);
        btnRow.addView(searchBtn);

        Button cancelBtn = new Button(activity);
        cancelBtn.setText("إلغاء");
        cancelBtn.setTextColor(COLOR_WHITE);
        cancelBtn.setBackgroundColor(COLOR_CARD);
        cancelBtn.setLayoutParams(new LinearLayout.LayoutParams(0, dp(activity,44), 1f));
        cancelBtn.setOnClickListener(v -> dialog.dismiss());
        btnRow.addView(cancelBtn);

        root.addView(btnRow);
        dialog.setContentView(root);

        searchBtn.setOnClickListener(v -> {
            String query = input.getText().toString().trim();
            if (query.isEmpty()) return;

            progress.setVisibility(View.VISIBLE);
            resultTxt.setVisibility(View.GONE);
            searchBtn.setEnabled(false);

            executor.submit(() -> {
                WFLocation loc = null;

                // 1) إحداثيات مباشرة
                Matcher m = COORD_PATTERN.matcher(query);
                if (m.find()) {
                    try {
                        double lat = Double.parseDouble(m.group(1));
                        double lng = Double.parseDouble(m.group(2));
                        loc = new WFLocation(lat, lng, query);
                    } catch (Exception ignored) {}
                }

                // 2) Geocoder (Google) — إذا كان متاحاً
                if (loc == null && Geocoder.isPresent()) {
                    try {
                        Geocoder geocoder = new Geocoder(activity, Locale.getDefault());
                        List<Address> addresses = geocoder.getFromLocationName(query, 1);
                        if (addresses != null && !addresses.isEmpty()) {
                            Address addr = addresses.get(0);
                            loc = new WFLocation(addr.getLatitude(), addr.getLongitude(),
                                    addr.getAddressLine(0));
                            WFLog.d(TAG, "Geocoder ✅: " + loc);
                        }
                    } catch (Exception e) {
                        WFLog.w(TAG, "Geocoder failed: " + e.getMessage());
                    }
                }

                // 3) FIX: Nominatim (OSM) fallback — لا يحتاج Google Services
                if (loc == null) {
                    loc = searchNominatim(query);
                }

                final WFLocation finalLoc = loc;
                new Handler(Looper.getMainLooper()).post(() -> {
                    progress.setVisibility(View.GONE);
                    searchBtn.setEnabled(true);

                    if (finalLoc != null) {
                        String label = finalLoc.getLabel() != null
                                ? finalLoc.getLabel()
                                : String.format("%.6f, %.6f",
                                    finalLoc.getLatitude(), finalLoc.getLongitude());
                        resultTxt.setText("✅ " + label);
                        resultTxt.setTextColor(COLOR_WHITE);
                        resultTxt.setVisibility(View.VISIBLE);

                        GPSMockManager.getInstance().setLocation(finalLoc);
                        WFStorage.getInstance(activity).addHistory(
                                new HistoryEntry(HistoryEntry.Action.SEARCH,
                                        finalLoc.getLatitude(), finalLoc.getLongitude(), query));
                        dialog.dismiss();
                        Toast.makeText(activity, "📍 " + label, Toast.LENGTH_SHORT).show();
                    } else {
                        resultTxt.setText("❌ لم يتم العثور على نتائج");
                        resultTxt.setTextColor(0xFFFF5252);
                        resultTxt.setVisibility(View.VISIBLE);
                    }
                });
            });
        });

        dialog.show();
    }

    /**
     * FIX: Nominatim OpenStreetMap — مجاني بلا API Key
     * User-Agent مطلوب وإلا يرفض الطلب
     */
    private static WFLocation searchNominatim(String query) {
        try {
            String encoded = URLEncoder.encode(query, "UTF-8");
            URL url = new URL(NOMINATIM_URL + encoded);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("User-Agent", "WolFoxGPS/2.0 (wolfox@p3nd.fun)");
            conn.setRequestProperty("Accept-Language", "ar,en");
            conn.setConnectTimeout(8000);
            conn.setReadTimeout(8000);

            int code = conn.getResponseCode();
            if (code != 200) {
                WFLog.w(TAG, "Nominatim HTTP " + code);
                return null;
            }

            BufferedReader br = new BufferedReader(
                    new InputStreamReader(conn.getInputStream(), "UTF-8"));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) sb.append(line);
            br.close();
            conn.disconnect();

            JSONArray arr = new JSONArray(sb.toString());
            if (arr.length() == 0) return null;

            JSONObject first = arr.getJSONObject(0);
            double lat = Double.parseDouble(first.getString("lat"));
            double lng = Double.parseDouble(first.getString("lon"));
            String displayName = first.optString("display_name", query);

            // اختصار الاسم الطويل
            if (displayName.length() > 60) displayName = displayName.substring(0, 57) + "...";

            WFLog.i(TAG, "Nominatim ✅: " + displayName);
            return new WFLocation(lat, lng, displayName);

        } catch (Exception e) {
            WFLog.e(TAG, "Nominatim error: " + e.getMessage());
            return null;
        }
    }

    private static int dp(android.content.Context ctx, int dp) {
        return Math.round(dp * ctx.getResources().getDisplayMetrics().density);
    }
}
