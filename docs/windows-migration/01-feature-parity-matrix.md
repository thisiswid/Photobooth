# Matriks Paritas Fitur — Android → Windows

Dokumen ini memetakan setiap fitur yang ada sekarang ke nasibnya di Windows.
Dipakai sebagai checklist penerimaan: **tidak ada baris yang boleh berstatus
"belum diverifikasi" saat go-live.**

Legenda status:

| Simbol | Arti |
|---|---|
| 🟢 | Tidak terpengaruh — kode sama persis, tidak perlu disentuh |
| 🟡 | Perlu implementasi ulang di lapisan platform, perilaku tetap sama |
| 🔵 | Perilaku **membaik** — ini alasan migrasi |
| 🔴 | Hilang atau berubah — butuh mitigasi |

---

## 1. Alur Pelanggan (FR-01 … FR-29)

| FR | Fitur | Status | Catatan |
|---|---|---|---|
| FR-01 | Welcome Screen + live camera background | 🟡 | Sumber preview berubah ke `camera_windows`; widget tidak berubah |
| FR-02 | Branding di Welcome Screen | 🟢 | |
| FR-03…FR-05 | Navigasi Tutorial → Payment | 🟢 | `go_router`, tidak tersentuh |
| FR-06 | Xendit QRIS + QR code | 🟢 | Murni HTTP |
| FR-07 | Status pembayaran via webhook | 🟢 | Backend |
| FR-08…FR-10 | Start session + timer 5 menit | 🟢 | |
| FR-11…FR-12 | Pemilihan frame | 🟢 | |
| FR-13…FR-15 | Photo Session + toggle Mirror | 🟡 | `Transform.flip` tetap; sumber preview berubah |
| FR-16 | Countdown 5 detik | 🟢 | |
| FR-17 | **Capture dari kamera** | 🔵 | Sony Camera Remote SDK menggantikan opcode rekayasa balik. AF ditunggu sebagai properti, bukan `delay(500)` |
| FR-18…FR-20 | Photo Result, retake maks 2x, multi-pose | 🟢 | |
| FR-21…FR-22 | Filter & render hasil akhir | 🟢 | Dirender backend |
| FR-23 | Final Result Screen | 🟢 | |
| FR-24 | **Auto print ke Epson L8050** | 🔵 | Silent sejati. Tanpa dialog, tanpa Accessibility, tanpa overlay |
| FR-25 | Status cetak PRINTING → SUCCESS/FAILED | 🔵 | Kini status **sesungguhnya** dari spooler, bukan tebakan |
| FR-26 | QR hasil (GIF, hasil akhir, foto individual) | 🟢 | |
| FR-27…FR-29 | Selesai, kembali ke Welcome, timeout | 🟢 | |

**Ringkasan:** dari 29 persyaratan fungsional pelanggan, **21 tidak tersentuh**,
5 perlu implementasi ulang di lapisan platform, dan 3 justru membaik.

---

## 2. Kapabilitas Perangkat

| Kapabilitas | Android sekarang | Windows | Status |
|---|---|---|---|
| Cetak tanpa dialog | Mustahil. Ditambal Accessibility + overlay | `Printing.directPrintPdf()` ke driver Epson | 🔵 |
| Rasterisasi ESC/P-R | Epson Print Service di tablet | Driver Epson resmi | 🔵 |
| Status printer | Tidak tersedia | Win32 spooler API | 🔵 |
| Pilih printer | Terbatas | `Printing.listPrinters()` | 🔵 |
| Preview UVC | Fork plugin dipatch + workaround generasi view | `camera_windows` bawaan | 🔵 |
| Shutter full-res | Opcode vendor rekayasa balik | Camera Remote SDK resmi | 🔵 |
| Deteksi AF lock | Tidak ada — `delay(500)` menebak | Properti SDK yang bisa dibaca | 🔵 |
| Deteksi perangkat USB | USB Host API + panel diagnostik | Ditangani OS | 🟡 |
| Fullscreen kiosk | `SystemChrome.immersiveSticky` | `window_manager` + Shell Launcher | 🟡 |
| Mencegah keluar aplikasi | Kiosk mode Android | Blokir `Alt+F4` + tombol Windows | 🔴 |
| Penyimpanan aman | Keystore | DPAPI (`flutter_secure_storage_windows`) | 🟢 |
| Keyboard di layar | Otomatis | TabTip / keyboard fisik | 🔴 |
| Sumber daya cadangan | **Baterai tablet** | **Tidak ada** — butuh UPS | 🔴 |
| Pembaruan aplikasi | APK | Installer + field versi di heartbeat | 🟡 |
| Update OS terkendali | Android Enterprise | Group Policy (butuh Win 11 Pro) | 🔴 |

---

## 3. Mitigasi untuk Baris Merah

| Risiko | Mitigasi |
|---|---|
| Pelanggan bisa keluar dari aplikasi | `window_manager` fullscreen + blokir `Alt+F4`, tombol Windows, `Ctrl+Shift+Esc`. Shell Launcher pada Windows 11 Pro sebagai lapisan kedua |
| Tidak ada keyboard di layar | Tidak ada input teks di alur pelanggan — seluruh `TextField` hanya milik operator (PIN admin, IP printer, pairing key). Operator memakai keyboard USB atau TabTip |
| Tidak ada baterai | UPS ~500VA masuk daftar belanja wajib. Lihat [BOM](03-hardware-bom.md) |
| Windows Update reboot mendadak | Windows 11 Pro + Group Policy: tunda feature update, atur active hours mencakup seluruh jam operasional |

---

## 4. Komponen yang Dihapus dari Jalur Windows

Dihapus **hanya dari jalur eksekusi Windows**. File tetap ada di repo selama
build Android masih dipelihara (NFR-05).

| Komponen | Baris | Alasan |
|---|---|---|
| `KioskAutoPrintService.kt` | 295 | Tidak ada dialog untuk ditekan |
| `MainActivity.kt` | 1.089 | Probe USB, overlay, diagnostik jaringan tidak relevan |
| `SonyPtpCameraManager.kt` | 1.299 | Digantikan helper Camera Remote SDK |
| `packages/flutter_uvc_camera` | fork lokal | Capture card = webcam biasa di Windows |
| Percabangan IPP di `printer_service.dart` | — | Driver Epson menggantikan seluruh jalur |
| Mode Silent Ketat & kontrol penutup dialog | — | Tidak ada dialog yang perlu ditutupi |
| Panel AUTO-PRINT HELPER, USB DIAGNOSTIC, NETWORK DIAGNOSTIC, IPP DIRECT | ±1.400 | Diagnostik khusus Android |

**Total kode yang tidak lagi dieksekusi di produksi: sekitar 4.000 baris.**

`lib/core/services/ipp/` (1.226 baris) **tetap disimpan** — siap pakai bila
printer diganti ke model ber-AirPrint.
