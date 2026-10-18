plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

configure<com.android.build.api.dsl.ApplicationExtension> {
    namespace = "com.example.dabafoodstall"
    compileSdk = 36 // 🔑 FIX CRITIQUE : Augmenté à 36 pour satisfaire sqflite_android et blue_thermal_printer_plus
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.dabafoodstall"
        minSdk = flutter.minSdkVersion
        targetSdk = 33 // 🔑 SÉCURITÉ : Reste figé à 33 pour cibler parfaitement Android 13 à l'exécution
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        getByName("debug") {
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("debug") {
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
