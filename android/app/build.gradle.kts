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
        // 23 = Android 6.0. Required by flutter_secure_storage and a sensible
        // floor for modern crypto / runtime permissions.
        minSdk = 23
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
