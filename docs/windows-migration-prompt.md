# PROMPT: Migrasi Kiosk Photobooth dari Android ke Windows

> Salin seluruh isi file ini sebagai prompt awal ke AI agent, atau cukup arahkan
> agent ke path file ini. Ditulis 2026-09-01.

---

## PERAN

Kamu adalah engineer yang mengerjakan migrasi aplikasi kiosk photobooth
**SnapTechBooth** dari Android ke Windows desktop. Repo ada di `E:\Photobooth`.
Aplikasi Flutter ada di `flutter_app/`.

Kerjakan **bertahap dan berhenti di setiap GERBANG**. Jangan mengerjakan seluruh
fase sekaligus.

---

## TUJUAN

Pindahkan aplikasi kiosk **sisi pelanggan saja** dari Android ke Windows, dengan
empat sasaran bernama:

1. **Silent print** — cetak tanpa dialog, tanpa Accessibility, tanpa overlay.
2. **Status printer terbaca** — kertas habis / tinta habis / offline bisa
   dideteksi dan dilaporkan, bukan gagal senyap.
3. **Shutter di atas API resmi** — ganti opcode vendor hasil rekayasa balik
   dengan Sony Camera Remote SDK.
4. **Setup per unit yang bisa diulang** — installer + pairing key, tanpa ritual
   manual per perangkat.

Kalau sebuah perubahan tidak melayani salah satu dari empat sasaran ini,
**jangan dikerjakan** — tanyakan dulu.

---

## KENAPA PINDAH (biar kamu paham prioritasnya)

Di Android, **ketiga** jalur hardware aplikasi ini berjalan di atas workaround,
bukan jalur resmi:

| Jalur | Kondisi sekarang |
|---|---|
| Cetak | `PrintManager.print()` **selalu** membuka spooler UI by design. Ditambal `KioskAutoPrintService` (Accessibility) yang menekan tombol Print, ditutupi overlay `TYPE_APPLICATION_OVERLAY`. Android bisa mematikan Accessibility Service setelah reboot/update. |
| Shutter | `SonyPtpCameraManager.kt` menulis properti vendor Sony `0xD2C1`/`0xD2C2` hasil rekayasa balik dari libgphoto2, dengan **1,1 detik delay hardcoded** — termasuk `delay(500)` yang hanya MENEBAK bahwa AF sudah lock. |
| Preview | Butuh fork `flutter_uvc_camera` yang dipatch sendiri (`packages/`) plus workaround `_viewGeneration` untuk bug single-view factory. |

Aplikasi ini juga dibangun untuk **armada**, bukan satu mesin: ada
`DEVICE PAIRING KEY`, `ProvisioningService`, dan heartbeat telemetri tiap 60
detik ke dashboard admin. Ritual setup manual per unit di Android tidak akan
menskala.

---

## ATURAN KERAS — LANGGAR INI BERARTI GAGAL

1. **SATU codebase. JANGAN fork.** Build Android harus **tetap bisa di-build dan
   berjalan** sampai fase terakhir. Tablet Legion Y700 adalah jaring pengaman.
2. **JANGAN sentuh** `laravel_backend/`, `laravel_api/`, `admin_dashboard/`.
   Backend sudah bicara lewat HTTP dan tidak ikut pindah.
3. **JANGAN ubah template render backend atau DPI cetak.** Itu perubahan
   terpisah, di luar scope prompt ini.
4. **JANGAN ubah alur atau desain UI pelanggan** di `lib/features/`. Satu-satunya
   pengecualian adalah kalibrasi ukuran di Fase 6.
5. **Semua kode platform wajib lewat dua facade yang sudah ada:**
   `PhotoboothCaptureService` dan `PrinterService`. Jangan bikin jalur baru yang
   memotong keduanya. Kedua kelas ini sudah berada tepat di titik sambung
   platform — itu sebabnya migrasi ini murah.
