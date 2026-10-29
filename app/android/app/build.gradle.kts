import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase config is git-ignored: app/android/app/src/<flavor>/google-services.json.
// Without it the plugins aren't applied and the app runs on no-op services (Ruling P6-R2).
val firebaseFlavorNames = listOf("dev", "prod")
val firebaseFlavors = firebaseFlavorNames.filter { file("src/$it/google-services.json").exists() }
if (firebaseFlavors.isNotEmpty()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
    // A flavor without its own file (say prod, while only dev has one) still builds.
    extensions.configure<com.google.gms.googleservices.GoogleServicesPlugin.GoogleServicesPluginConfig>("googleServices") {
        missingGoogleServicesStrategy = com.google.gms.googleservices.GoogleServicesPlugin.MissingGoogleServicesStrategy.WARN
    }
    // Crashlytics' mapping upload reads the flavor's own google-services values, so a
    // release build of a flavor without its file would fail; skip the upload for it.
    // Task names look like uploadCrashlyticsMappingFile<Flavor><BuildType>.
    val uploadPrefixesWithoutFirebase = (firebaseFlavorNames - firebaseFlavors.toSet())
        .map { "uploadCrashlyticsMappingFile" + it.replaceFirstChar(Char::uppercase) }
    tasks.configureEach {
        if (uploadPrefixesWithoutFirebase.any { name.startsWith(it) }) {
            enabled = false
        }
    }
} else {
    // The Google Services plugin also finds a file in these places, but this script only
    // looks in src/<flavor>/, so say so instead of silently running without Firebase.
    val unsupportedLocations = listOf("", "src/debug/", "src/release/", "src/profile/") +
        firebaseFlavorNames.flatMap { f -> listOf("Debug", "Release", "Profile").map { "src/$f$it/" } }
    unsupportedLocations.filter { file(it + "google-services.json").exists() }.forEach {
        logger.warn("WARNING: ignoring app/android/app/${it}google-services.json; move it to src/<flavor>/ (dev or prod) to enable Firebase.")
    }
}

// AdMob app ids (Ruling P6-R9). The dev flavor always uses Google's test id. The prod
// flavor reads its own from git-ignored android/secrets.properties (admobAppIdProd) and
// falls back to the test id, so a clean clone still builds.
val admobTestAppId = "ca-app-pub-3940256099942544~3347511713"
val secrets = Properties().apply {
    val file = rootProject.file("secrets.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
// A blank value, or the placeholder of secrets.example.properties left in place, counts as
// "not set": an empty or malformed app id makes the Mobile Ads provider throw at launch.
val admobAppIdProd = secrets.getProperty("admobAppIdProd")?.trim()
    ?.takeIf { it.isNotBlank() && !it.contains("XXXXXXXX") }
// Only a prod build needs the warning; dev always uses the test id on purpose.
val prodRequested = gradle.startParameter.taskNames.any { it.contains("prod", ignoreCase = true) }
if (admobAppIdProd == null && prodRequested) {
    logger.warn("prod uses Google's test AdMob app id; set admobAppIdProd in android/secrets.properties")
}
// A value that isn't an app id (an ad unit id, say) makes the Mobile Ads provider throw at
// launch, so a prod build stops here instead.
val admobAppIdPattern = Regex("""^ca-app-pub-\d{16}~\d{10}$""")
if (prodRequested && admobAppIdProd != null && !admobAppIdPattern.matches(admobAppIdProd))
    throw GradleException("admobAppIdProd in android/secrets.properties must be an AdMob app id (ca-app-pub-<16 digits>~<10 digits>), not an ad unit id; a malformed id stops the app at launch.")

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
            manifestPlaceholders["admobAppId"] = admobTestAppId
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appName"] = "Remotely for Android TV"
            manifestPlaceholders["admobAppId"] = admobAppIdProd ?: admobTestAppId
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
