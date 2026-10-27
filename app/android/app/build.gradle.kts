plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase config is git-ignored: app/android/app/src/<flavor>/google-services.json.
// Without it the plugins aren't applied and the app runs on no-op services (Ruling P6-R2).
val firebaseFlavors = listOf("dev", "prod").filter { file("src/$it/google-services.json").exists() }
if (firebaseFlavors.isNotEmpty()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
    // A flavor without its own file (say prod, while only dev has one) still builds.
    extensions.configure<com.google.gms.googleservices.GoogleServicesPlugin.GoogleServicesPluginConfig>("googleServices") {
        missingGoogleServicesStrategy = com.google.gms.googleservices.GoogleServicesPlugin.MissingGoogleServicesStrategy.WARN
    }
    // Crashlytics' mapping upload reads the flavor's own google-services values, so a
    // release build of a flavor without its file would fail; skip the upload for it.
    val flavorsWithoutFirebase = listOf("dev", "prod") - firebaseFlavors.toSet()
    tasks.configureEach {
        if (name.startsWith("uploadCrashlyticsMappingFile") && flavorsWithoutFirebase.any { name.contains(it, ignoreCase = true) }) {
            enabled = false
        }
    }
}

android {
    namespace = "com.digitallinked.atvremote"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.digitallinked.atvremote"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appName"] = "Remotely Dev"
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appName"] = "Remotely for Android TV"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
