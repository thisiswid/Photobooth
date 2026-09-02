# Alur Kerja Kamera — Kondisi Sekarang & Rencana C4

Ditulis 2026-09-02, saat C4 tertunda karena ZV-E10 generasi pertama tidak
didukung Sony Camera Remote SDK.

Dokumen ini menjelaskan bagaimana kamera bekerja **sekarang** di Windows, dan
bagaimana alurnya berubah pada masing-masing dari tiga opsi C4. Dipakai sebagai
bahan memutuskan, bukan sebagai instruksi kerja.

---

## 1. Empat mode capture

Enum `CaptureMode` di `photobooth_capture_service.dart`:

| Mode | Preview dari | Foto dari | Resolusi foto | Platform |
|---|---|---|---|---|
| `hybrid` | Capture card (UVC) | Sony PTP | 6000x4000 (24 MP) | Android |
| `hdmiOnly` | Capture card (UVC) | Frame-grab capture card | 1920x1080 (~2 MP) | Android |
| `ptpOnly` | Kamera tablet | Sony PTP | 6000x4000 | Android |
| `windowsCamera` | Capture card (MediaFoundation) | `takePicture()` dari controller yang sama | mengikuti capture card (~2 MP) | **Windows** |
| `tabletOnly` | Kamera bawaan | Kamera bawaan | rendah | keduanya |

Windows saat ini **selalu** memakai `windowsCamera`, atau `tabletOnly` bila
tidak ada kamera sama sekali.

---

## 2. Alur sekarang di Windows

### 2.1 Deteksi — sekali saat masuk layar kamera

```text
camera_session_screen.initState()
  └─ PhotoboothCaptureService.detectMode()
       └─ Platform.isWindows ?
            └─ CameraService.getAvailableCamerasList()
                 ├─ kosong        -> CaptureMode.tabletOnly
                 └─ ada isinya    -> CaptureMode.windowsCamera
```

`SonyPtpCameraService.getStatus()` **tidak dipanggil di Windows** — seluruh isinya
bergantung pada USB Host API Android lewat MethodChannel ke Kotlin.

### 2.2 Pemilihan perangkat

`CameraService.getBestCamera()` memilih berurutan:

1. Kamera yang dipilih manual operator di panel settings
2. `lensDirection == external`
3. Pencocokan kata kunci nama (capture card, UVC, USB video, dsb.)
4. Kamera pertama yang ada

Terbukti di lapangan: MacroSilicon MS2109 (`vid_534D&pid_2109`) terdeteksi dan
dipilih otomatis.

### 2.3 Preview

```text
UnifiedCameraPreview
  ├─ isUvcMode == true   -> UvcPreview     (Android saja)
  ├─ controller siap     -> CameraPreview  (Windows & Android)
  ├─ isInitializing      -> spinner
  └─ tidak ada kamera    -> latar diam "Kamera belum tersambung"
```

Cabang terakhir ditambahkan di C1. Sebelumnya kondisi "tidak ada kamera"
menampilkan spinner selamanya, dan layar Welcome tampak seperti aplikasi yang
gagal terbuka.

### 2.4 Jepretan

```text
Tombol jepret / countdown selesai
  └─ PhotoboothCaptureService.capture()
       └─ mode == windowsCamera
            └─ mengembalikan success:false dengan pesan
               "Jepretan diambil oleh layar lewat CameraController"
  └─ camera_session_screen menangkap itu, lalu:
       _cameraController.takePicture()   (timeout 10 detik)
```

**Kenapa jepretan tidak diambil di dalam service.** Layar sudah memegang
`CameraController` untuk preview. Membuat controller kedua di service berarti dua
pemilik untuk satu perangkat kamera — sumber bug klasik, dan versi Android-nya
sudah pernah menggigit lewat bug single-view factory di plugin UVC.

### 2.5 Sesudah jepretan

