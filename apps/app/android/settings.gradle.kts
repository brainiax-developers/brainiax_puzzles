pluginManagement {
    // Read flutter.sdk for this block
    val props = java.util.Properties().apply {
        file("local.properties").inputStream().use { load(it) }
    }
    val flutterSdkPath = checkNotNull(props.getProperty("flutter.sdk")) {
        "flutter.sdk not set in local.properties"
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()

        // Read flutter.sdk again for this block (separate scope)
        val props = java.util.Properties().apply {
            file("local.properties").inputStream().use { load(it) }
        }
        val flutterSdkPath = checkNotNull(props.getProperty("flutter.sdk")) {
            "flutter.sdk not set in local.properties"
        }
        // Flutter engine artifacts (needed for io.flutter:flutter_embedding_*)
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        maven { url = uri("$flutterSdkPath/bin/cache/artifacts/engine") }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
