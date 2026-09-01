# Rencana Cycle & Papan Pelacakan

Branch kerja: **`feat/windows-migration`**
Dokumen ini adalah papan status. Perbarui kolom Status dan Tanggal setiap kali
sebuah cycle selesai.

Legenda status: `⬜ belum` · `🟨 jalan` · `✅ selesai` · `⛔ terblokir`

---

## Papan Status

| Cycle | Fokus | Estimasi | Status | Mulai | Selesai |
|---|---|---|---|---|---|
| **P** | Persiapan & baseline | 2-3 hari | ⬜ | | |
| **C0** | Spike cetak ⛔ **GERBANG** | 1 hari | ⬜ | | |
| **C1** | Kerangka Windows | 2-3 hari | ⬜ | | |
| **C2** | Jalur cetak | 3-4 hari | ⬜ | | |
| **C3** | Kamera capture card 🎯 **BISA PRODUKSI** | 3-4 hari | ⬜ | | |
| **C4** | Shutter Sony SDK ⛔ **GERBANG** | 1-2 minggu | ⬜ | | |
| **C5** | Settings & diagnostik | 3-4 hari | ⬜ | | |
| **C6** | Kalibrasi layar sentuh | 2 hari | ⬜ | | |
| **C7** | Packaging & penguncian kiosk | 3-4 hari | ⬜ | | |
| **C8** | Soak test 7 hari | 7 hari | ⬜ | | |

**Total realistis: 4-6 minggu.** Variansi terbesar ada di C4.

---

## Cycle P — Persiapan & Baseline

Bisa dikerjakan paralel dengan C0. Tanpa baseline, tidak ada cara membuktikan
Windows lebih baik — hanya perasaan.

