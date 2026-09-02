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
| **C1** | Kerangka Windows | 2-3 hari | ✅ | 2026-09-01 | 2026-09-02 |
| **C2** | Jalur cetak | 3-4 hari | ✅ | 2026-09-02 | 2026-09-02 |
| **C3** | Kamera capture card 🎯 **BISA PRODUKSI** | 3-4 hari | ✅ | 2026-09-02 | 2026-09-02 |
| **C4** | Shutter Sony ✅ **GERBANG LULUS** | 1-2 minggu | 🟨 | 2026-09-02 | POC PASS |
| **C5** | Settings & diagnostik | 3-4 hari | ✅ | 2026-09-02 | 2026-09-02 |
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
- [ ] **C0-7** ⚠️ Atur Paper Size + Borderless + Expansion di **Printing Preferences** driver — `format:` di `directPrintPdf` TIDAK mengatur ukuran kertas, driver memakai DEVMODE default (sering A4)
- [ ] **C0-8** Verifikasi print queue menunjukkan ukuran yang benar, bukan A4
- [ ] **C0-9** Catat kombinasi yang menang: ukuran kertas + bleed per sisi + setelan Expansion
- [x] **C0-11** ⛔ TERBUKTI: kertas 2x6 sungguhan mustahil di L8050 — User-Defined Paper Size mentok di lebar minimum **89 mm** (2 inci = 50,8 mm). Strip WAJIB dicetak 2-up di 4R lalu dipotong. Konsekuensi baik: ukuran kertas tidak pernah berubah antar job, jadi kontrol DEVMODE per job kemungkinan tidak diperlukan
- [ ] **C0-10** Putuskan pustaka untuk C2: `printing` cukup bila kiosk hanya satu ukuran; butuh `printing_ffi`/`windows_printer` bila harus berpindah antara 4R dan strip 2x6 per job (kontrol DEVMODE)

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
- [x] **C1-2** Tambah `window_manager`, ganti `SystemChrome.setEnabledSystemUIMode` di `main.dart` (fungsi itu tidak berefek di Windows)
- [x] **C1-3** Jalur Android tetap memakai `SystemChrome` seperti sebelumnya
- [x] **C1-4** Aplikasi jalan fullscreen, tanpa taskbar, tanpa border
- [x] **C1-5** Seluruh rute `go_router` bisa dinavigasi tanpa kamera/printer
- [x] **C1-6** Provisioning: pairing key tersimpan (DPAPI) dan device terhubung ke tenant
- [x] **C1-7** Heartbeat sampai ke dashboard admin
- [x] **C1-8** **Build Android masih hijau** — `flutter build apk --debug` sukses. Muncul peringatan KGP (bukan error): `camera_android_camerax` dan `flutter_uvc_camera` masih memakai Kotlin Gradle Plugin, dan versi Flutter mendatang akan menolaknya

**Selesai bila:** aplikasi Windows jalan fullscreen dan sudah ter-pair ke backend.

### 🎯 Temuan C1

1. Paket `camera` TIDAK meng-endorse Windows — `camera_windows` wajib eksplisit.
2. MSVC VS18 menolak `<experimental/coroutine>` di `permission_handler_windows`
   — ditambal `add_definitions(-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)`.
3. Mengubah `BINARY_NAME` WAJIB diikuti pembuangan cache CMake di `build/`,
   kalau tidak muncul `No target "<nama lama>"`.
4. Fullscreen sebaiknya hanya di build release; saat debug jendela normal.
5. `app_version` SUDAH dikirim di payload heartbeat — separuh pondasi update
   jarak jauh (WR-15) ternyata sudah ada.
6. `apiBaseUrlDev` dan `apiBaseUrlProd` dua-duanya menunjuk domain produksi;
   lokal hanya lewat `--dart-define=API_BASE_URL=...`.

