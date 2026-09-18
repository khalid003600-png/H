# =====================================================
#  WolFox GPS Module — ProGuard Rules
# =====================================================

# الموديول لا يُصغَّر (minify=false) لأن LSPatch يحتاج الأسماء الأصلية
# هذا الملف احتياطي فقط

# الحفاظ على كلاسات Xposed
-keep class de.robv.android.xposed.** { *; }
-keep interface de.robv.android.xposed.** { *; }
-keepclassmembers class * implements de.robv.android.xposed.IXposedHookLoadPackage {
    public void handleLoadPackage(de.robv.android.xposed.callbacks.XC_LoadPackage$LoadPackageParam);
}

# الحفاظ على كلاسات WolFox بالكامل
-keep class com.wolfox.gps.** { *; }
-keepclassmembers class com.wolfox.gps.** { *; }

# الحفاظ على النماذج (models)
-keepclassmembers class com.wolfox.gps.model.** {
    public *;
    private *;
}

# منع تشويش أسماء الهوكات
-keepnames class com.wolfox.gps.hook.** { *; }

# Android
-keep class android.location.** { *; }
-keep class android.webkit.** { *; }

# Google Play Services Location
-keep class com.google.android.gms.location.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# JSON
-keep class org.json.** { *; }

# لا تزيل استثناءات مفيدة
-keepattributes Exceptions, Signature, *Annotation*
