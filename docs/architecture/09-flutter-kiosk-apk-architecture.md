# Arsitektur & Alur Kerja Flutter Kiosk APK (Multi-Tenant Photobooth)

Dokumen ini menjelaskan rancangan arsitektur, alur kerja (workflow), serta integrasi hardware (Kamera, Printer, Pembayaran) untuk aplikasi Android Photobooth (Flutter APK).

---

## 1. Strategi Multi-Tenant: Bagaimana Setiap Cafe Memiliki Tampilan & Sistem Berbeda?

Ada 2 pendekatan teknis untuk mengelola perbedaan tiap cafe:

```mermaid
graph TD
    subgraph "Metode 1: Dynamic Provisioning (Sangat Direkomendasikan)"
        A[1 Master APK Universal] --> B[Install di Tablet Cafe Mana Saja]
        B --> C[Input Device Key / Scan QR Pairing]
        C --> D[Fetch Konfigurasi dari Server]
        D --> E[Otomatis Berubah Sesuai Cafe: Logo, Warna, Frame, Filter, Harga]
    end

    subgraph "Metode 2: Flutter Build Flavors (Jika butuh Icon/Nama App Berbeda di Launcher)"
        F[Source Code Flutter] --> G1[Build APK Flavor A: app-fakultaskopi.apk]
        F --> G2[Build APK Flavor B: app-cafebintang.apk]
        F --> G3[Build APK Flavor C: app-kopicuan.apk]
    end
```

> [!TIP]
> **Rekomendasi Utama: Metode 1 (Dynamic Provisioning)**
> Anda hanya perlu membuat & memelihara **1 file APK saja**. Saat APK dipasang di tablet/kiosk cafe baru, staf hanya memasukkan **Device Pairing Key** yang digenerate dari Super Admin. Aplikasi otomatis mendownload identitas cafe tersebut.

---

## 2. Diagram Alur Pairing & Inisialisasi Kiosk (Onboarding)

Alur ketika mesin booth pertama kali diinstal di lokasi cafe:

```mermaid
sequenceDiagram
    autonumber
    actor Staf as Staf / Teknisi Cafe
    participant APK as Flutter Kiosk APK
    participant Storage as Local SQLite / SharedPreferences
    participant Backend as Laravel Backend

    Staf->>APK: Buka APK pertama kali
    APK->>Storage: Cek apakah sudah ada Device Key?
    Storage-->>APK: Belum terdaftar (Device Key = Null)
    APK->>Staf: Tampilkan Layar "Setup & Aktivasi Mesin"
    
    Staf->>APK: Input Device Key (didapat dari Super Admin)
    APK->>Backend: POST /api/devices/activate (device_key, platform, device_info)
    
    alt Device Key Valid & Cafe Aktif
        Backend-->>APK: Return 200 OK + Cafe Info + Theme + Frames + Filters + Config
        APK->>Storage: Simpan Cafe ID, Device Token, & Konfigurasi Offline
        APK->>APK: Download & Cache Aset (Frame PNG, Watermark, Video Tutorial)
        APK->>Staf: Tampilkan Layar Utama (Welcome Screen Cafe)
    else Device Key Invalid / Cafe Suspended
        Backend-->>APK: Return 403 Forbidden / Invalid Key
        APK->>Staf: Tampilkan Notifikasi Error & Hubungi Super Admin
    end
```

---

## 3. Diagram Alur Transaksi Pelanggan (Customer Journey)

Alur lengkap mulai dari pelanggan mendekat ke booth sampai cetak foto dan scan QR download:

```mermaid
flowchart TD
    Start([1. Idle / Video Screen Saver]) --> TapScreen[Pelanggan Sentuh Layar]
    TapScreen --> ChooseFrame[2. Pilih Layout & Frame Foto]
    ChooseFrame --> PaymentScreen[3. Halaman Pembayaran QRIS]
    
    PaymentScreen --> RequestQR[APK Minta Dynamic QRIS ke Server]
    RequestQR --> ShowQR[Tampilkan QRIS & Timer 3 Menit]
    
    ShowQR --> PollingPayment{Cek Status Bayar}
    PollingPayment -- Belum Bayar & Timeout --> CancelSession[Sesi Dibatalkan / Reset]
    PollingPayment -- Sukses Bayar --> StartCapture[4. Mulai Sesi Foto]
    
    StartCapture --> Countdown[Countdown 3..2..1]
    Countdown --> TriggerCamera[📷 Jepret Foto via Kamera]
    TriggerCamera --> NextPose{Pose Lengkap?}
    NextPose -- Belum --> Countdown
    NextPose -- Lengkap --> ChooseFilter[5. Pilih Filter & Efek]
    
    ChooseFilter --> Processing[6. Penggabungan Foto ke Frame Composite]
    Processing --> UploadServer[Upload Hasil Foto & Video ke Server]
    
    UploadServer --> TriggerPrint[🖨️ Kirim Perintah Cetak ke Printer]
    UploadServer --> ShowDownloadQR[7. Tampilkan QR Code Download untuk HP]
    
    TriggerPrint --> FinishScreen[8. Layar Terima Kasih]
    ShowDownloadQR --> FinishScreen
    FinishScreen --> ResetIdle([Kembali ke Screen Saver])
```

