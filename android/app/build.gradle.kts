plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // `namespace` stays at the original Kotlin source-tree package so we don't
    // have to move MainActivity.kt on disk. The user-visible `applicationId`
    // is what Play Store + the launcher use.
    namespace = "app.mood8.mood8"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.mood8.app"
        // 24 = Android 7.0. Required by url_launcher_android 6.3.29 which
        // raised its plugin minSdk to 24 — without this override the
        // manifest merger refuses the build with "uses-sdk:minSdkVersion
        // X cannot be smaller than version 24 declared in library
        // [:url_launcher_android]". 24 still covers ~98% of active
        // Android devices and is a sensible floor for modern crypto +
        // runtime permissions.
        minSdk = 24
        targetSdk = 34
        // Version is sourced from pubspec.yaml (`version: x.y.z+code`).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now so `flutter run --release`
            // and CI APK uploads work. Replace with a real keystore when
            // we're ready to ship to Play.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
