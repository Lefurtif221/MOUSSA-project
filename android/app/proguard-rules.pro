# Ndoket — Règles ProGuard/R8 pour Capacitor + plugins

# Capacitor
-keep class com.getcapacitor.** { *; }
-keep class com.capacitorjs.** { *; }
-keep class capacitor.** { *; }

# WebView JS bridge
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.codetrixstudio.capacitor.GoogleAuth.** { *; }
-keep class com.codetrixstudio.capacitor.googleauth.** { *; }
-keep class * extends com.google.android.gms.common.api.GoogleApiClient { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.libraries.identity.googleid.** { *; }

# Push Notifications
-keep class com.capacitorjs.plugins.pushnotifications.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.ktx.** { *; }
-keep class com.google.firebase.installations.** { *; }

# Share plugin
-keep class com.capacitorjs.plugins.share.** { *; }

# App plugin (back button, deep links)
-keep class com.capacitorjs.plugins.app.** { *; }

# Keep line numbers for crash reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Suppress warnings for optional Firebase dependencies
-dontwarn com.google.firebase.ktx.**
-dontwarn com.google.firebase.installations.ktx.**
