import 'package:flutter/material.dart';

/// Palet Sistem Kamar Gelap.
///
/// Setiap piksel di aplikasi ini adalah salah satu dari DUA material, dan
/// tidak ada material ketiga:
///
///   Kertas       — layar tempat tamu MEMILIH.
///                  Tiket, Bayar, Pilih bingkai, Pilih filter.
///
///   Kamar gelap  — layar tempat GAMBAR jadi subjeknya.
///                  Sambutan, jendela bidik saat pengambilan, Hasil.
///
/// Terang adalah bawaan. Gelap hanya kalau gambar yang jadi subjeknya.
///
/// Warnanya sendiri cuma tiga kelompok: satu tinta dengan empat kekuatan
/// tetap, satu warna spot (jatah tenant), dan tiga tinta semantik. Kalau kamu
/// sedang mengetik nilai opacity untuk mendapatkan tingkat abu-abu, kamu
/// sedang keluar dari sistem — pakai kekuatan tinta yang sudah ada.
abstract final class AppColors {
  // ══ MATERIAL 01 — KERTAS ═════════════════════════════════════════════════

  /// Kertas cetak. Permukaan baca utama di layar terang.
  static const Color paper = Color(0xFFEDE4D6);

  /// Kertas foto — permukaan cetakan, lebih terang dari kertas biasa.
  static const Color paperBright = Color(0xFFF8F3EA);

  /// Cerukan dan sumur di dalam kertas. Menggantikan bayangan.
  static const Color paperDeep = Color(0xFFDCD0BD);

  // ══ MATERIAL 02 — KAMAR GELAP ════════════════════════════════════════════

  /// Meja kamar gelap. Gelap-hangat, bukan hitam dingin — kamar gelap
  /// disinari lampu pengaman, dan semua di dalamnya condong ke cokelat.
  static const Color bench = Color(0xFF17120F);

  /// Panel yang terangkat di atas meja.
  static const Color benchRaised = Color(0xFF211A15);

  /// Garis rambut di atas meja.
  static const Color benchLine = Color(0xFF3A2E26);

  // ══ TINTA — di atas kertas ═══════════════════════════════════════════════
  //
  // Empat kekuatan tetap. Hierarki datang dari sini, BUKAN dari nilai alpha
  // yang dikarang per widget.

  /// Teks utama.
  static const Color ink = Color(0xFF2A211A);

  /// Teks sekunder, keterangan.
  static const Color ink70 = Color(0xFF5E4E41);

  /// Garis rambut, label kecil.
  static const Color ink40 = Color(0xFF9A8874);

  /// Pemisah, keadaan nonaktif.
  static const Color ink15 = Color(0xFFD3C6B3);

  // ══ CAHAYA — di atas kamar gelap ═════════════════════════════════════════

  static const Color light = Color(0xFFE8DFD2);
  static const Color light60 = Color(0xFF9C9082);
  static const Color light30 = Color(0xFF6A5D51);

  // ══ WARNA SPOT — jatah tenant ════════════════════════════════════════════
  //
  // Satu warna spot untuk seluruh aplikasi, dan tenant boleh menggantinya
  // lewat `cafe.theme.primaryColor`. Bawaannya merah stempel.
  //
  // Emas TURUN PANGKAT: dari border di 9 komponen berbeda, jadi tidak dipakai
  // sama sekali. Emas di mana-mana membaca sebagai kasino, bukan heritage.

  static const Color spot = Color(0xFFA8432F);

  /// Tingkatan yang terbaca di atas meja gelap.
  static const Color spotLit = Color(0xFFCE6E4A);

  /// Garis dan bingkai redup di atas meja gelap.
  static const Color spotDim = Color(0xFF6B2C1E);

