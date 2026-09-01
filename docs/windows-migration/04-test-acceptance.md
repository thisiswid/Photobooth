# Rencana Uji & Kriteria Penerimaan

## 1. Baseline — Ukur Dulu Sebelum Pindah

**Kerjakan di tablet Android yang sedang berjalan, sebelum migrasi dimulai.**
Tanpa baseline, tidak ada cara membuktikan Windows lebih baik.

| Metrik | Cara mengukur |
|---|---|
| Waktu shutter → foto tampil di layar | Stopwatch di empat titik: shutter ditekan, ObjectAdded diterima, byte terakhir masuk, gambar siap tampil |
| Waktu decode + resize per foto | **Sudah tersedia** — log `🗜️ [UploadPrep] ... dalam Xms` di `photo_upload_prep_service.dart` |
| Waktu Result Screen → kertas keluar | Stopwatch manual |
| Frekuensi kegagalan Accessibility | Hitung dari checklist buka-kios harian |
| Sesi macet per 100 sesi | Catatan operator |

Simpan hasilnya sebagai `docs/windows-migration/baseline-android.md`.

---

## 2. Penerimaan per Fase

### Fase 0 — Spike Cetak ⛔ GERBANG

| # | Uji | Lulus bila |
|---|---|---|
| 0.1 | `Printing.listPrinters()` | L8050 muncul di daftar |
| 0.2 | `Printing.directPrintPdf()` gambar uji 4R | Kertas keluar, gambar benar (bukan karakter acak) |
| 0.3 | Borderless | Tidak ada border putih di keempat sisi |
| 0.4 | Pengamatan layar selama cetak | **Nol dialog muncul** |
| 0.5 | Baca status printer | Kertas dikeluarkan dari tray → status berubah secara programatik |

**Bila 0.3 atau 0.4 gagal, seluruh premis migrasi gugur.** Laporkan apa adanya,
jangan cari akal-akalan.

### Fase 1 — Kerangka Windows

| # | Uji | Lulus bila |
|---|---|---|
| 1.1 | `flutter build windows` | Build berhasil |
| 1.2 | Aplikasi dijalankan | Fullscreen, tanpa taskbar, tanpa border |
| 1.3 | Navigasi seluruh layar | Semua rute `go_router` berfungsi tanpa kamera/printer |
| 1.4 | Provisioning | Pairing key tersimpan (DPAPI), device terhubung ke tenant |
| 1.5 | Heartbeat | Payload sampai ke dashboard admin |
| 1.6 | **Build Android** | Masih hijau |

### Fase 2 — Jalur Cetak

| # | Uji | Lulus bila |
|---|---|---|
| 2.1 | Cetak dari Final Result Screen | Satu lembar 4R borderless, tanpa dialog |
| 2.2 | Tekan tombol cetak dua kali cepat | Tetap **satu** lembar (lock `_isPrintingBusy`) |
| 2.3 | Setelan `copies = 2` | Keluar 2 lembar — utang teknis lama terselesaikan |
| 2.4 | Cabut kabel printer lalu cetak | Gagal terkendali dengan pesan jelas, aplikasi tidak crash |
| 2.5 | Habiskan kertas | Status `out_of_paper` muncul di heartbeat ≤ 60 detik |
| 2.6 | Setelan margin & quality | Terpakai, bukan hanya tersimpan |

### Fase 3 — Kamera Capture Card

| # | Uji | Lulus bila |
|---|---|---|
| 3.1 | Preview di monitor kiosk | 1920x1080, mulus, tanpa patah-patah |
| 3.2 | Toggle Mirror | Berfungsi seperti di Android |
| 3.3 | Sesi penuh mode `hdmiOnly` | Welcome → cetak, selesai tanpa error |
| 3.4 | Cabut capture card saat sesi | Gagal terkendali, tidak crash |

### Fase 4 — Sony Camera Remote SDK ⛔ GERBANG

Sebelum kode ditulis:

