# Arsitektur Kamera Sony ZV-E10 — Mode HYBRID (2 Kabel)

> Status: **diterapkan** (menggantikan mode "full HDMI").
> Kode terkait: `lib/core/services/photobooth_capture_service.dart`,
> `SonyPtpCameraManager.kt`.

## Keputusan

Pakai **KEDUA kabel**, dengan pembagian tugas yang tegas:

| Fungsi | Jalur | Alasan |
|---|---|---|
| **Live preview** | HDMI → USB capture card (UVC) | Stream 1080p mulus, latency rendah |
| **Shutter / ambil foto** | USB C-to-C (PTP, PC Remote) | Shutter mekanik + JPEG resolusi penuh 24MP |
| Fallback shutter | Frame-grab dari HDMI | Dipakai otomatis bila PTP gagal |
| Fallback terakhir | Kamera tablet | Bila tidak ada kamera eksternal |

```
Sony ZV-E10 ──HDMI──────────────> USB Capture Card ──┐
                                                     ├─> USB Hub bertenaga ─> Tablet
Sony ZV-E10 ──USB C-to-C (PC Remote)─────────────────┘
```

## Kenapa bukan HDMI saja?

Frame HDMI hanya **1920×1080 = 2,07 MP**. Cetak 4R (4×6 inci) @300 DPI butuh
1200×1800 px. Setelah frame 16:9 di-crop ke rasio 2:3, yang tersisa hanya
**±720×1080 px (0,78 MP)** — hasil cetak terlihat lunak dan pecah.

## Kenapa bukan C-to-C saja?

PTP tidak menyediakan live view yang layak untuk kiosk (liveview Sony hanya
±640×480, beberapa fps). Pengalaman preview jadi patah-patah.

## Kenapa 2 kabel tidak bentrok

Capture card dan kamera adalah **dua perangkat USB berbeda**:

- Capture card: VID `0x534D` (MacroSilicon), USB Video Class (class 14)
- Sony ZV-E10: VID `0x054C`, PTP (class 6, subclass 1, protocol 1)

Driver berbeda, endpoint berbeda, izin USB berbeda. Tidak ada tabrakan.

## Setting wajib di kamera

1. `MENU → Setup → USB → USB Connection` = **PC Remote**
   ⚠️ **JANGAN pilih "USB Streaming"** — mode itu mematikan output HDMI.
2. `MENU → Network → PC Remote Function → PC Remote` = **ON**
3. `MENU → Setup → HDMI Settings → HDMI Info. Display` = **Off** (clean HDMI)
4. Matikan Auto Power Off / pakai dummy battery untuk operasi seharian.

## Setting wajib di sisi tablet

- Gunakan **USB hub bertenaga (powered hub)**. Capture card + kamera menarik
  arus melebihi kemampuan port tablet.
- Saat dialog "Allow app to access USB device?" muncul, centang
  **"Use by default for this USB device"** agar tidak ditanya ulang tiap boot.

## Catatan implementasi

- `PhotoboothCaptureService.detectMode()` mendeteksi kabel mana yang terpasang
  dan memilih mode: `hybrid` / `hdmiOnly` / `ptpOnly` / `tabletOnly`.
- Badge mode ditampilkan di pojok kiri-atas layar preview untuk operator.
- Shutter mekanik membuat feed HDMI blackout ±0,5 detik; sudah ditutup oleh
  jeda transisi 700 ms di `_takePhoto()`.