  // ══ TINTA SEMANTIK ═══════════════════════════════════════════════════════
  //
  // Dibuat sebagai tinta cetak, bukan lampu peringatan.
  //
  // PENTING: karena warna spot milik tenant bisa saja merah, warna TIDAK
  // BOLEH jadi satu-satunya penanda status. Setiap status wajib membawa label
  // tercetak — BERHASIL / GAGAL — dalam kapital condensed. Itu kebetulan juga
  // jawaban aksesibilitas yang benar.

  static const Color inkGreen = Color(0xFF3F5B41);
  static const Color inkGreenLit = Color(0xFF7A9B7C);
  static const Color inkOxide = Color(0xFF8C2E1E);
  static const Color inkOxideLit = Color(0xFFC4705E);

  // ══ LAIN-LAIN ════════════════════════════════════════════════════════════

  /// Selubung di belakang dialog dan overlay.
  static const Color scrim = Color(0xE617120F);

  /// Putih sungguhan. HANYA untuk latar kode QR — pemindai butuh putih
  /// murni, bukan kertas hangat.
  static const Color white = Color(0xFFFFFFFF);

  // ══════════════════════════════════════════════════════════════════════════
  // PETA SEMENTARA — nama lama menunjuk ke token baru
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Nama-nama di bawah ini adalah palet lama. Semuanya dipertahankan supaya
  // aplikasi tetap ter-kompilasi dan LANGSUNG berubah tampilan tanpa harus
  // menyunting 30 berkas layar sekaligus.
  //
  // Yang paling menentukan: `gold` dipakai 170 kali, hampir semuanya sebagai
  // border hiasan. Sekarang dia menunjuk ke tinta 40 — garis rambut cetak.
  // Satu perubahan ini yang membuang kesan "emas di mana-mana" sekaligus.
  //
  // Beberapa tempat memang butuh aksen sungguhan (keadaan terpilih, indikator
  // langsung, tanda pencetak). Setelah perubahan ini, tempat-tempat itu akan
  // terlihat terlalu sunyi — dan itu memang cara menemukannya. Ganti yang
  // seperti itu ke `spot` satu per satu saat layarnya dikerjakan.
  //
  // Anotasi @Deprecated sengaja BELUM dipasang: dengan 400+ pemakaian, keluaran
  // `flutter analyze` jadi tidak terbaca, padahal justru sedang dipakai untuk
  // memverifikasi perubahan ini. Pasang setelah build hijau.
  //
  // Hapus seluruh blok ini kalau sudah tidak ada yang menunjuk ke sini.

  static const Color gold = ink40;                 // 170x — border hiasan
  static const Color darkBrown = ink;              // 135x
  static const Color creamWhite = paperBright;     // 103x
  static const Color coffeeBrown = ink;            //  36x
  static const Color borderWarm = ink15;           //  23x
  static const Color textPrimary = ink;            //  20x
  static const Color brown = ink70;                //  20x
  static const Color textSecondary = ink70;        //  15x
  static const Color error = inkOxide;             //  11x
  static const Color darkCoffee = bench;           //  11x
  static const Color buttonBrown = ink;            //   9x
  static const Color parchmentLight = paperBright; //   8x
  static const Color parchmentDark = paperDeep;    //   8x
  static const Color goldAccent = ink40;           //   7x
  static const Color parchment = paper;            //   6x
  static const Color textMuted = ink40;            //   5x
  static const Color lightBrown = ink40;           //   4x
  static const Color surfaceModal = paperBright;   //   3x
  static const Color success = inkGreen;           //   3x
  static const Color cream = paper;                //   3x
  static const Color backgroundParchment = paper;  //   3x
  static const Color surfaceCard = paperBright;    //   2x
  static const Color overlayDark = scrim;          //   2x
  static const Color errorLight = inkOxideLit;     //   2x
  static const Color antiqueBrass = ink40;         //   2x
  static const Color warningLight = spotLit;       //   1x
  static const Color warning = spot;               //   1x
  static const Color vintageRust = spot;           //   1x
  static const Color coffeeLight = ink70;          //   1x
  static const Color borderLight = ink15;          //   1x
  static const Color borderGold = ink40;           //   1x
}