```text
File foto tersimpan
  └─ PhotoUploadPrepService.warm(path)      <- dimulai SEGERA, di latar belakang
       └─ compute(_downscaleJpeg)           <- isolate terpisah
            └─ diperkecil ke sisi terpanjang 2000 px
  └─ (pelanggan meninjau foto / bersiap pose berikutnya)
  └─ Layar hasil: bytes sudah siap, unggah langsung jalan
```

Penyiapan sengaja dimulai saat jepretan, bukan saat layar hasil dibuka — supaya
waktu decode tidak jatuh di jalur kritis saat pelanggan menunggu.

---

## 3. Alur Android sekarang, sebagai pembanding

```text
Sony ZV-E10 ──HDMI──> Capture Card ──USB──┐
                                          ├──> Powered Hub ──> Tablet
Sony ZV-E10 ──USB C-to-C (PC Remote)──────┘

PREVIEW : capture card -> flutter_uvc_camera (fork dipatch) -> UVCCameraView
SHUTTER : SonyPtpCameraManager.kt
            ├─ drainEndpoints() + delay(200)
            ├─ S1 half-press : properti vendor 0xD2C1 = 0x02
            ├─ delay(500)                    <- MENEBAK AF sudah lock
            ├─ S2 full-press : properti vendor 0xD2C2 = 0x02
            ├─ delay(300) + release + delay(100)
            ├─ waitForObjectAddedEvent(5000) <- baca interrupt endpoint mentah
            └─ GetObjectHandles -> GetObject -> JPEG 6000x4000
```

Total **1,1 detik delay yang di-hardcode** sebelum menunggu ObjectAdded. Opcode
`0xD2C1`/`0xD2C2` berasal dari libgphoto2, bukan dokumentasi Sony.

Dua kelemahannya: `delay(500)` untuk AF adalah taruhan — kalau AF belum lock,
foto tetap dijepret dan hasilnya lembut tanpa ada yang tahu sampai cetakan
keluar. Dan opcode vendor tidak dijamin bertahan melewati update firmware.

---

## 4. Tiga opsi C4

### Opsi A — tetap 1080p (biaya nol)

Alurnya **persis seperti bagian 2**. Tidak ada perubahan kode sama sekali.

```text
Sony ZV-E10 ──HDMI──> Capture Card ──USB──> Mini PC
                       (preview DAN foto)
```

Kabel PTP tidak dipakai. Satu kabel, satu perangkat, tidak ada titik gagal
tambahan.

Konsekuensi kualitas: foto ~2 MP. Untuk cetak 4R pada kanvas template backend
`1333x2000` (333 DPI), foto 1080p yang dipotong ke slot 472x472 masih memadai —
plafon kualitas cetak ada di kanvas backend, bukan di kamera. Lihat PRD §4.

### Opsi B — ganti ke ZV-E10 II + Sony Camera Remote SDK

```text
Sony ZV-E10 II ──HDMI──> Capture Card ──USB──┐
                                             ├──> Powered Hub ──> Mini PC
Sony ZV-E10 II ──USB C-to-C (PC Remote)──────┘

PREVIEW : capture card -> camera_windows -> CameraPreview   (tidak berubah)
SHUTTER : helper .exe terpisah
            └─ Sony Camera Remote SDK 2.02.00
```

Alur jepretan menjadi:

```text
capture()  [mode hybrid]
  ├─ helper: status?           -> kamera terhubung?
  ├─ helper: capture
  │    ├─ tunggu PROPERTI AF LOCK        <- bukan delay tebakan
  │    ├─ SendCommand release down/up
  │    ├─ tunggu CALLBACK foto siap      <- bukan polling endpoint
  │    └─ SDK mengirim file langsung ke PC
  └─ file 26 MP ke disk
```

Yang hilang dibanding jalur Android: seluruh `drainEndpoints`, delay hardcoded,
`waitForObjectAddedEvent`, `GetObjectHandles`, dan fallback baca bulk stream.

**Arsitektur wajib: helper proses terpisah**, bukan DLL yang di-load in-process.
Kalau SDK crash atau hang, aplikasi kiosk tidak ikut mati. Berdasarkan pengalaman
jalur PTP Android, lapisan ini akan hang.

