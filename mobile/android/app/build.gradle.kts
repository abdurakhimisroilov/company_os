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

android {
    namespace = "com.companyos.company_os"
    compileSdk = 37


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
            abiFilters.addAll(listOf("arm64-v8a"))
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols += "**/*.so"
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}


