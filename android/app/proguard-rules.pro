# Flutter wrapper — handled by the Flutter Gradle plugin, but keep the embedding.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_local_notifications (uses Gson reflection for scheduled-notification payloads).
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.TypeAdapter
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Google Play Services — Wearable data sync (MainActivity).
-keep class com.google.android.gms.wearable.** { *; }
-dontwarn com.google.android.gms.**

# mobile_scanner / ML Kit barcode.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep annotated native methods (sqlite3 / drift JNI bindings are native, not reflective,
# but this is cheap insurance against stripping JNI entry points).
-keepclasseswithmembernames class * {
    native <methods>;
}