> 📌 Detail: paket `camera` TIDAK meng-endorse Windows. `camera_windows`
> harus ditambahkan eksplisit ke pubspec, kalau tidak `availableCameras()`
> mengembalikan kosong. Terlihat dari `generated_plugins.cmake` yang semula
> hanya memuat 4 plugin.

---

## Cycle C2 — Jalur Cetak

- [~] **C2-1** ~~Abstract + factory~~ → **diturunkan jadi percabangan `Platform.isWindows` di dalam `printer_service.dart`**. Alasan: 1.315 baris itu 80% konfigurasi & storage yang dipakai kedua platform; memecahnya jadi dua file berarti menduplikasi semuanya. Yang dipisah cukup lapisan eksekusi: `printing/windows_printer_backend.dart`
- [~] **C2-2** Tidak dipindah — jalur Android dibiarkan di tempatnya, TIDAK DISENTUH sama sekali. Risiko lebih rendah daripada memindahkan 500+ baris yang sudah terbukti jalan
- [x] **C2-3** `printing/windows_printer_backend.dart` (390 baris)
- [x] **C2-4** Cetak 4R borderless tanpa dialog — kunci: `usePrinterSettings: true` supaya DEVMODE driver dipakai
- [x] **C2-5** Lock `_isPrintingBusy` tetap berlaku di jalur Windows
- [x] **C2-6** `copies` dan `orientation` akhirnya dibaca jalur cetak
- [~] **C2-7** TIDAK BERLAKU di Windows: margin diurus driver lewat borderless, quality diatur di Printing Defaults. Setelan margin/quality di aplikasi sengaja diabaikan supaya tidak bertabrakan dengan driver
- [x] **C2-8** Status spooler dibaca lewat WMI `Win32_Printer` (PowerShell CIM), dipetakan ke enum `PrinterHealth` — 13 kondisi termasuk `out_of_paper`, `no_ink`, `paper_jam`
- [x] **C2-9** `HeartbeatService` mengirim kode status rinci, bukan lagi ready/offline
- [x] **C2-10** Cabut kabel printer → gagal terkendali
- [x] **C2-11** **Build Android masih hijau**

> ✅ **C2 SELESAI 2026-09-02.** Dua dari empat tujuan PRD tercapai:
> G-1 silent print sejati, dan G-2 status printer terbaca.
>
> Keputusan teknis: status dibaca lewat **PowerShell CIM**, bukan FFI atau
> package pembungkus. Dibaca sekali per 60 detik sehingga biaya ~300ms tidak
> terasa, dan tidak ada struct FFI yang bisa salah ukuran. Pindah ke Win32 FFI
> hanya bila kelak perlu dibaca berkali-kali per detik.
>
> Perubahan perilaku: `isPrinterReachable()` di Windows kini berarti "masih
> layak menerima job". Printer yang kertasnya habis dianggap TIDAK terjangkau,
> supaya kiosk berhenti menerima pesanan sebelum pelanggan membayar.

**Selesai bila:** WR-02 sampai WR-06 terpenuhi dan status kertas habis muncul di
dashboard ≤ 60 detik.

---

## Cycle C3 — Kamera Capture Card 🎯 BISA PRODUKSI

- [~] **C3-1** Percabangan `Platform.isWindows` di `detectMode()`, konsisten dengan keputusan C2-1
- [x] **C3-2** `CaptureMode.windowsCamera` + `camera_windows`
- [x] **C3-3** Jalur Windows memakai `CameraPreview`; `UnifiedCameraPreview` tetap pintu tunggal
- [x] **C3-4** Capture card MacroSilicon MS2109 (`vid_534D&pid_2109`) terdeteksi dan dipilih otomatis oleh `CameraService`
- [x] **C3-5** Toggle Mirror berfungsi
- [x] **C3-6** Mode `windowsCamera` berjalan penuh sebagai jalur mandiri
- [x] **C3-7** Sesi lengkap: Welcome → cetak, tanpa error
- [x] **C3-8** Cabut capture card saat sesi → gagal terkendali
- [x] **C3-9** **Build Android masih hijau**

