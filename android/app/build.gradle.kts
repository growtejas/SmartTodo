plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// ✅ Load keystore properties
val keystorePropertiesFile = rootProject.file("../key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    throw GradleException("key.properties file not found at ${keystorePropertiesFile.absolutePath}")
}

android {
    namespace = "com.tejas.todoapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.tejas.todoapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: throw GradleException("keyAlias not found in key.properties")
            keyPassword = keystoreProperties["keyPassword"] as String? ?: throw GradleException("keyPassword not found in key.properties")
            storeFile = file(keystoreProperties["storeFile"] as String? ?: throw GradleException("storeFile not found in key.properties"))
            storePassword = keystoreProperties["storePassword"] as String? ?: throw GradleException("storePassword not found in key.properties")
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.1.5")
}

flutter {
    source = "../.."
}
