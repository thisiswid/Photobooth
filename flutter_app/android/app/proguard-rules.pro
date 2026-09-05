# ── JNI / native ────────────────────────────────────────────────────────────
# Method native didaftarkan dari C++ berdasarkan NAMA. Kalau R8 me-rename atau
# menghapusnya, System.loadLibrary gagal dengan NoSuchMethodError saat runtime.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# ── Library UVC / kamera USB ────────────────────────────────────────────────
# com.jiangdg = AndroidUSBCamera (AUSBC) + libuvc. Inilah yang crash sebelumnya:
#   NoSuchMethodError: com.jiangdg.uvc.UVCCamera.nativeSetStatusCallback
-keep class com.jiangdg.** { *; }
-keep interface com.jiangdg.** { *; }
-keep class com.serenegiant.** { *; }
-keep class com.herohan.uvcnode.** { *; }

# Plugin flutter_uvc_camera (versi lokal yang sudah dipatch)
-keep class com.chenyeju.** { *; }

# ── Driver PTP Sony (dipanggil lewat MethodChannel) ─────────────────────────
-keep class com.fakultaskopi.fakultas_kopi_photobooth.** { *; }

# ── Flutter ─────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Callback yang dipanggil balik dari native
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
-keep @androidx.annotation.Keep class * { *; }