6. Pilih implementasi lewat **abstract class + conditional import**, bukan
   `Platform.isWindows` yang bertebaran di mana-mana.
7. **JANGAN pernah** mengirim byte mentah (JPEG/PDF) ke port 9100 atau ke USB
   bulk endpoint. Sudah dicoba, hasilnya karakter acak di kertas foto.
8. **Komentar kode dalam Bahasa Indonesia**, mengikuti gaya yang sudah ada di
   repo.
9. **Setiap fase harus bisa di-build dan dijalankan.** Jangan tinggalkan repo
   dalam keadaan rusak di antara fase.
10. **Berhenti dan lapor di setiap GERBANG.** Jangan lanjut tanpa persetujuan.

---

## BACA DULU SEBELUM MENULIS KODE APA PUN

- `docs/hardware/01-camera.md`, `02-printer.md`, `03-camera-wiring-hybrid.md`
- `flutter_app/lib/core/services/printer_service.dart` (1.315 baris)
- `flutter_app/lib/core/services/photobooth_capture_service.dart`
- `flutter_app/lib/core/services/uvc_camera_service.dart`
- `flutter_app/lib/core/services/sony_ptp_camera_service.dart`
- `flutter_app/android/app/src/main/kotlin/.../SonyPtpCameraManager.kt`
- `flutter_app/lib/features/result/presentation/final_result_screen.dart`
  (lihat `_executePrint`)
- `flutter_app/lib/main.dart`

---

## FAKTA YANG SUDAH TERBUKTI — JANGAN DITELITI ULANG

Ini sudah dibuktikan dengan percobaan langsung. Mengulanginya membuang waktu.

- Printer **Epson L8050** (`04B8:1331`) **tidak punya IPP** maupun
  **IPP-over-USB**. Web Config-nya tidak memuat IPP — hanya Bonjour, SLP, WSD,
  LLTD, LLMNR, LPR, RAW (Port 9100), SNMP.
- L8050 hanya menerima raw dan isinya wajib **ESC/P-R**. Di Windows, **driver
  Epson resmi yang mengerjakan rasterisasi ini** — itulah inti kenapa migrasi ini
  menyelesaikan masalah.
- Stack IPP di `lib/core/services/ipp/` (1.226 baris) **tidak terpakai** untuk
  L8050. **Jangan dihapus** — simpan untuk printer ber-AirPrint di masa depan.
- Foto yang dicetak **bukan file kamera**, melainkan hasil render backend
  (`final_url`) yang diunduh ulang di `_executePrint`.
- Foto diperkecil ke sisi terpanjang **2000 px** (`_kMaxUploadSide`) sebelum
  diunggah, dan kanvas template backend adalah **1333x2000**. Jadi kualitas cetak
  **tidak** terpengaruh oleh ukuran foto kamera. Jangan mengoptimasi ke arah itu.
- ZV-E10 adalah **USB 2.0**. Jangan menjanjikan peningkatan kecepatan transfer di
  luar batas itu.
- `USB Connection Mode` di ZV-E10 bersifat **eksklusif**: PC Remote **ATAU** USB
  Streaming, tidak bisa dua-duanya. USB Streaming mematikan output HDMI.

---

## FASE 0 — SPIKE CETAK  ⛔ GERBANG

**Ini gerbang pertama dan paling penting. Jangan mulai fase lain sebelum ini
lulus.**

Buat proyek Flutter Windows **kosong dan terpisah** (di luar repo, misalnya di
`C:\spike_print`). Bukan di dalam `flutter_app/`.

Tugasnya cuma satu: buktikan bahwa Epson L8050 bisa dicetak **tanpa dialog**
dari Flutter Windows.

