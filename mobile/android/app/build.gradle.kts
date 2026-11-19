import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val pubspecFile = File(project.rootDir.parentFile, "pubspec.yaml")
var parsedVersionName = "1.0.2"
var parsedVersionCode = 3
if (pubspecFile.exists()) {
    val versionLine = pubspecFile.readLines().find { it.trim().startsWith("version:") }
    if (versionLine != null) {
        val vPart = versionLine.substringAfter("version:").trim()
        val parts = vPart.split("+")
        if (parts.isNotEmpty()) parsedVersionName = parts[0].trim()
        if (parts.size > 1) parsedVersionCode = parts[1].trim().toIntOrNull() ?: 3
    }
}

// Release signing: android/key.properties (git-ignored) points at the upload key.
// Without it, release builds fall back to the debug key (CI, local testing).
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

// PLAY_STORE=true builds the Google Play variant: no self-updater permission.
val isPlayStoreBuild = System.getenv("PLAY_STORE") == "true"

android {
    namespace = "com.companyos.company_os"
    compileSdk = flutter.compileSdkVersion


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.companyos.company_os"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = parsedVersionCode
        versionName = parsedVersionName
        multiDexEnabled = true
        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
        }
    }

    if (isPlayStoreBuild) {
        sourceSets.getByName("release").manifest.srcFile("src/playstore/AndroidManifest.xml")
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
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