> ✅ **TERCAPAI 2026-09-02. Kiosk Windows sudah bisa dipakai jualan** dengan
> foto 1080p dari capture card.
>
> Temuan C3: hampir tidak ada yang perlu dibangun. `camera_windows` melihat
> capture card sebagai webcam biasa, dan `CameraService.getBestCamera()` sudah
> punya logika memilih kamera eksternal. Fork `flutter_uvc_camera` beserta
> workaround generasi view-nya tidak tersentuh sama sekali di Windows.
>
> Tambahan di luar rencana: **kompensasi bleed**. Elemen frame dekat tepi
> terpotong oleh expansion driver. Setelan margin di panel settings kini
> menyusutkan bidang gambar, sehingga yang dimakan expansion adalah penyangga
> — bukan frame rancangan admin. Berlaku sama di halaman uji maupun cetak foto.
>
> 🎯 **Titik penting.** Semua cycle berikutnya adalah peningkatan, bukan
> syarat. Kalau C4 bermasalah, kamu tidak terdampar.

---

## Cycle C4 — Shutter Sony SDK ⛔ GERBANG

**Gerbang di awal — selesaikan sebelum menulis satu baris kode:**

- [ ] **C4-0a** Baca ketentuan lisensi Sony Camera Remote SDK untuk pemakaian **komersial**, laporkan temuan
- [ ] **C4-0b** Konfirmasi ZV-E10 ada di daftar model yang didukung SDK terbaru
- [ ] **C4-0c** Jalankan sample `RemoteCli` — shutter & transfer berfungsi di luar aplikasi kita

> ⛔ **GERBANG GAGAL — 2026-09-02.**
>
> **Sony ZV-E10 generasi pertama TIDAK ADA di daftar model yang didukung
> Camera Remote SDK.** Daftar resmi versi 2.02.00 memuat `ZV-E1` dan
> `ZV-E10M2`, tanpa `ZV-E10`.
>
> Daftar lengkap saat pemeriksaan: ILX-LR1, ILCE-1M2, ILCE-1, ILCE-9M3,
> ILCE-9M2, ILCE-7RM6, ILCE-7RM5, ILCE-7RM4A, ILCE-7RM4, ILCE-7CR, ILCE-7SM3,
> ILCE-7M5, ILCE-7M4, ILCE-7CM2, ILCE-7C, ILCE-6700, BURANO, ILME-FX6V/FX6T,
> ILME-FX3A, ILME-FX3, ILME-FX2, ILME-FX30, PXW-Z300, PXW-Z380, PXW-Z200,
> HXR-NX800, BRC-AM7, ILME-FR7, ZV-E1, ZV-E10M2, DSC-RX1RM3, DSC-RX0M2.
>
> **Lisensi bukan penghalang:** pemakaian komersial diizinkan tanpa royalti.
> Kewajibannya: memberi tahu pengguna bahwa kamera kehilangan garansi pabrik
> saat dikendalikan aplikasi, tidak menyiratkan Sony pembuat aplikasi, dan
> menanggung dukungan pelanggan sendiri.
>
> ✅ **GERBANG LULUS 2026-09-02 — lewat jalan yang berbeda.**
>
> Kesimpulan "ZV-E10 tidak didukung" ternyata **hanya berlaku untuk Camera
> Remote SDK**. Produk yang berbeda, **Camera Remote Command**, mendukung
> ZV-E10 generasi pertama pada PTP 2 maupun PTP 3.
>
> POC lengkap P1-P8 **PASS** dengan eksekusi nyata. Hasil akhir **6000 x 4000
> (24,0 MP)** — melampaui baseline Imaging Edge yang 21,3 MP, karena batas itu
> ternyata cuma setelan Aspect Ratio 4:3 di kamera.
>
> Rincian: [08 — POC Camera Remote Command](08-camera-remote-command-poc.md)
>
> **Tidak perlu ganti kamera. Tidak perlu reverse engineering. Tidak perlu
> Zadig.** Opsi 2 dan 3 di bawah gugur — yang berlaku sekarang adalah jalur
> keempat yang belum terbayang saat daftar itu ditulis.
>
> Sisa pekerjaan C4: menulis helper produksi sendiri berdasarkan Command
> Reference (contoh Sony dilarang dipakai di produk), lalu menyambungkannya ke
> Flutter lewat socket lokal dengan degradasi ke `windowsCamera`.
>
> **Tiga jalan keluar, semuanya keputusan bisnis bukan teknis:**
>
> 1. **Tetap 1080p** — kiosk sudah jalan penuh sejak C3. Biaya nol,
>    C4 dibatalkan. Foto ~2 MP, dan untuk cetak 4R di 333 DPI itu sebenarnya
>    sudah memadai (lihat catatan kualitas cetak di PRD).
> 2. **Ganti kamera ke ZV-E10 II** — SDK resmi langsung berlaku, C4 berjalan
>    sesuai rencana. Biaya sebesar satu badan kamera.
> 3. **Port PTP hasil rekayasa balik ke Windows** — opcode `0xD2C1`/`0xD2C2`
>    sudah TERBUKTI bekerja dengan kamera ini di Android. Di Windows perlu
>    libusb/WinUSB (driver kamera diganti lewat Zadig, jadi kamera tidak lagi
>    dikenali sebagai perangkat MTP biasa di mesin itu — untuk kiosk masih
>    dapat diterima). Konsekuensi: tujuan G-3 "shutter di atas API resmi"
>    GUGUR, dan kerapuhan terhadap update firmware tetap ada.