> 💡 **C0 tidak menunggu cycle ini.** Spike cetak bisa dijalankan di **laptop
> development** begitu Flutter + Visual Studio Build Tools (workload "Desktop
> development with C++") + driver Epson terpasang. Lihat
> [BOM §0](03-hardware-bom.md). Pengadaan hardware kiosk (P-1 sampai P-4) baru
> menghambat mulai Cycle C7 dan C8.

- [ ] **P-1** Beli / siapkan mini PC sesuai [BOM](03-hardware-bom.md) §2
- [ ] **P-2** Siapkan monitor sentuh + UPS
- [ ] **P-3** Install Windows 11 **Pro** dengan lisensi asli
- [ ] **P-4** Install driver Epson L8050 resmi
- [ ] **P-5** Ukur baseline di tablet Android: waktu shutter → foto tampil
- [ ] **P-6** Ambil angka decode dari log `🗜️ [UploadPrep] ... dalam Xms` (sudah ada di kode)
- [ ] **P-7** Ukur waktu Result Screen → kertas keluar
- [ ] **P-8** Tulis hasilnya ke `docs/windows-migration/baseline-android.md`

**Selesai bila:** hardware siap dinyalakan dan file baseline sudah ada isinya.

---

## Cycle C0 — Spike Cetak ⛔ GERBANG

Proyek Flutter **kosong dan terpisah** (misal `C:\spike_print`), bukan di dalam
`flutter_app/`.

- [ ] **C0-1** `Printing.listPrinters()` — L8050 muncul di daftar
- [ ] **C0-2** `Printing.directPrintPdf()` gambar uji ukuran 4R
- [ ] **C0-3** Borderless benar — tidak ada border putih di keempat sisi
- [ ] **C0-4** **Nol dialog muncul** selama proses cetak
- [ ] **C0-5** Baca status printer (keluarkan kertas dari tray → status berubah)
- [ ] **C0-6** Catat pustaka mana yang dipakai: `printing` / `printing_ffi` / `windows_printer`

> Dijalankan di **laptop development**, bukan di mesin kiosk. Prasyarat: Flutter
> SDK, Visual Studio Build Tools dengan workload "Desktop development with C++"
> (**sering terlewat — tanpa ini build Windows gagal**), driver Epson L8050, dan
> printer tersambung.

**Selesai bila:** kertas foto 4R keluar penuh tanpa border, tanpa satu pun dialog,
dan status printer terbaca secara programatik.

> ⛔ **Bila C0-3 atau C0-4 gagal, seluruh premis migrasi gugur.** Berhenti,
> laporkan apa adanya, dan pertimbangkan opsi Raspberry Pi + CUPS sebagai
> pengganti. Jangan mencari akal-akalan.

**Bukti yang dilampirkan:** foto hasil cetak + rekaman layar saat mencetak.

---

## Cycle C1 — Kerangka Windows

- [ ] **C1-1** `flutter build windows` berhasil apa adanya
- [ ] **C1-2** Tambah `window_manager`, ganti `SystemChrome.setEnabledSystemUIMode` di `main.dart` (fungsi itu tidak berefek di Windows)
- [ ] **C1-3** Jalur Android tetap memakai `SystemChrome` seperti sebelumnya
- [ ] **C1-4** Aplikasi jalan fullscreen, tanpa taskbar, tanpa border
- [ ] **C1-5** Seluruh rute `go_router` bisa dinavigasi tanpa kamera/printer
- [ ] **C1-6** Provisioning: pairing key tersimpan (DPAPI) dan device terhubung ke tenant
- [ ] **C1-7** Heartbeat sampai ke dashboard admin
- [ ] **C1-8** **Build Android masih hijau**

**Selesai bila:** aplikasi Windows jalan fullscreen dan sudah ter-pair ke backend.

---

## Cycle C2 — Jalur Cetak

- [ ] **C2-1** Refactor `PrinterService` jadi abstract + factory (conditional import)
- [ ] **C2-2** Pindahkan jalur PrintManager lama ke `printer_service_android.dart` tanpa mengubah perilakunya
- [ ] **C2-3** Implementasi `printer_service_windows.dart`
- [ ] **C2-4** Cetak dari Final Result Screen: 4R borderless, tanpa dialog
- [ ] **C2-5** Tekan cetak 2x cepat → tetap **satu** lembar (lock `_isPrintingBusy`)
- [ ] **C2-6** Selesaikan utang teknis: `copies` dan `orientation` benar-benar dibaca
- [ ] **C2-7** Margin & quality terpakai, bukan hanya tersimpan
- [ ] **C2-8** Baca status spooler: `ready` / `out_of_paper` / `low_ink` / `offline` / `error`
- [ ] **C2-9** Kirim status printer di payload `HeartbeatService`
- [ ] **C2-10** Cabut kabel printer → gagal terkendali, aplikasi tidak crash
- [ ] **C2-11** **Build Android masih hijau**

**Selesai bila:** WR-02 sampai WR-06 terpenuhi dan status kertas habis muncul di
dashboard ≤ 60 detik.

---

## Cycle C3 — Kamera Capture Card 🎯 BISA PRODUKSI

- [ ] **C3-1** Refactor `PhotoboothCaptureService` jadi abstract + factory
- [ ] **C3-2** Implementasi Windows dengan `camera_windows`
- [ ] **C3-3** Ganti `UvcPreview` di jalur Windows dengan `CameraPreview`, `UnifiedCameraPreview` tetap jadi pintu tunggal
- [ ] **C3-4** **Verifikasi capture card benar-benar bisa 1920x1080** — laporkan bila terkunci lebih rendah
- [ ] **C3-5** Toggle Mirror berfungsi
- [ ] **C3-6** Mode `hdmiOnly` berjalan penuh sebagai jalur mandiri
- [ ] **C3-7** Sesi lengkap: Welcome → cetak, tanpa error
- [ ] **C3-8** Cabut capture card saat sesi → gagal terkendali
- [ ] **C3-9** **Build Android masih hijau**

> 🎯 **Titik penting.** Setelah cycle ini, kiosk Windows sudah bisa dipakai
> jualan dengan foto 1080p. Semua cycle berikutnya adalah peningkatan, bukan
> syarat. Kalau C4 bermasalah, kamu tidak terdampar.

---

## Cycle C4 — Shutter Sony SDK ⛔ GERBANG

**Gerbang di awal — selesaikan sebelum menulis satu baris kode:**

- [ ] **C4-0a** Baca ketentuan lisensi Sony Camera Remote SDK untuk pemakaian **komersial**, laporkan temuan
- [ ] **C4-0b** Konfirmasi ZV-E10 ada di daftar model yang didukung SDK terbaru
- [ ] **C4-0c** Jalankan sample `RemoteCli` — shutter & transfer berfungsi di luar aplikasi kita

> ⛔ **Berhenti dan tunggu persetujuan setelah tiga langkah ini.**

Implementasi:

- [ ] **C4-1** Bangun helper `.exe` **proses terpisah** (bukan DLL in-process) — isolasi crash
- [ ] **C4-2** Protokol socket lokal: `connect` / `status` / `capture` / `disconnect`
- [ ] **C4-3** `sony_remote_sdk_service.dart` sebagai klien helper
- [ ] **C4-4** **Tunggu properti AF lock**, jangan salin delay hardcoded dari `SonyPtpCameraManager.kt`
- [ ] **C4-5** Pakai callback SDK untuk tahu foto siap — jangan polling
- [ ] **C4-6** SDK mengirim gambar langsung ke PC
- [ ] **C4-7** Capture menghasilkan file 6000x4000 di disk
- [ ] **C4-8** Uji AF di cahaya redup → foto tajam, bukan lembut
- [ ] **C4-9** **Cabut kabel kamera di tengah sesi → jatuh ke `hdmiOnly`, sesi tidak mati**
- [ ] **C4-10** Matikan paksa proses helper → perilaku sama seperti C4-9
- [ ] **C4-11** Degradasi terlaporkan lewat heartbeat (`capture_mode`)
- [ ] **C4-12** 50 jepretan berturut-turut tanpa kebocoran memori / hang
- [ ] **C4-13** **Build Android masih hijau**

---

## Cycle C5 — Settings & Diagnostik

- [ ] **C5-1** Buang dari jalur Windows: DIAGNOSA OTOMATIS, NETWORK DIAGNOSTIC, IPP DIRECT, AUTO-PRINT HELPER, USB DIAGNOSTIC, tombol izin overlay, tombol izin USB
- [ ] **C5-2** Tambah: pilih printer dari `listPrinters()`, status printer live, test page
- [ ] **C5-3** Tambah: status koneksi kamera + status helper PTP
- [ ] **C5-4** Satukan `printer_settings_modal.dart` dengan tab hidden settings (utang teknis lama)
- [ ] **C5-5** Tidak ada tombol mati tersisa di panel
- [ ] **C5-6** **Build Android masih hijau**

---

## Cycle C6 — Kalibrasi Layar Sentuh

- [ ] **C6-1** Kalibrasi `designSize` (`Size(1280, 800)` saat ini) untuk monitor sebenarnya
- [ ] **C6-2** Sesuaikan breakpoint di `responsive_helper.dart` (ditulis untuk tablet 7-12 inci)
- [ ] **C6-3** Tombol & teks terbaca dan nyaman ditekan sambil berdiri
- [ ] **C6-4** Tombol aksi utama di **sepertiga bawah layar**
- [ ] **C6-5** Bila portrait: ikat sentuh ke display yang benar (Control Panel → Tablet PC Settings → Setup) dan **dokumentasikan langkahnya**
- [ ] **C6-6** Titik sentuh tepat, tidak meleset 90 derajat

---

## Cycle C7 — Packaging & Penguncian Kiosk

- [ ] **C7-1** Skrip **Inno Setup** (bukan MSIX)
- [ ] **C7-2** Installer memasang: aplikasi → Program Files, VC++ Redistributable, driver Epson + default 4R borderless
- [ ] **C7-3** Installer mengatur autologin + autostart
- [ ] **C7-4** Matikan notifikasi Windows, atur active hours mencakup seluruh jam operasional
- [ ] **C7-5** Blokir `Alt+F4`, tombol Windows, `Ctrl+Shift+Esc`
- [ ] **C7-6** Tambah field `app_version` di heartbeat + alur unduh installer
- [ ] **C7-7** Uji di mesin Windows bersih: dari nol sampai siap jual **≤ 30 menit**
- [ ] **C7-8** Waktu boot ≤ 90 detik dari listrik menyala
- [ ] **C7-9** Tulis `docs/deployment-windows.md` — checklist instalasi unit baru

---

## Cycle C8 — Soak Test 7 Hari

Uji injeksi kegagalan dulu (rinci di [Rencana Uji](04-test-acceptance.md) §3):

- [ ] **C8-1** F-1 sampai F-9 semua lulus
- [ ] **C8-2** Hari 1-7 berjalan tanpa intervensi manual
- [ ] **C8-3** Catat harian: sesi selesai, kegagalan cetak, degradasi mode, crash
- [ ] **C8-4** Windows Update tidak me-reboot di jam operasional
- [ ] **C8-5** Idle 24 jam: tidak sleep, tidak screensaver, kamera masih hidup

> Cycle ini **tidak bisa dipercepat**, termasuk dengan bantuan AI. Masalah kiosk
> Windows baru muncul setelah berhari-hari berjalan.

**Go-live bila:** 7 hari nol intervensi manual dan seluruh uji injeksi lulus.

---

## Catatan Harian

Tambahkan baris di bawah setiap hari kerja. Format bebas, yang penting tanggal
dan apa yang menghambat.

| Tanggal | Cycle | Yang dikerjakan | Hambatan |
|---|---|---|---|
| | | | |

---

## Aturan yang Berlaku di Semua Cycle

1. **Build Android harus tetap hijau** di akhir setiap cycle (NFR-05)
2. Satu codebase, **tanpa fork**
3. Jangan sentuh `laravel_backend/`, `laravel_api/`, `admin_dashboard/`
4. Semua kode platform lewat facade `PhotoboothCaptureService` dan `PrinterService`
5. Jangan hapus kode Android / stack IPP sampai ada keputusan pensiun tablet
6. Kalau muncul ide "sekalian saja", cek dulu ke [PRD §3 dan §4](00-prd.md)
