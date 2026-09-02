plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.fakultaskopi.fakultas_kopi_photobooth"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fakultaskopi.fakultas_kopi_photobooth"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // R8 dimatikan untuk release.
            //
            // Library UVC (com.jiangdg.*) mendaftarkan method native dari sisi
            // C++ BERDASARKAN NAMA. Begitu R8 me-rename/menghapusnya, JNI gagal
            // memuat library dan aplikasi crash saat membuka kamera:
            //   NoSuchMethodError: com.jiangdg.uvc.UVCCamera.nativeSetStatusCallback
            //
            // Blok ini sebelumnya tidak mendeklarasikan proguardFiles sama
            // sekali, sehingga app/proguard-rules.pro TIDAK PERNAH dipakai —
            // keep rule yang sudah ditulis di sana pun tidak berpengaruh.
            //
            // Untuk aplikasi kiosk, ukuran APK tidak penting sementara
            // keandalan sangat penting. proguardFiles tetap disambungkan agar
            // aturannya benar bila suatu saat R8 dinyalakan lagi.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