| # | Verifikasi | Lulus bila |
|---|---|---|
| 4.0a | Lisensi SDK untuk pemakaian komersial | Ketentuan dibaca dan dilaporkan |
| 4.0b | ZV-E10 di daftar model SDK terbaru | Terkonfirmasi |
| 4.0c | Sample `RemoteCli` | Shutter & transfer berfungsi di luar aplikasi kita |

Setelah implementasi:

| # | Uji | Lulus bila |
|---|---|---|
| 4.1 | Capture | File 6000x4000 sampai ke disk |
| 4.2 | AF di cahaya redup | Menunggu AF lock sesungguhnya — foto tajam, bukan lembut |
| 4.3 | **Cabut kabel kamera di tengah sesi** | Jatuh ke `hdmiOnly`, **sesi pelanggan tidak mati** |
| 4.4 | Matikan paksa proses helper | Sama seperti 4.3 |
| 4.5 | Degradasi terlaporkan | `capture_mode` di heartbeat berubah |
| 4.6 | 50 jepretan berturut-turut | Tidak ada kebocoran memori, tidak ada hang |

### Fase 5-6 — Settings & Kalibrasi

| # | Uji | Lulus bila |
|---|---|---|
| 5.1 | Panel settings | Tidak ada tombol mati atau panel khusus Android tersisa |
| 5.2 | Pilih printer dari daftar | Berfungsi |
| 6.1 | Ukuran tombol & teks di monitor sungguhan | Terbaca dan nyaman ditekan sambil berdiri |
| 6.2 | Sentuh setelah rotasi portrait | Titik sentuh tepat, tidak meleset 90 derajat |
| 6.3 | Jangkauan tangan | Tombol aksi utama di sepertiga bawah |

### Fase 7 — Packaging

| # | Uji | Lulus bila |
|---|---|---|
| 7.1 | Installer di mesin Windows bersih | Dari nol sampai siap jual **≤ 30 menit** |
| 7.2 | Reboot | Autologin + autostart, langsung ke layar Welcome |
| 7.3 | Waktu boot | ≤ 90 detik dari listrik menyala |
| 7.4 | `Alt+F4`, tombol Windows, `Ctrl+Shift+Esc` | Tidak bisa keluar dari aplikasi |
| 7.5 | Pembaruan jarak jauh | Versi baru terpasang tanpa kunjungan fisik |

---

## 3. Uji Injeksi Kegagalan

Dijalankan sebelum go-live. Setiap skenario: sistem harus **gagal dengan
terkendali** dan **melaporkannya**, bukan diam atau macet.

| # | Skenario | Perilaku yang diharapkan |
|---|---|---|
| F-1 | Cabut kabel kamera saat countdown | Jatuh ke `hdmiOnly`, sesi lanjut |
| F-2 | Cabut capture card saat preview | Pesan jelas, sesi bisa dibatalkan dengan rapi |
| F-3 | Matikan printer saat auto-print | Status PRINT FAILED, pelanggan tetap dapat QR |
| F-4 | Kertas habis di tengah sesi | Terdeteksi, dilaporkan, sesi tetap selesai |
| F-5 | Cabut jaringan saat pembayaran | Timeout jelas, tidak menggantung selamanya |
| F-6 | Cabut daya (dengan UPS) | Shutdown rapi, tidak ada file korup |
| F-7 | Cabut daya (tanpa UPS) | **Uji ini membuktikan kenapa UPS wajib** |
| F-8 | Paksa Windows Update | Tidak reboot di dalam jam operasional |
| F-9 | Biarkan idle 24 jam | Tidak sleep, tidak screensaver, kamera masih hidup |

---

## 4. Soak Test — Gerbang Go-Live

**7 hari berturut-turut tanpa intervensi manual** (NFR-01).

Dicatat harian: jumlah sesi selesai, kegagalan cetak, degradasi mode capture,
crash, dan apa pun yang butuh sentuhan manusia.

> Fase ini tidak bisa dipercepat, termasuk dengan bantuan AI. Masalah kiosk
> Windows — reboot update, popup driver, memory leak — baru muncul setelah
> berhari-hari berjalan. Jangan potong.

**Go-live bila:** 7 hari berjalan, nol intervensi manual, dan semua uji injeksi
kegagalan lulus.