Implementasi:

- [x] **C4-1** Helper `.exe` **proses terpisah** — `tools/sony_camera_helper/`. Win32 + WIA murni, tanpa MFC/ATL, jadi tidak terkena jebakan toolset v141 yang mengunci program contoh Sony. Semua panggilan COM terisolasi di satu thread STA dengan pompa pesan; thread socket punya batas waktu sendiri, sehingga lapisan kamera yang macet menjawab `busy`/`timeout` alih-alih menggantung
- [x] **C4-2** Protokol socket loopback baris-JSON: `connect` / `status` / `capture` / `disconnect`, plus `ping` / `list` / `shutdown`. Tabel kode error ada di README helper
- [ ] **C4-3** Klien Dart + integrasi `PhotoboothCaptureService` — **ditahan sampai C4-B lulus** (pola buktikan-dulu-baru-integrasi). Catatan: nama `sony_remote_sdk_service.dart` dibatalkan, karena yang dipakai Camera Remote **Command**, bukan SDK
- [x] **C4-4** **Menunggu Focus Indication (0xD213)** bernilai `0x02`/`0x06`. Tidak ada delay tebakan di jalur AF, dan tidak ada satu pun angka yang disalin dari `SonyPtpCameraManager.kt`. Satu-satunya `Sleep` adalah durasi tahan tombol rana (`--s2-hold`) dan jeda antar pembacaan status
- [x] **C4-5** Foto siap dideteksi lewat **Shooting File Info (0xD215)** bit `0x8000`. Ini pembacaan berkala, dan itu memang **mekanisme resmi**: Reference bagian Overview menyatakan Initiator sebaiknya *tidak* memakai PTP vendor event (model lama tidak menjamin semua event terkirim) dan harus membaca properti Responder secara berkala lewat `SDIO_GetAllExtDevicePropInfo`. Transport WIA `Escape` juga tidak punya kanal event sama sekali
- [x] **C4-6** Gambar ditarik langsung ke PC lewat `GetObjectInfo`/`GetObject` pada handle `0xFFFFC001`, divalidasi SOI/EOI, lalu ditulis atomik (`.part` → `MoveFileEx`)
- [ ] **C4-7** Capture menghasilkan file 6000x4000 di disk — perlu uji hardware
- [ ] **C4-8** Uji AF di cahaya redup → foto tajam, bukan lembut
- [ ] **C4-9** **Cabut kabel kamera di tengah sesi → jatuh ke `windowsCamera`, sesi tidak mati**
- [ ] **C4-10** Matikan paksa proses helper → perilaku sama seperti C4-9
- [ ] **C4-11** Degradasi terlaporkan lewat heartbeat (`capture_mode`)
- [ ] **C4-12** 50 jepretan berturut-turut tanpa kebocoran memori / hang
- [ ] **C4-13** **Build Android masih hijau**

