# Pemasangan Unit Kiosk Windows

Checklist untuk menyiapkan satu unit SnapTechBooth dari mesin Windows kosong
sampai siap jual. Target: **≤ 30 menit** per unit (C7-7).

Urutannya disengaja: yang paling sering gagal ditaruh di depan, supaya kalau
unit ini bermasalah, ketahuannya di menit ke-5 dan bukan di menit ke-25.

---

## 0. Prasyarat perangkat keras

| | Keterangan |
| --- | --- |
| Mini PC | Windows 11 **Pro** — Home tidak punya Shell Launcher / Group Policy |
| UPS | **Wajib**, bukan opsional. Legion Y700 punya baterai bawaan; mini PC tidak |
| Monitor sentuh | Kalibrasi sentuh terpisah dari rotasi tampilan (lihat langkah 6) |
| Printer | Epson L8050, USB |
| Kamera | Sony ZV-E10 + adaptor AC / dummy battery |
| Capture card | MS2109 (`VID_534D&PID_2109`) untuk preview HDMI |
| USB hub | Bertenaga (powered), untuk kamera + capture card + printer |

---

## 1. Windows: izin kamera (PALING SERING TERLEWAT)

**Settings → Privacy & security → Camera**, nyalakan **keduanya**:

1. `Camera access`
2. **`Let desktop apps access your camera`**

Kalau yang kedua mati, capture card **tidak akan terlihat sama sekali** oleh
aplikasi — `availableCameras()` mengembalikan daftar kosong tanpa error, padahal
Device Manager menampilkannya sebagai `OK`. Jalur kamera Sony (WIA) tetap jalan,
sehingga gejalanya menyesatkan: seolah "sebagian kamera rusak".

Verifikasi:

```
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam\NonPackaged" /v Value
```

Harus `Allow`.

---

## 2. Kamera Sony: setelan wajib

| Setelan | Nilai | Kenapa |
| --- | --- | --- |
| `MENU → Setup → USB → USB Connection` | **PC Remote** | Jangan `USB Streaming` — mode itu mematikan keluaran HDMI |
| Mode dial | **Foto**, bukan video | Di mode video, S1/S2 memulai rekaman, bukan menjepret |
| Image Size | **M** (4240×2832, 12 MP) | 24 MP hanya memperlambat transfer dan pemrosesan; cetakan tidak memakainya |
| File Format | **JPEG** saja | RAW+JPEG menggandakan transfer; helper menolak objek non-JPEG |
| Auto Power Off | **Mati** | Kamera tidur = sesi PTP hilang = jepretan pertama berikutnya gagal |
| Tampilan info HDMI | **Mati** | Supaya preview kiosk bersih dari overlay kamera |

Driver: kamera harus terikat `WUDFWpdMtp` bawaan Windows. Kalau Imaging Edge
pernah dipasang, driver libusbK-nya **memblokir WIA** — lepas dulu perangkatnya
di Device Manager beserta drivernya, lalu colok ulang.

---

## 3. Pasang aplikasi

Jalankan `SnapTechBooth-Setup-<versi>.exe` sebagai Administrator.

Yang dipasang: aplikasi ke `Program Files`, `sony_camera_helper.exe` **di folder
yang sama** (aplikasi mencarinya di situ), VC++ Redistributable, dan pintasan
autostart bila tasknya dicentang.

Verifikasi cepat sebelum lanjut — buka Command Prompt di folder instalasi:

```
sony_camera_helper.exe --list
sony_camera_helper.exe --selftest --verbose
```

`--selftest` harus `connect ok` lalu `capture ok`. Kalau gagal di sini, tidak
ada gunanya melanjutkan ke printer.

---

## 4. Printer: borderless 4R

Setelan ukuran kertas datang dari **driver**, bukan dari aplikasi. Dan ada dua
tempat yang mirip tapi berbeda:

- **Printing Preferences** — hanya untuk pengguna saat ini, **BUKAN** yang
  dibaca aplikasi.
- **Printer Properties → Advanced → Printing Defaults** — ini yang dipakai.

Set di **Printing Defaults**: ukuran `4 x 6 in`, Borderless **aktif**, bleed
`0`. Lalu di aplikasi: Hidden Settings → Printer → jalankan Test Print dan
sesuaikan custom margin bila tepinya terpotong.

Kertas 2×6 **tidak mungkin** di L8050 — lebar minimum drivernya 89 mm.

---

## 5. Penguncian kiosk

Belum diotomatiskan installer; ini setelan sistem operasi.

- [ ] Autologin akun kiosk (`netplwiz`, hilangkan centang "Users must enter a
      user name and password")
- [ ] **Settings → System → Notifications → Off**
- [ ] **Windows Update → Active hours** mencakup SELURUH jam operasional
- [ ] Sleep & screen timeout → **Never** (Power & battery)
- [x] `Alt+F4` dan tombol tutup **sudah diblokir aplikasi** (release saja).
      Operator keluar lewat **Hidden Settings → System → Tutup Aplikasi**,
      di balik PIN. Jangan lupakan ini saat menguji — tanpa jalan keluar itu,
      satu-satunya cara menutup adalah Task Manager
- [ ] Blokir tombol Windows dan `Ctrl+Shift+Esc` — TIDAK bisa dilakukan
      aplikasi. Butuh Shell Launcher (Windows 11 Pro) atau kiosk mode
- [ ] Matikan autoplay perangkat (supaya kamera tidak memicu dialog import
      yang merebut kamera dari helper)

---

## 6. Monitor sentuh

Rotasi tampilan dan rotasi **sumbu sentuh** adalah dua setelan terpisah. Kalau
hanya tampilan yang diputar, titik sentuh akan meleset 90 derajat.

Control Panel → **Tablet PC Settings → Setup** → ikuti wizard untuk mengikat
sentuh ke display yang benar.

---

## 7. Verifikasi akhir

- [ ] Boot dari listrik menyala sampai aplikasi siap **≤ 90 detik**
- [ ] Satu sesi penuh: bayar → pose → hasil → cetak
- [ ] Cabut kabel kamera di tengah sesi → sesi tidak mati, dan degradasi
      terlihat di dasbor lewat `capture_mode`
- [ ] Heartbeat masuk di dasbor admin (`printer_status`, `camera_status`,
      `capture_mode`, `app_version`)
- [ ] Cetakan borderless rapi, tanpa tepi putih dan tanpa terpotong

---

## Kalau kamera "sibuk" (WIA_ERROR_BUSY)

Kamera hanya melayani **satu sesi PTP**. Dari yang paling murah:

1. Tutup aplikasi SnapTechBooth — helper dijalankan olehnya dan ikut hidup
   selama aplikasi terbuka.
2. **Matikan kamera, cabut USB, tunggu 5 detik, colok, nyalakan.**
3. `tasklist | findstr /i "sony_camera_helper snaptechbooth ImagingEdge"`
4. Kalau tidak ada yang memegang tapi tetap sibuk, restart layanan WIA dari
   Command Prompt Administrator:

   ```
   net stop stisvc
   net start stisvc
   ```

Penyebab paling sering: helper dimatikan paksa dengan `taskkill /F`, sehingga
tidak sempat melepas kamera. Pemakaian normal tidak menimbulkan ini — helper
berhenti rapi saat aplikasi ditutup.
