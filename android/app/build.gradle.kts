import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing config sources:
//
//   1. Local builds — `android/key.properties` (gitignored). Copy
//      `android/key.properties.example`, fill in the passwords, and
//      `flutter build appbundle --release` signs locally.
//   2. CI builds   — environment variables decoded from GitHub
//      secrets in `.github/workflows/android-build.yml`:
//        MOOD8_KEYSTORE_PATH    (path the workflow wrote the keystore to)
//        MOOD8_KEYSTORE_PASSWORD
//        MOOD8_KEY_ALIAS
//        MOOD8_KEY_PASSWORD
//
// If NEITHER source is present (e.g. someone on a fresh checkout
// runs `flutter build apk --release` without keys) we fall through
// to the debug-signed config so the build still succeeds — the
// resulting artifact just can't be uploaded to Play.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun signingValue(propKey: String, envKey: String): String? {
    val fromProps = keystoreProperties.getProperty(propKey)
    if (!fromProps.isNullOrBlank()) return fromProps
    val fromEnv = System.getenv(envKey)
    if (!fromEnv.isNullOrBlank()) return fromEnv
    return null
}

val signingStorePath = signingValue("storeFile", "MOOD8_KEYSTORE_PATH")
val signingStorePass = signingValue("storePassword", "MOOD8_KEYSTORE_PASSWORD")
val signingAlias     = signingValue("keyAlias", "MOOD8_KEY_ALIAS")
val signingKeyPass   = signingValue("keyPassword", "MOOD8_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    signingStorePath, signingStorePass, signingAlias, signingKeyPass,
).all { !it.isNullOrBlank() } && file(signingStorePath!!).let {
    // Resolve relative paths against the android/ project dir.
    val resolved = if (it.isAbsolute) it else rootProject.file(signingStorePath!!)
    resolved.exists()
}

android {
    // `namespace` stays at the original Kotlin source-tree package so we don't
    // have to move MainActivity.kt on disk. The user-visible `applicationId`
    // is what Play Store + the launcher use.
    namespace = "app.mood8.mood8"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Core library desugaring is required by flutter_local_notifications
        // (uses java.time on a minSdk that doesn't ship it). Without this
        // the AAR metadata check fails:
        //   "Dependency ':flutter_local_notifications' requires core
        //    library desugaring to be enabled for :app."
        // Pair this with the matching coreLibraryDesugaring dependency
        // declared in the `dependencies { }` block below — both are
        // required, neither alone is enough.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.mood8.app"
        // 24 = Android 7.0. Required by url_launcher_android 6.3.29 which
        // raised its plugin minSdk to 24. Covers ~98% of active devices.
        minSdk = 24
        targetSdk = 34
        // Version is sourced from pubspec.yaml (`version: x.y.z+code`).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                val keystoreFile = file(signingStorePath!!)
                storeFile = if (keystoreFile.isAbsolute) keystoreFile
                            else rootProject.file(signingStorePath!!)
                storePassword = signingStorePass
                keyAlias = signingAlias
                keyPassword = signingKeyPass
            }
        }
    }

    buildTypes {
        release {
            // Sign release with the real keystore when it's available
            // (local key.properties or CI env vars). Otherwise fall
            // back to the debug keystore so dev builds still link —
            // those artifacts can't be uploaded to Play but are fine
            // for sideload testing.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 minification + resource shrinking. Flutter's gradle
            // plugin used to enable these by default for release
            // builds, but AGP 8 made that less consistent — declare
            // explicitly so the keep rules in proguard-rules.pro are
            // actually applied AND so the same release builds well
            // locally and in CI.
            //
            // Why the keep rules matter: without them, R8 strips the
            // generic type signatures (`Signature` attribute) that
            // flutter_local_notifications' Gson TypeToken cache
            // deserializer needs, and every plugin call throws
            // `PlatformException("error", "Missing type parameter.")`
            // in the release build. The debug build works because R8
            // doesn't run. See proguard-rules.pro for the rule set.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Pair to the `isCoreLibraryDesugaringEnabled = true` flag above.
    // 2.1.4 is the latest line that supports AGP 8.x and is what
    // flutter_local_notifications' README pins.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
