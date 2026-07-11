# R8/ProGuard keep rules for Mood8.
#
# Why this file exists: Flutter's gradle plugin enables R8 minification
# on release builds by default. Without the rules below, R8 strips the
# generic type signatures that flutter_local_notifications' Gson
# TypeToken cache deserialization relies on, and every plugin call in
# the release build throws:
#
#   PlatformException(error, Missing type parameter., null,
#     java.lang.RuntimeException: Missing type parameter.
#       at com.dexterous.flutterlocalnotifications.FlutterLocalNotifications
#         Plugin.loadScheduledNotifications)
#
# Debug builds work because R8 doesn't run; release builds break with
# this exact stack. The rules below are the ones the plugin's README
# documents.

# Preserve generic type info (Gson TypeToken needs `Signature`).
-keepattributes Signature

# Preserve annotations used by Gson + Flutter codegen.
-keepattributes *Annotation*

# Keep the plugin's classes — its scheduled-notification deserializer
# reflects across com.dexterous.flutterlocalnotifications.*.
-keep class com.dexterous.** { *; }

# Gson core + its reflection-based TypeToken plumbing.
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

# ─── Firebase Crashlytics ────────────────────────────────────────────
# Keep line numbers so uploaded symbols map back to readable stacks in
# the Firebase console instead of "<obfuscated>:12". The plugin also
# uploads a mapping file so R8 obfuscation itself is fine — but the
# source-file + line-number attributes must survive shrinking.
-keepattributes SourceFile,LineNumberTable

# Preserve Crashlytics + the Google Play Services runtime it plugs
# into. These paths are reflected against by the plugin at runtime.
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
