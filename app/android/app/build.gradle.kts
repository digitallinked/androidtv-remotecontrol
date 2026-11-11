import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Warnings use logger.quiet: `flutter build` runs Gradle with -q, which hides logger.warn.

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
}
// The Google Services plugin also finds a file in these places, but this script only
// looks in src/<flavor>/, so say so instead of silently misconfiguring Firebase. The scan
// runs whatever the flavors have. With no flavor file the plugin isn't applied, so the
// stray file is ignored; once it is applied, it may use the stray file for a flavor that
// has none, while that flavor's Crashlytics upload stays off (Rulings P9-R3, P9-C2).
val unsupportedLocations = listOf("", "src/debug/", "src/release/", "src/profile/") +
    firebaseFlavorNames.flatMap { f -> listOf("Debug", "Release", "Profile").map { "src/$f$it/" } }
unsupportedLocations.filter { file(it + "google-services.json").exists() }.forEach {
    val note = if (firebaseFlavors.isEmpty())
        "WARNING: ignoring app/android/app/${it}google-services.json; move it to src/<flavor>/ (dev or prod) to enable Firebase."
    else
        "WARNING: app/android/app/${it}google-services.json is in a location this build script doesn't manage. The Google Services plugin may use it for a flavor that has no src/<flavor>/google-services.json, and that flavor's Crashlytics mapping upload stays off. Move it to src/<flavor>/ (dev or prod)."
    logger.quiet(note)
}

// Upload-key signing (Ruling P9-R3). Git-ignored android/key.properties names the upload
// keystore, which lives outside the repo; see android/key.properties.example.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { load(it) }
}
val signingKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
// A blank value counts as missing, as in the release checker (app/tool/release_check.dart).
fun keyProperty(name: String): String? = keyProperties.getProperty(name)?.takeIf { it.isNotBlank() }
val missingSigningKeys = signingKeys.filter { keyProperty(it) == null }
// storeFile may be absolute or start with ~/ (the home directory); anything else is
// relative to android/.
val releaseStoreFile: File? = keyProperty("storeFile")?.trim()?.let { path ->
    if (path.startsWith("~/")) File(System.getProperty("user.home"), path.removePrefix("~/"))
    else rootProject.file(path)
}
// Null when key.properties is usable, or absent (the bundle rule below handles that).
val releaseSigningProblem: String? = when {
    !keyPropertiesFile.exists() -> null
    missingSigningKeys.isNotEmpty() ->
        "android/key.properties is incomplete: ${missingSigningKeys.joinToString(", ")} missing. See android/key.properties.example."
    releaseStoreFile?.isFile != true ->
        "android/key.properties points at ${releaseStoreFile?.path}, which doesn't exist. Restore the upload keystore from your backup, or fix storeFile."
    else -> null
}
val releaseSigningUsable = keyPropertiesFile.exists() && releaseSigningProblem == null
// Flutter passes Gradle one task per build, such as assembleProdRelease or bundleDevRelease.
// These name checks stop a Flutter build early; the task-graph check below also catches
// aggregate and abbreviated bundle tasks (gradlew bundle, :app:bundleProdRel). gradlew build
// and assemble never make a bundle, so the bundle rules don't apply to them.
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val uploadBundleRequested = gradle.startParameter.taskNames.any { Regex("(?i)bundle\\w*prod\\w*release").containsMatchIn(it) }

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
// Google's test publisher: the fallback, or a test id someone set in secrets.properties.
val admobTestPublisherPrefix = "ca-app-pub-3940256099942544~"
val prodUsesTestAdmobId = (admobAppIdProd ?: admobTestAppId).startsWith(admobTestPublisherPrefix)
// Only a prod build needs the warning; dev always uses the test id on purpose.
val prodRequested = gradle.startParameter.taskNames.any { it.contains("prod", ignoreCase = true) }
if (prodUsesTestAdmobId && prodRequested) {
    logger.quiet("prod uses Google's test AdMob app id; set admobAppIdProd in android/secrets.properties")
}
// A value that isn't an app id (an ad unit id, say) makes the Mobile Ads provider throw at
// launch, so a prod build stops here instead (and the upload bundle below, on every path).
val admobAppIdPattern = Regex("""^ca-app-pub-\d{16}~\d{10}$""")
val admobAppIdMalformed = admobAppIdProd != null && !admobAppIdPattern.matches(admobAppIdProd)
val admobAppIdMalformedMessage = "admobAppIdProd in android/secrets.properties must be an AdMob app id (ca-app-pub-<16 digits>~<10 digits>), not an ad unit id; a malformed id stops the app at launch."
if (prodRequested && admobAppIdMalformed) throw GradleException(admobAppIdMalformedMessage)

// What stops the prod upload bundle, reported together (Rulings P9-R3, P9-R4, P9-C2). Only
// it goes to Google Play, so only it must have the upload key and the real AdMob app id:
// release APKs (flutter run --release, the prodRelease manifest check) and dev bundles still
// build, with the debug key and, for prod, the test app id. Google's test publisher is
// refused whether it is the fallback or was set in secrets.properties, and a malformed id is
// refused here too, so `gradlew bundle` (no prod task name) hits it in the backstop.
val uploadBundleProblems: List<String> = listOfNotNull(
    releaseSigningProblem
        ?: if (!keyPropertiesFile.exists()) "A prod app bundle is the file you upload to Google Play, so it must be signed with the upload key: copy android/key.properties.example to android/key.properties and fill it in (store-release skill). Release APKs and dev bundles still build, signed with the debug key." else null,
    if (prodUsesTestAdmobId) "A prod app bundle needs the real AdMob app id: set admobAppIdProd in android/secrets.properties." else null,
    if (admobAppIdMalformed) admobAppIdMalformedMessage else null,
)
// A broken key.properties stops every release task; a missing one only the upload bundle.
fun refuseReleaseTasks(release: Boolean, uploadBundle: Boolean) {
    if (uploadBundle && uploadBundleProblems.isNotEmpty()) throw GradleException(uploadBundleProblems.joinToString("\n"))
    if (release && releaseSigningProblem != null) throw GradleException(releaseSigningProblem)
}
refuseReleaseTasks(releaseRequested, uploadBundleRequested)
// The backstop: the tasks Gradle will really run in this module, whatever was typed.
gradle.taskGraph.whenReady {
    val names = allTasks.filter { it.project == project }.map { it.name }
    val release = names.any { it.contains("Release") }
    refuseReleaseTasks(release, "bundleProdRelease" in names)
    if (!keyPropertiesFile.exists() && release)
        logger.quiet("release build signed with the debug key (no android/key.properties); don't upload it.")
}

android {
    namespace = "my.newy.remotely"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "my.newy.remotely"
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

    signingConfigs {
        if (releaseSigningUsable) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keyProperty("storePassword")
                keyAlias = keyProperty("keyAlias")?.trim()
                keyPassword = keyProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Both flavors sign with the upload key when key.properties is usable. Without
            // it, release builds use the debug key, so `flutter run --release` and the
            // prodRelease APK still work; the prod bundle is refused above.
            signingConfig = if (releaseSigningUsable) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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