Kontrak helper lewat socket lokal:

| Perintah | Balasan |
|---|---|
| `connect` | status koneksi kamera |
| `status` | terhubung / AF state / model / serial |
| `capture` | tunggu AF lock, lepas shutter, kirim path file |
| `disconnect` | — |

### Opsi C — port PTP rekayasa balik ke Windows

```text
Kabel sama seperti Opsi B.

SHUTTER : helper .exe -> libusb/WinUSB -> opcode 0xD2C1 / 0xD2C2
```

Opcode-nya **sudah terbukti bekerja dengan kamera ini** di Android, jadi
protokolnya bukan tebakan. Yang baru adalah transportnya: di Windows kamera harus
diganti driver-nya ke WinUSB lewat Zadig supaya libusb bisa bicara.

Konsekuensi: kamera tidak lagi dikenali sebagai perangkat MTP biasa di mesin itu
(untuk kiosk masih dapat diterima), tujuan **G-3 "shutter di atas API resmi"
GUGUR**, dan kerapuhan terhadap update firmware tetap ada.

---

## 5. Degradasi — berlaku di Opsi B dan C

Ini bagian yang tidak boleh dilewat, apa pun opsinya.

```text
hybrid ──(PTP gagal / kabel dicabut / helper mati)──> windowsCamera
   │                                                      │
   │ foto 24-26 MP                                        │ foto ~2 MP
   │                                                      │
   └──────────────> sesi pelanggan TETAP JALAN <──────────┘
```

Aturannya:

1. Kegagalan PTP **tidak boleh** mematikan sesi pelanggan
2. Degradasi **wajib dilaporkan** lewat heartbeat (`capture_mode`), bukan hanya
   di log — kalau tidak, kiosk bisa berbulan-bulan mencetak 2 MP tanpa ada yang
   sadar
3. Kegagalan PTP **tidak boleh** diam-diam diganti frame-grab lalu dilaporkan
   sukses. Jalur Android pernah begitu, dan hasil akhirnya turun dari 24 MP ke
   2 MP tanpa siapa pun tahu. Sekarang kegagalan dilaporkan sebagai kegagalan.

---

## 6. Prasyarat kamera — tidak berubah di semua opsi

Dari `docs/hardware/01-camera.md`, tetap berlaku:

- `MENU → Setup → USB → USB Connection = PC Remote`
  **BUKAN "USB Streaming"** — mode itu mematikan output HDMI, dan
  `USB Connection Mode` bersifat eksklusif: PC Remote **atau** USB Streaming
- `Auto Power OFF Temp = High` — mencegah shutdown termal pada kiosk yang nyala
  seharian
- `HDMI Info. Display = OFF` — feed HDMI bersih tanpa ikon OSD
- Daya dari dummy battery atau USB PD, bukan baterai kamera
- Powered USB hub wajib bila dua kabel dipakai bersamaan

---

## 7. Ringkasan untuk memutuskan

| | Opsi A | Opsi B | Opsi C |
|---|---|---|---|
| Biaya | nol | satu badan kamera | nol |
| Waktu | nol | 1-2 minggu | 1-2 minggu |
| Resolusi foto | ~2 MP | 26 MP | 24 MP |
| Risiko teknis | tidak ada | sedang | tinggi |
| Tujuan G-3 tercapai | tidak berlaku | ya | **tidak** |
| Tahan update firmware | ya | ya | tidak |
| Jumlah kabel ke kamera | 1 | 2 | 2 |
| Titik gagal tambahan | tidak ada | helper + SDK | helper + libusb + driver Zadig |

Pertanyaan yang menentukan bukan teknis: **apakah pelanggan membayar untuk
perbedaan 2 MP dan 26 MP pada cetakan 4R?** Pada kanvas template 333 DPI yang
sekarang, perbedaan itu tidak sampai ke kertas. Ia baru terasa kalau kamu juga
menaikkan kanvas backend ke 480 DPI dan menjual file digital resolusi penuh.