### C4-B — Uji helper berdiri sendiri (sebelum menyentuh Flutter)

Dijalankan dari mesin Windows, kamera di `USB Connection = PC Remote`:

- [x] **C4-B1** `build.bat` lulus sekali jalan, MSVC 14.51 (v145). Tanpa MFC, tanpa retarget, tanpa sentuh Visual Studio
- [x] **C4-B2** `--list` menampilkan `ZV-E10` beserta device id WIA
- [x] **C4-B3** `--selftest` PASS **dua kali berturut-turut tanpa cabut-colok**. `6000x4000` (24,0 MP), `object_format 0x3801` Exif/JPEG, `stale_discarded 0`, `extra_discarded 0`. AF ~780 ms, transfer ~795 ms, **total ~2,26 s per jepretan**
- [ ] **C4-B4** File hasil dibuka: utuh, dimensi sesuai setelan Aspect Ratio kamera
- [ ] **C4-B5** Mode server via `scripts\test-server.ps1`: tiga capture berurutan lewat satu sambungan
- [ ] **C4-B6** Uji gagal fokus: tutup lensa → `af_timeout`/`af_failed`, **bukan** foto buram yang dilaporkan sukses
- [ ] **C4-B7** Cabut USB saat `--serve` jalan → `status` melaporkan `connected:false`, helper tidak crash

Dua bug ditemukan uji hardware dan sudah diperbaiki — keduanya tidak akan
terlihat tanpa kamera nyata:

1. **Buffer transfer tidak dikosongkan.** Sisa berkas terbawa ke capture
   berikutnya; pelanggan menerima foto yang meleset satu jepretan.
2. **`CloseSession` saat disconnect.** Sesi PTP milik driver WIA/WPD, bukan
   milik kita. Menutupnya membuat sambungan berikutnya gagal
   `Session_Not_Open (0x2003)` sampai kamera dicabut-colok — persis pola
   kegagalan yang mematikan untuk kiosk yang hidup seharian.

---

## Cycle C5 — Settings & Diagnostik

- [x] **C5-1** Empat panel diagnostik Android disembunyikan lewat `Platform.isAndroid` — kodenya tidak dihapus supaya build Android tetap utuh
- [x] **C5-2** Panel PRINTER WINDOWS: lampu status WMI, dropdown pilih printer, tombol periksa ulang, pengingat Printing Defaults
- [x] **C5-3** Kartu Sony PTP dan kartu UVC disembunyikan di Windows — keduanya Android-only, tombolnya akan mati. Kamera Windows tampil di daftar kamera biasa
- [~] **C5-4** Tidak digabung penuh. Kolom IP di modal disembunyikan di Windows dan diarahkan ke Hidden Settings > Printer. Penggabungan penuh ditunda: modal itu dipakai layar hasil yang dilihat pelanggan, risikonya tidak sepadan sekarang
- [x] **C5-5** Tidak ada tombol mati tersisa di jalur Windows
- [x] **C5-6** **Build Android masih hijau** — sempat GAGAL dan itu berguna: `camera_settings_tab.dart` meng-import `dart:io` dengan prefix (`as dart_io`), sehingga `Platform` telanjang tidak dikenali. Error compile-time yang tidak pernah muncul di Windows karena file itu belum dikompilasi ulang di sana. Bukti konkret kenapa build Android diperiksa tiap akhir cycle

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