---

## 4. Diagram Arsitektur Komponen Flutter APK

Struktur modul internal dalam aplikasi Flutter:

```mermaid
graph TB
    subgraph UI_Layer ["📱 UI / Presentation Layer"]
        Screensaver[Screen Saver & Attract Loop]
        FrameSelection[Frame Selector Grid]
        PaymentUI[QRIS & Payment Gateway UI]
        CameraPreview[Live Camera Preview & Overlay]
        FilterGallery[Filter & Sticker Selector]
        PrintStatusUI[Printing Status & QR Download]
    end

    subgraph Core_Engine ["⚙️ Core Business Logic (Bloc / Riverpod)"]
        SessionBloc[Session State Manager]
        PaymentBloc[Payment & Webhook Listener]
        CompositorService[Canvas Photo Strip Compositor]
        SyncService[Asset Sync & Telemetry Reporter]
    end

    subgraph Hardware_Drivers ["🔌 Hardware Abstraction Layer"]
        CamDriver["📷 Camera Engine (Camera2 / UVC USB / Canon DSLR)"]
        PrintDriver["🖨️ Printer Service (DNP / ESC-POS / OTG USB / Wi-Fi)"]
        LedDriver["💡 Light & Shutter Relay (Opsional via Serial/Bluetooth)"]
    end

    subgraph Storage_Network ["💾 Storage & Network Layer"]
        LocalCache[(SQLite / Hive / File Cache)]
        ApiClient[Dio / Retrofit HTTP Client]
        WebSocketClient[Pusher / WebSocket Realtime]
    end

    UI_Layer --> Core_Engine
    Core_Engine --> Hardware_Drivers
    Core_Engine --> Storage_Network
    Storage_Network --> LaravelServer[🌐 Laravel Cloud Backend]
```

---

## 5. Rincian Integrasi Hardware (Kamera, Printer, Pembayaran)

### A. Integrasi Kamera (Camera Driver)
1. **Kamera Built-in Tablet / Android**:
   - Menggunakan package `camera` Flutter dengan resolusi Full HD (1920x1080) atau 4K.
2. **Kamera Eksternal USB (Webcam Logitech / USB Kiosk Camera)**:
   - Menggunakan package `flutter_uvc_camera` melalui kabel USB OTG.
3. **Kamera DSLR / Mirrorless (Canon EOS / Sony)**:
   - Terhubung via USB Tethering menggunakan PTP/IP protokol library Android.

### B. Integrasi Printer (Print Driver)
1. **Printer Foto Dye-Sublimation (DNP RX1HS / Citizen / Hiti)**:
   - Terhubung ke Android Box / Tablet via USB OTG atau Print Server lokal (CUPS / Raw TCP port 9100).
   - Ukuran cetak standar: 4R (4x6 inci) atau 2x6 strip potong otomatis (2 strips per 4R print).
2. **Thermal Receipt / Mini Photo (ESC/POS)**:
   - Terhubung via Bluetooth / USB menggunakan package `esc_pos_utils_plus` & `flutter_pos_printer_platform`.

### C. Integrasi Pembayaran (Payment Gateway)
1. **Dynamic QRIS (Xendit / Midtrans)**:
   - Setiap sesi membuat invoice QRIS unik.
   - Aplikasi mendengarkan status pembayaran via Polling `/api/payments/{id}/status` tiap 2 detik atau Push Notification via WebSocket.
2. **Opsi Bayar di Kasir (Voucher Code / Cashier Approval)**:
   - Pelanggan memasukkan kode voucher yang dibeli di kasir cafe.

---

## 6. Struktur Konfigurasi Dinamis yang Dikirim Server ke APK

Saat APK melakukan sync ke server (`GET /api/devices/{key}/config`), server mengembalikan JSON yang mengatur seluruh identitas cafe:

```json
{
  "status": "success",
  "data": {
    "cafe": {
      "id": 1,
      "name": "Fakultas Kopi",
      "code": "FK-BOOT-001",
      "theme": {
        "primary_color": "#D97706",
        "secondary_color": "#78350F",
        "background_url": "https://server.com/storage/themes/fk-bg.jpg",
        "logo_url": "https://server.com/storage/cafes/logos/fk.png"
      }
    },
    "pricing": {
      "session_price": 25000,
      "currency": "IDR",
      "print_copies_default": 2
    },
    "hardware_config": {
      "countdown_seconds": 5,
      "max_retakes": 1,
      "auto_print": true
    },
    "frames": [
      {
        "id": 1,
        "name": "Strip Vintage Coffee",
        "layout_type": "single",
        "pose_count": 4,
        "asset_url": "https://server.com/storage/frames/vintage.png"
      }
    ],
    "filters": [
      { "id": 1, "name": "Normal", "slug": "normal" },
      { "id": 2, "name": "Monochrome B&W", "slug": "bw" },
      { "id": 3, "name": "Warm Coffee", "slug": "warm" }
    ]
  }
}
```
