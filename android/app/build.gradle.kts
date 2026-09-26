plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.yas369.platecheck"
    // permission_handler_android needs the Android 37 SDK to compile against.
    // This only sets which APIs the build can see; it doesn't change which
    // phones the app installs on (minSdk) or its runtime behaviour (targetSdk).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Needed by flutter_local_notifications for scheduled reminders.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // One fixed key for every build, the same key the earlier version of the
    // app used. Android only installs an update signed with the same key as
    // the installed app, and reinstalling would erase your food log. This is a
    // personal, sideloaded app, so the key lives in the repo; see README before
    // ever publishing it to a store.
    signingConfigs {
        create("platecheck") {
            storeFile = file("plate-check.keystore")
            storePassword = "platecheck"
            keyAlias = "platecheck"
            keyPassword = "platecheck"
        }
    }

    defaultConfig {
        // Same ID as the earlier version, so this installs over it and keeps its data.
        applicationId = "com.yas369.platecheck"
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

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("platecheck")
        }
        release {
            signingConfig = signingConfigs.getByName("platecheck")
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
}
