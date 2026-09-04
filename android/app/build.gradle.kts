import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePropertiesFile = rootProject.file("key.properties")
require(releaseKeystorePropertiesFile.exists()) {
    "Missing android/key.properties. Refusing to build with an unintended signing key."
}
val releaseKeystoreProperties = Properties().apply {
    FileInputStream(releaseKeystorePropertiesFile).use(::load)
}

android {
    namespace = "com.photostorer.photo_storer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    flavorDimensions += "data"

    productFlavors {
        create("standard") {
            dimension = "data"
        }
        create("zero") {
            dimension = "data"
            applicationIdSuffix = ".zero"
            versionNameSuffix = "-zero"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.photostorer.photo_storer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("fixedRelease") {
            storeFile = file(releaseKeystoreProperties.getProperty("storeFile"))
            storePassword = releaseKeystoreProperties.getProperty("storePassword")
            keyAlias = releaseKeystoreProperties.getProperty("keyAlias")
            keyPassword = releaseKeystoreProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        getByName("debug") {
            // deploy.bat installs standardDebug. Sign it with the same fixed
            // identity so development deployments also preserve app data.
            signingConfig = signingConfigs.getByName("fixedRelease")
        }
        release {
            // Keep this signing identity stable so installed versions can be
            // upgraded without uninstalling and losing local app data.
            signingConfig = signingConfigs.getByName("fixedRelease")
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
