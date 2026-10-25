plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nwbn.blendburst"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Needed by flutter_local_notifications (java.time on old Androids).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nwbn.blendburst"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing, picked by environment variables:
    // - BB_UPLOAD_KEYSTORE (+ BB_UPLOAD_PASSWORD, BB_UPLOAD_ALIAS): the
    //   private Google Play upload key, used by the Play Store workflow. It
    //   is never committed.
    // - BB_UNSIGNED=1: no signing (the bundle is signed afterwards).
    // - otherwise: the development key below, committed so every test APK
    //   from CI installs over the previous one. Never used for Google Play.
    val uploadKeystore = System.getenv("BB_UPLOAD_KEYSTORE")
    val unsigned = System.getenv("BB_UNSIGNED") == "1"
    signingConfigs {
        create("dev") {
            storeFile = file("dev-release.keystore")
            storePassword = "blendburst"
            keyAlias = "blendburst"
            keyPassword = "blendburst"
        }
        if (uploadKeystore != null) {
            create("upload") {
                storeFile = file(uploadKeystore)
                storePassword = System.getenv("BB_UPLOAD_PASSWORD")
                keyAlias = System.getenv("BB_UPLOAD_ALIAS") ?: "upload"
                keyPassword = System.getenv("BB_UPLOAD_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                uploadKeystore != null -> signingConfigs.getByName("upload")
                unsigned -> null
                else -> signingConfigs.getByName("dev")
            }
            // Keeps the classes the notification plugin stores with Gson.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Recommended with desugaring to avoid crashes on Android 12L+.
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
    // Play Games SDK, started from MainActivity (same version as the
    // games_services plugin uses).
    implementation("com.google.android.gms:play-services-games-v2:21.0.0")
}