1. Install driver Epson L8050 resmi di mini PC.
2. `Printing.listPrinters()` — pastikan L8050 terdeteksi.
3. `Printing.directPrintPdf()` dengan gambar uji ke ukuran 4R (102x152 mm).
4. Pastikan **borderless** benar-benar keluar tanpa border putih.
5. Coba juga jalur `printing_ffi` atau `windows_printer` untuk membaca **status
   printer** (kertas habis, offline) — laporkan mana yang berhasil.

**Kriteria lulus:** kertas foto 4R keluar penuh tanpa border, tanpa satu pun
dialog muncul di layar, dan status printer bisa dibaca secara programatik.

**BERHENTI DI SINI.** Laporkan hasilnya, sertakan foto/scan hasil cetak kalau
bisa, dan tunggu persetujuan sebelum lanjut. Kalau borderless bermasalah,
laporkan apa adanya — jangan mencari akal-akalan.

---

## FASE 1 — KERANGKA WINDOWS

Folder `flutter_app/windows/` sudah ter-generate dan plugin Windows sudah
terdaftar (`printing`, `connectivity_plus`, `flutter_secure_storage_windows`,
`permission_handler_windows`).

1. Pastikan `flutter build windows` berhasil apa adanya.
2. Ganti `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` di
   `main.dart` — **fungsi ini tidak melakukan apa-apa di Windows.** Pakai package
   `window_manager` untuk fullscreen. Jaga agar jalur Android tetap memakai
   `SystemChrome` seperti sebelumnya.
3. Pastikan aplikasi bisa jalan dan seluruh navigasi `go_router` berfungsi,
   walaupun kamera dan printer belum tersambung.
4. Pastikan `flutter_secure_storage` (DPAPI di Windows) menyimpan dan membaca
   pairing key dengan benar — layar provisioning harus bisa dipakai.

**Selesai bila:** aplikasi jalan fullscreen di Windows, provisioning bisa
di-pair ke backend, heartbeat terkirim.

---

## FASE 2 — JALUR CETAK

Refactor `PrinterService` menjadi abstract + dua implementasi.

**Wajib dipenuhi implementasi Windows:**

- Cetak **tanpa dialog sama sekali**.
- 4R borderless, sesuai setelan yang tersimpan (`paperSize`, `borderless`,
  `quality`, margin).
- **Garansi 1 aksi = 1 PrintJob = 1 lembar.** Pertahankan lock `_isPrintingBusy`.
  Ini melindungi kertas foto pelanggan — jangan dilonggarkan.
- `isPrinterReachable()` harus benar-benar menanyakan spooler, bukan menebak.
- **Baru:** ekspos status printer (siap / kertas habis / tinta habis / offline /
  error) supaya `HeartbeatService` bisa mengirimnya ke dashboard.

**Yang boleh dibuang di jalur Windows:** seluruh percabangan IPP, mode Silent
Ketat, kontrol penutup dialog, `bindProcessToWifi`, dan diagnostik USB. Semuanya
tidak punya arti di Windows.

**Yang JANGAN dihapus dari repo:** file di `lib/core/services/ipp/` dan file
Kotlin — jalur Android masih harus hidup.

Sekalian selesaikan utang teknis yang tercatat: `copies` dan `orientation` selama
ini hanya disimpan tapi tidak pernah dibaca jalur cetak. Di Windows, baca dan
pakai.

**Selesai bila:** menekan Cetak di `final_result_screen` menghasilkan satu lembar
4R borderless, tanpa dialog, dan status printer muncul di payload heartbeat.

---

## FASE 3 — KAMERA VIA CAPTURE CARD

Di Windows, HDMI capture card adalah **webcam UVC biasa** lewat MediaFoundation.
Tidak perlu plugin vendor.

1. Implementasi Windows untuk `PhotoboothCaptureService` memakai `camera_windows`
   (paket `camera` yang sudah ada di pubspec).
2. Ganti `UvcPreview` di jalur Windows dengan `CameraPreview` biasa. Pertahankan
   `UnifiedCameraPreview` sebagai titik masuk tunggal.
