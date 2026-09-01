# Arsitektur Target — Kiosk Windows

## 1. Prinsip

Migrasi ini murah karena codebase sudah punya **dua facade** yang kebetulan
berada tepat di titik sambung platform:

- `PhotoboothCaptureService` — satu lapisan yang memutuskan jalur preview dan
  jalur shutter (`CaptureMode`, `CaptureSource`)
- `PrinterService` — satu pintu masuk untuk semua pencetakan

Seluruh migrasi berbentuk **menukar isi di balik dua facade ini**. Pemanggilnya —
`camera_session_screen`, `final_result_screen`, `heartbeat_service` — tidak perlu
tahu apa pun berubah.

**Aturan:** tidak boleh ada jalur baru yang memotong kedua facade tersebut.

---

## 2. Lapisan

```text
┌─────────────────────────────────────────────────────────────┐
│  features/  — welcome, tutorial, payment, frame, camera,    │
│               filter, preview, result, settings             │
│               TIDAK BERUBAH (±80% dari 21.465 baris lib/)   │
├─────────────────────────────────────────────────────────────┤
│  FACADE                                                     │
│  PhotoboothCaptureService        PrinterService             │
│  (abstract)                      (abstract)                 │
├──────────────────────────┬──────────────────────────────────┤
│  Implementasi Android    │  Implementasi Windows            │
│  ─ UvcCameraService      │  ─ WindowsCameraService          │
│    (fork flutter_uvc)    │    (camera_windows)              │
│  ─ SonyPtpCameraService  │  ─ SonyRemoteSdkService          │
│    (MethodChannel→Kotlin)│    (socket → helper .exe)        │
│  ─ PrintManager+A11y     │  ─ WindowsPrinterService         │
│                          │    (printing / printing_ffi)     │
├──────────────────────────┴──────────────────────────────────┤
│  PLATFORM                                                   │
│  Android: Kotlin, USB Host API │ Windows: Win32 spooler,     │
│  Epson Print Service           │ MediaFoundation, Sony SDK   │
└─────────────────────────────────────────────────────────────┘
```

Pemilihan implementasi lewat **abstract class + conditional import**, bukan
`Platform.isWindows` yang bertebaran di seluruh kode.

---

## 3. Struktur File yang Diusulkan

```text
lib/core/services/
├── capture/
│   ├── photobooth_capture_service.dart      ← abstract + factory
│   ├── capture_service_android.dart
│   └── capture_service_windows.dart
├── printing/
│   ├── printer_service.dart                 ← abstract + factory
│   ├── printer_service_android.dart         ← jalur PrintManager lama
│   └── printer_service_windows.dart         ← printing / printing_ffi
├── camera/
│   ├── uvc_camera_service.dart              ← Android saja
│   ├── windows_camera_service.dart          ← camera_windows
│   ├── sony_ptp_camera_service.dart         ← Android saja
│   └── sony_remote_sdk_service.dart         ← klien helper .exe
└── ipp/                                     ← DISIMPAN, tidak dipakai L8050
```

---

## 4. Jalur Cetak

```text
final_result_screen._executePrint()
  → unduh hasil render backend (final_url)
  → PrinterService.printPhotoBytes()
      → lock _isPrintingBusy   (garansi 1 aksi = 1 lembar)
      → Printing.directPrintPdf(printer: L8050)
          → driver Epson Windows melakukan rasterisasi ESC/P-R
              → kertas keluar. TIDAK ADA DIALOG.
      → baca status spooler → laporkan ke UI + heartbeat
```

Bandingkan dengan jalur Android sekarang, yang membutuhkan Accessibility Service
menekan tombol dan overlay menutupi dialog.

**Larangan permanen:** jangan pernah mengirim byte mentah (JPEG/PDF) ke port 9100
atau ke USB bulk endpoint. Sudah dibuktikan gagal — L8050 membacanya sebagai
perintah ESC/P dan mencetak karakter acak.

