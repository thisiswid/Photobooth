# Font bundel

Tujuh berkas ini harus ada di folder ini, dengan nama persis seperti tertulis:

    Bitter-Regular.ttf
    Bitter-SemiBold.ttf
    Bitter-Bold.ttf
    Bitter-ExtraBold.ttf
    ArchivoNarrow-Regular.ttf
    ArchivoNarrow-SemiBold.ttf
    ArchivoNarrow-Bold.ttf

Unduh dari:
  https://fonts.google.com/specimen/Bitter
  https://fonts.google.com/specimen/Archivo+Narrow

Ambil dari folder `static/` di dalam zip-nya — bukan berkas variable font
(`Bitter[wght].ttf`), karena dukungan variable font di Flutter Windows belum
konsisten untuk seluruh rentang berat.

Setelah ketujuhnya ada:
  1. buang tanda pagar pada blok `fonts:` di pubspec.yaml
  2. ganti isi `AppFonts.display` dan `AppFonts.ui` di
     lib/core/theme/app_fonts.dart menjadi TextStyle biasa dengan
     `fontFamily: 'Bitter'` dan `fontFamily: 'ArchivoNarrow'`
  3. hapus berkas ini

Kenapa penting: `google_fonts` mengunduh font saat aplikasi berjalan. Kiosk di
kafe dengan wifi mati akan tampil dengan huruf bawaan Windows, dan seluruh
sistem tipografi hilang tanpa pesan error.