3. **Verifikasi resolusi**: pastikan capture card benar-benar bisa dipaksa
   1920x1080. Laporkan kalau ternyata terkunci lebih rendah.
4. Mode `hdmiOnly` harus berfungsi penuh sebagai jalur mandiri — ini akan jadi
   fallback saat PTP bermasalah di Fase 4.

**Selesai bila:** preview 1080p mulus di monitor kiosk, sesi photobooth bisa
diselesaikan dari awal sampai cetak memakai mode `hdmiOnly`.

**Pada titik ini kiosk Windows sudah bisa dipakai produksi**, dengan kualitas
foto 1080p. Fase 4 menaikkannya ke 24 MP.

---

## FASE 4 — SHUTTER SONY VIA CAMERA REMOTE SDK  ⛔ GERBANG

**Sebelum menulis satu baris kode pun, lakukan ini dan laporkan:**

1. Baca **ketentuan lisensi** Sony Camera Remote SDK untuk penggunaan
   **komersial**. Aplikasi ini produk komersial multi-tenant. Laporkan temuan.
2. Pastikan **ZV-E10 masih ada di daftar model yang didukung** versi SDK terbaru.
   Sony kadang memindahkan model lama ke SDK versi lawas.
3. Jalankan aplikasi contoh `RemoteCli` bawaan SDK. Konfirmasi shutter dan
   transfer gambar berfungsi di luar aplikasi kita dulu.

**BERHENTI dan tunggu persetujuan setelah tiga langkah ini.**

Setelah disetujui:

**Arsitektur wajib: helper `.exe` terpisah**, bukan DLL yang di-load in-process.
Helper bicara dengan Flutter lewat socket lokal atau stdin/stdout. Alasannya:
kalau SDK Sony crash atau hang, aplikasi kiosk tidak ikut mati — dan berdasarkan
pengalaman jalur Android, itu akan terjadi.

**Wajib dipenuhi:**

- **Tunggu properti AF benar-benar lock, jangan `delay()` menebak.** Ini
  perbaikan utama dibanding jalur Android: foto lebih tajam DAN lebih cepat.
- Pakai **callback SDK** untuk tahu foto siap. Jangan polling endpoint mentah.
- Suruh SDK mengirim gambar **langsung ke PC**. Tidak perlu `GetObjectHandles` →
  cari handle → `GetObject`.
- **Degradasi anggun**: kalau PTP gagal atau putus saat runtime, jatuh otomatis
  ke mode `hdmiOnly`. **Sesi pelanggan tidak boleh mati.** Laporkan lewat
  heartbeat, jangan hanya di log.
- **Jangan** menyalin delay hardcoded dari `SonyPtpCameraManager.kt`. Itu tebakan
  empiris untuk jalur yang berbeda.

**Selesai bila:** shutter dipicu, foto 6000x4000 sampai ke disk, dan mencabut
kabel kamera di tengah sesi membuat sistem jatuh ke `hdmiOnly` tanpa crash.

---

## FASE 5 — SETTINGS & DIAGNOSTIK

`printer_settings_tab.dart` (2.063 baris) dan `camera_settings_tab.dart`
(951 baris) sebagian besar berisi panel diagnostik khusus Android.

- **Buang di jalur Windows:** DIAGNOSA OTOMATIS berbasis Android, NETWORK
  DIAGNOSTIC, IPP DIRECT, AUTO-PRINT HELPER, USB DIAGNOSTIC, tombol izin overlay,
  tombol izin USB (yang memang hardcoded `false`).
- **Ganti dengan yang relevan:** pilih printer dari `listPrinters()`, status
  printer live, test page, status koneksi kamera, status helper PTP.
- Rapikan duplikasi yang tercatat sebagai utang teknis:
  `shared/widgets/printer_settings_modal.dart` terpisah dari tab hidden settings.
  Satukan.

---

## FASE 6 — KALIBRASI LAYAR