---

## 5. Jalur Capture

```text
Sony ZV-E10 ──HDMI──> Capture Card ──USB──┐
                                          ├──> Mini PC (Windows)
Sony ZV-E10 ──USB C-to-C (PC Remote)──────┘

PREVIEW  : capture card → MediaFoundation → camera_windows → CameraPreview
SHUTTER  : Camera Remote SDK → helper .exe → socket lokal → Flutter
```

Prasyarat di kamera tidak berubah dari dokumen hardware yang ada:
`USB Connection = PC Remote` (**bukan** USB Streaming, karena mode itu mematikan
output HDMI), powered USB hub, `Auto Power OFF Temp = High`,
`HDMI Info. Display = OFF`.

### 5.1 Kenapa helper `.exe` terpisah, bukan DLL in-process

Sony Camera Remote SDK adalah C++ dengan callback virtual. Memuatnya langsung ke
dalam proses Flutter berarti crash atau hang di SDK akan mematikan aplikasi
kiosk. Pengalaman jalur PTP di Android menunjukkan lapisan ini **akan** hang.

Batas proses memberi isolasi kegagalan: helper mati → Flutter mendeteksi socket
putus → jatuh ke mode `hdmiOnly` → sesi pelanggan tetap jalan.

### 5.2 Kontrak helper (garis besar)

| Perintah | Balasan |
|---|---|
| `connect` | status koneksi kamera |
| `status` | terhubung / AF state / model / serial |
| `capture` | menunggu **properti AF lock**, lepas shutter, kirim path file |
| `disconnect` | — |

Wajib: tunggu properti AF, **jangan** menyalin delay hardcoded dari
`SonyPtpCameraManager.kt`. Delay itu tebakan empiris untuk jalur yang berbeda.

### 5.3 Degradasi

```text
hybrid  ──(PTP gagal / kabel dicabut)──>  hdmiOnly  ──(capture card hilang)──>  gagal terkendali
   │                                          │
   └── foto 6000x4000                         └── grab frame 1920x1080
```

Enum `CaptureMode.hdmiOnly` sudah ada di kode dan menjadi jaring pengaman resmi.
Setiap degradasi wajib dilaporkan lewat `HeartbeatService`, bukan hanya di log.

---

## 6. Telemetri

`HeartbeatService` (interval 60 detik) diperluas:

| Field | Sekarang | Tambahan Windows |
|---|---|---|
| `printer_status` | `ready` / `offline` / `error` (tebakan) | status spooler sesungguhnya: `ready`, `out_of_paper`, `low_ink`, `offline`, `error` |
| `camera_status` | terhubung / tidak | + `capture_mode` aktif (`hybrid` / `hdmiOnly`) |
| `app_version` | — | **baru** — dasar mekanisme pembaruan jarak jauh |

---

## 7. Provisioning & Pembaruan

Provisioning **tidak berubah**: layar `DEVICE PAIRING KEY` + `API Base URL` yang
sudah ada tetap dipakai. `flutter_secure_storage` otomatis memakai DPAPI di
Windows.

Alur unit baru:

```text
Installer (Inno Setup)
  → aplikasi ke Program Files
  → Visual C++ Redistributable
  → driver Epson L8050 + default 4R borderless
  → autologin + autostart
  → matikan notifikasi, atur active hours
Jalankan aplikasi → masukkan pairing key → terhubung ke tenant → siap jual
```

Pembaruan: heartbeat mengirim `app_version`; backend membalas versi terbaru + URL
installer; aplikasi mengunduh dan memasang saat idle.

---

## 8. Yang Tidak Ikut Pindah

`laravel_backend/`, `laravel_api/`, `admin_dashboard/` — seluruhnya berkomunikasi
lewat HTTP dan tidak menyadari OS kiosk. Tidak ada perubahan skema database,
endpoint, maupun kontrak API, kecuali penambahan field telemetri di bagian 6.