`main.dart` memakai `designSize: Size(1280, 800)` (16:10, ukuran tablet) dan
breakpoint di `responsive_helper.dart` ditulis untuk "tablet 7-12 inci".

Di monitor sentuh besar semuanya jatuh ke kategori `large` yang belum pernah
diuji. ScreenUtil menskala **proporsional**, jadi tidak ada yang rusak — tapi
tombol yang pas di 8,8 inci jadi raksasa di 24 inci.

- Kalibrasi `designSize` dan breakpoint untuk target monitor sebenarnya.
- Ergonomi: taruh tombol aksi utama di **sepertiga bawah layar** — di monitor
  portrait besar, bagian atas di luar jangkauan nyaman.
- Kalau dipasang portrait: dokumentasikan bahwa **rotasi tampilan dan rotasi
  sumbu sentuh adalah dua setelan terpisah** (Control Panel → Tablet PC Settings
  → Setup). Salah satu tidak ikut berputar = sentuhan meleset 90 derajat.

---

## FASE 7 — PACKAGING & PENGUNCIAN KIOSK

Pakai **Inno Setup**, bukan MSIX (MSIX ter-sandbox dan menyulitkan autostart
serta akses printer).

Installer harus mengerjakan:

1. Copy aplikasi ke `Program Files`
2. Install **Visual C++ Redistributable** (wajib untuk Flutter Windows)
3. Install driver Epson L8050 + set default 4R borderless
4. Daftarkan autostart + autologin
5. Matikan notifikasi Windows, atur active hours untuk menunda update

Penguncian kiosk: `window_manager` fullscreen + blokir `Alt+F4` dan tombol
Windows. Butuh Windows 11 **Pro** (Shell Launcher + Group Policy).

Mekanisme update: `HeartbeatService` sudah mengirim telemetri tiap 60 detik.
Tambahkan field versi di payload; backend membalas versi terbaru + URL installer;
aplikasi mengunduh dan memasang saat idle.

Tulis hasilnya sebagai `docs/deployment-windows.md` berisi checklist instalasi
unit baru dari nol.

---

## PEMBERSIHAN — HANYA SETELAH DIMINTA

**JANGAN menghapus** `SonyPtpCameraManager.kt`, `MainActivity.kt`,
`KioskAutoPrintService.kt`, `lib/core/services/ipp/`, atau
`packages/flutter_uvc_camera` selama build Android masih harus hidup.

Penghapusan baru dilakukan setelah ada keputusan eksplisit untuk memensiunkan
jalur tablet. Tanyakan, jangan asumsikan.

---

## YANG **TIDAK** AKAN DIPERBAIKI MIGRASI INI

Jangan menjanjikan atau mengoptimasi ke arah ini — semuanya di luar jangkauan
perubahan OS:

- **Kualitas cetak** — dibatasi kanvas template backend `1333x2000` (333 DPI di
  4x6), bukan kamera dan bukan OS.
- **Kecepatan decode gambar** — `img.decodeImage` di package `image` itu pure
  Dart. Mini PC murah belum tentu menang lawan Snapdragon Legion Y700.
- **Kecepatan transfer foto** — dibatasi USB 2.0 di ZV-E10. Peningkatannya nyata
  tapi kecil.

---

## CARA MELAPOR

Di akhir setiap fase, laporkan dalam format ini:

1. Apa yang berhasil, dengan bukti (output perintah, hasil cetak, screenshot)
2. Apa yang **tidak** berhasil, apa adanya — jangan dihaluskan
3. Keputusan yang kamu ambil sendiri dan alasannya
4. File apa saja yang disentuh
5. Apakah build Android masih hijau
6. Apa yang kamu butuhkan dariku sebelum lanjut

Kalau kamu menemukan bahwa asumsi di prompt ini keliru, **katakan**. Prompt ini
disusun dari pembacaan kode, bukan dari percobaan di mesin Windows sungguhan.
