# Camera Remote Command POC — Sony ZV-E10

**Status: BLOCKED** — menunggu persetujuan akses korporat dari Sony.
Ditulis 2026-09-02. Semua isian PASS/FAIL menunggu eksekusi nyata.

> Aturan dokumen ini: **tidak ada klaim tanpa bukti.** Kolom yang belum diuji
> ditulis `BLOCKED` atau `UNKNOWN`, bukan ditebak. Nama perintah, class, event,
> dan callback tidak boleh ditulis sebelum Command Reference resmi diterima.

---

## 0. Temuan sebelum coding

### 0.1 Camera Remote Command ≠ Camera Remote SDK

Ini dua produk berbeda di bawah payung Camera Remote Toolkit, dan pembedaan itu
menyelamatkan proyek ini.

| | Camera Remote **SDK** | Camera Remote **Command** |
|---|---|---|
| Bentuk | Pustaka biner (C++) | **Spesifikasi perintah/protokol** |
| Dasar | API milik Sony | **Perluasan proprietary Sony atas PTP standar ISO** |
| ZV-E10 Gen 1 | **TIDAK didukung** | **DIDUKUNG** |
| Isi paket | Library + header + sample | **Command Reference + Example Code** |
| Siapa boleh | umum (registrasi) | **hanya pelanggan korporat** |

Daftar ZV yang didukung Camera Remote Command, dikutip persis dari halaman
resmi: `ZV-E1, ZV-E10, ZV-E10M2, ZV-1M2, ZV-1F, ZV-1A, ZV-1`

Bandingkan dengan daftar Camera Remote SDK 2.02.00 yang hanya memuat `ZV-E1`
dan `ZV-E10M2` — inilah sebab gerbang C4 gagal pada 2026-09-02.

### 0.2 Konsekuensi bentuknya adalah spesifikasi, bukan pustaka

Karena Camera Remote Command adalah **spesifikasi protokol di atas PTP**, POC
tetap membutuhkan **transport PTP di Windows**. Sony memberi tahu perintah apa
yang harus dikirim; mengirimkannya tetap urusan kita.

Tiga kemungkinan transport, belum ditentukan karena bergantung isi Example Code:

1. **Example Code Sony** sudah menyertakan transport — kemungkinan terbaik
2. **WinUSB via libusb** — driver kamera diganti lewat Zadig. Konsekuensi:
   kamera tidak lagi dikenali sebagai perangkat MTP biasa di mesin itu
3. **WPD/MTP API bawaan Windows** — tanpa ganti driver, tapi belum jelas apakah
   perintah vendor Sony bisa lewat jalur ini

> Ini pembeda penting dari asumsi awal: masalahnya bukan "apakah ada API",
> melainkan "bagaimana perintah resmi itu dikirimkan".

### 0.3 Hubungan dengan jalur Android yang sudah ada

`SonyPtpCameraManager.kt` sudah berbicara PTP ke kamera yang sama, memakai
properti vendor `0xD2C1` (half-press) dan `0xD2C2` (full-press) yang diambil
dari libgphoto2 — hasil rekayasa balik pihak ketiga, bukan dokumentasi Sony.

Kemungkinan besar perintah yang sama terdokumentasi resmi di Command Reference.
Kalau benar, nilai dari Command Reference bukan "membuka kemampuan baru",
melainkan:

- Mengganti tebakan dengan perintah yang terdokumentasi
- Memberi tahu apakah **status AF** benar-benar bisa dibaca — inilah yang
  membuat `delay(500)` di Android bisa dihapus
- Memberi tahu apakah ada **notifikasi foto selesai**, menggantikan pembacaan
  interrupt endpoint mentah

Kedua hal terakhir belum diketahui. Lihat P3 dan P4.

### 0.4 Lisensi — bukan penghalang

Pemakaian komersial **diizinkan**. Lisensi memberi hak "develop and using
application software" untuk mengendalikan perangkat Sony dan menjualnya ke
pengguna akhir, serta menyertakan example program ke dalam aplikasi secara
tidak terpisahkan lalu mendistribusikannya.

Kewajiban yang menempel:

- Memberi tahu pengguna akhir bahwa **perangkat keluar dari garansi pabrik**
  begitu dikendalikan lewat aplikasi
- Tidak menyiratkan Sony sebagai pemilik/pembuat aplikasi
- Menanggung dukungan pelanggan sendiri
- Dilarang untuk keperluan militer/persenjataan
- Dilarang melakukan reverse engineering atas materi berlisensi

Tidak ada kewajiban kerahasiaan atas spesifikasinya yang disebutkan, dan tidak
ada royalti.

### 0.5 Prasyarat firmware — mengandung risiko

Halaman resmi: **"Only supports the latest firmware version."**

> ⚠️ Memperbarui firmware ZV-E10 berpotensi **mengubah perilaku jalur PTP
> Android** yang memakai opcode hasil rekayasa balik. Catat versi firmware
> sebelum dan sesudah update, lalu uji ulang tablet. Jangan update firmware di
> hari yang sama dengan jadwal operasional.

---

## 1. Environment

Isi setelah menjalankan `tools/sony_camera_remote_poc/scripts/probe-camera.ps1`.

| | Nilai |
|---|---|
| Windows version | Windows 11 Home Single Language, build 26200, AMD64 |
| Camera model | Sony ZV-E10 (generasi 1) |
| Camera firmware | **bodi 2.30, lensa 01** (dicatat 2026-09-02, sebelum update apa pun) |
| USB VID/PID saat PC Remote | `VID_054C&PID_0D97` — "Sony Remote Control Camera" |
| Driver pemegang perangkat | **libusbK** (status OK) |
| Camera Remote Command version | **2.02.00** |
| Contoh yang dipakai | `Examples/example-v2-windows` dan `example-v3-windows` |

> ⚠️ **Windows 11 Home.** Untuk mesin kiosk nanti tetap dibutuhkan **Pro** —
> Shell Launcher dan Group Policy penunda update tidak ada di Home. Ini urusan
> C7, bukan penghalang POC.

Perangkat Sony lain yang terlihat di probe (status Unknown = sisa koneksi lama,
tidak tersambung saat ini): `PID_0DE3` UVC+audio (mode USB Streaming),
`PID_0D95` dan `PID_03E2` mass storage.

---

## 2. Compatibility

Dikutip dari matriks resmi di `README.pdf`:

| Model | Camera Control PTP 3 | Camera Control PTP 2 | USB | IP |
|---|---|---|---|---|
| **ZV-E10** | ✓ | ✓ | ✓ | ✓ |
| ZV-E10M2 | ✓ | ✓*4 | ✓ | ✓ |
| ZV-E1 | ✓ | ✓*4 | ✓ | ✓ |

**ZV-E10 mendukung KEDUA versi protokol tanpa catatan kaki pembatas** — lebih
bersih daripada ZV-E10M2 dan ZV-E1 yang memakai tanda `*4` pada PTP 2.

- **PTP 3** = "2020 models or later", fitur terbaru
- **PTP 2** = model sebelum 2020, fitur lebih terbatas

Karena ZV-E10 mendukung dua-duanya, POC sebaiknya memakai **PTP 3** (fitur lebih
lengkap) dan menyimpan PTP 2 sebagai cadangan bila ada perintah yang bermasalah.

---

## 3. Test Results

| Test | Requirement | Result | Evidence |
|---|---|---|---|
| P1 | USB connect | **SIAP DIUJI** | transport WIA, lihat §3.1 |
| P2 | Shutter | **TERDOKUMENTASI** | `SDIOControlDevice(DPC_S1/S2_BUTTON)` |
| P3 | AF status | **SUPPORTED** ✅ | `DPC_AF_STATUS = 0xD213` di `PTPDef.h` |
| P4 | Photo complete | **SUPPORTED** ✅ | `DPC_SHOOTING_FILE_INFOMATION = 0xD215` |
| P5 | JPEG transfer | **TERDOKUMENTASI** | `ExecuteGetObject(SHOT_OBJECT_HANDLE)` |
| P6 | Original JPEG | **BELUM DIUJI** | menunggu eksekusi |
| P7 | Resolution | **BELUM DIUJI** | baseline pembanding: 5328x4000 |
| P8 | 10 captures | **BELUM DIUJI** | menunggu P1-P7 |

### 3.1 Transport — WIA, BUKAN libusb

`PTPControl.cpp` memakai **Windows Image Acquisition**: `IWiaDevMgr`,
`IWiaItemExtras`, `Sti.h`, `Wia.h`. Perintah vendor dikirim lewat mekanisme
escape WIA.

**Artinya tidak perlu Zadig dan tidak perlu mengganti driver ke WinUSB.**
Kekhawatiran di dokumen 07 tentang driver replacement gugur.

> ⚠️ **TAPI ADA KONFLIK DENGAN KONDISI SEKARANG.**
>
> Instruction Manual mensyaratkan: *"Ensure that the connected camera is under
> **Portable Devices** in the Device Manager window."*
>
> Probe 2026-09-02 menunjukkan kamera justru terikat ke **libusbK** sebagai
> "Sony Remote Control Camera", dan **tidak muncul** di daftar perangkat
> portabel. Driver libusbK itu kemungkinan besar dipasang oleh Imaging Edge.
>
> Selama binding itu bertahan, WIA tidak akan melihat kamera — dan P1 akan gagal
> karena alasan yang tidak ada hubungannya dengan protokol.

### 3.2 Alur capture resmi

Dari `CaptureDlg.cpp` dan `DataManager.cpp`:

```text
SDIOConnect / SDIOGetExtDeviceInfo          <- buka sesi
   │
SDIOControlDevice(DPC_S1_BUTTON, DOWN)      <- half-press
   │
baca DPC_AF_STATUS (0xD213)                 <- STATUS AF RESMI
   │                                           bukan delay tebakan
SDIOControlDevice(DPC_S2_BUTTON, DOWN)      <- shutter
SDIOControlDevice(DPC_S2_BUTTON, UP)
SDIOControlDevice(DPC_S1_BUTTON, UP)
   │
DPC_SHOOTING_FILE_INFOMATION (0xD215)       <- pemberitahuan file siap
   │
GetObjectInfo(SHOT_OBJECT_HANDLE)           <- 0xFFFFC001
ExecuteGetObject(SHOT_OBJECT_HANDLE, buf)
   │
WriteFile -> JPEG di disk
```

### 3.3 Temuan yang mengubah cara memandang jalur Android

Opcode dan properti yang dipakai `SonyPtpCameraManager.kt` **ternyata benar dan
resmi**:

| Dipakai di Android | Nama resmi Sony |
|---|---|
| `0xD2C1` | `DPC_S1_BUTTON` |
| `0xD2C2` | `DPC_S2_BUTTON` |
| `0x9207` | `PTP_OC_SDIOControlDevice` |

Jadi jalur Android bukan "protokol karangan" — ia memakai perintah yang benar,
diambil dari libgphoto2 yang rupanya memetakan hal yang sama.

**Yang hilang di Android bukan perintah shutter-nya, melainkan `DPC_AF_STATUS`.**
Itulah sebabnya di sana ada `delay(500)` yang menebak AF sudah lock. Dengan
Command Reference, tebakan itu bisa diganti pembacaan status sungguhan — dan
inilah nilai terbesar dari paket ini, bukan kemampuan menjepretnya.

---

## 4. Actual JPEG

Baseline dari **Imaging Edge Remote** (bukan hasil POC, hanya pembanding):

| | Nilai |
|---|---|
| dimensions | **5328 x 4000** (~21,3 MP) |
| sumber | Imaging Edge Remote via USB, mode PC Remote |
| status | **TERBUKTI 2026-09-02** — shutter menyala, JPEG tersimpan ke PC |

### Apa yang sudah dibuktikan baseline ini

Bukan sekadar "Imaging Edge bisa". Yang terbukti adalah seluruh rantai fisiknya:

- Kamera menerima perintah shutter lewat USB dalam mode PC Remote
- Firmware ZV-E10 saat ini mendukung jalur itu
- Kabel dan port USB memadai untuk transfer file besar
- JPEG resolusi penuh sampai ke disk Windows, bukan preview

Artinya risiko POC menyusut drastis. Pertanyaannya bukan lagi "apakah kamera
ini bisa dikendalikan dari Windows" — itu sudah dijawab. Yang tersisa: apakah
kita boleh memerintahnya **langsung** tanpa Imaging Edge sebagai perantara.

### ⚠️ Catatan tentang angka 5328 x 4000

Rasio 5328:4000 adalah **4:3**. Sensor ZV-E10 berformat **3:2**, yang pada
ukuran L menghasilkan **6000 x 4000**.

Artinya ada pemotongan di sisi lebar — kemungkinan besar dari setelan kamera,
bukan dari Imaging Edge. Yang perlu diperiksa di kamera:

- `MENU > Shooting > Aspect Ratio` — apakah sedang 4:3 atau 3:2
- `MENU > Shooting > JPEG Image Size` — apakah L, M, atau S
- `MENU > Shooting > JPEG Quality`

Ini **bukan** masalah yang harus diselesaikan sekarang, dan **bukan** alasan
menunda POC. Tapi kalau nanti file digital resolusi penuh dijual ke pelanggan,
selisih 5328 dan 6000 piksel itu berarti — dan perbaikannya cuma satu setelan
di menu kamera, bukan pekerjaan koding.

Catat rasio yang dipakai saat POC supaya hasilnya bisa dibandingkan setara.

Hasil POC — diisi setelah eksekusi:

| | Nilai |
|---|---|
| filename | _belum_ |
| dimensions | _belum_ |
| file size | _belum_ |
| format | _belum_ |

> Resolusi **wajib diukur dari file di disk**, bukan dari tampilan aplikasi.
> Catatan: 1920x1080 yang sempat terlihat di Viewer ternyata hanya representasi
> preview — file aslinya 5328x4000. Jangan mengulang kesalahan pembacaan itu.
>
> **6000x4000 BUKAN requirement.** Yang terbukti adalah 5328x4000.

---

## 5. Limitations

Yang sudah pasti, sebelum POC dijalankan:

1. **Driver kamera saat ini terikat libusbK, bukan WIA.** Ini penghalang nomor
   satu. Kamera harus muncul di bawah "Portable Devices" di Device Manager
   sebelum contoh Windows bisa melihatnya. Melepas binding libusbK kemungkinan
   membuat **Imaging Edge Remote berhenti bekerja** — dan Imaging Edge adalah
   baseline pembanding kita. Lakukan setelah baseline JPEG-nya disimpan.
2. **Contoh program dilarang dipakai di produk.** Instruction Manual menyatakan
   tegas: *"please do not use them in your products."* Contoh dipakai untuk
   MEMBUKTIKAN (POC); implementasi produksi harus ditulis sendiri berdasarkan
   Command Reference. Ini mengubah perkiraan usaha untuk helper produksi.
3. **Butuh Visual Studio 2022 + Windows SDK 10.0** untuk membangun contoh
   Windows. Sudah ada di laptop (dipakai Flutter Windows), tapi workload C++
   harus lengkap.
4. **Hanya untuk pelanggan korporat.** Sudah teratasi — paket diterima.
5. **Wajib firmware terbaru.** Firmware saat ini bodi 2.30. Belum diverifikasi
   apakah itu yang terbaru. Kalau perlu update, ingat risikonya ke jalur Android.
6. **Satu perangkat USB, satu pemilik.** Imaging Edge harus ditutup saat POC.

---

## 5.1 Jalan pintas yang HARUS ditolak

Karena Imaging Edge Remote sudah terbukti bekerja, akan muncul godaan untuk
mengotomasi GUI-nya — menekan tombol shutter Imaging Edge lewat UI automation,
lalu memantau folder keluarannya.

**Jangan.** Itu persis kelas kesalahan yang sama dengan Accessibility Service di
Android: menekan tombol aplikasi lain secara otomatis, rapuh terhadap perubahan
tata letak, dan gagal diam-diam tanpa pesan error. Seluruh migrasi ini dilakukan
justru untuk keluar dari pola itu.

Imaging Edge tetap berperan sebagai **baseline pembanding**, bukan sebagai
dependency produksi. Kalau Camera Remote Command akhirnya tidak bisa diakses,
opsi yang jujur adalah tetap di 1080p dari capture card — bukan mengotomasi GUI
orang lain.

---

## 6. Conclusion

**PARTIAL — dokumentasi PASS, eksekusi belum dijalankan.**

Seluruh kemampuan yang dibutuhkan **terdokumentasi resmi dan berlaku untuk
ZV-E10**:

- ZV-E10 didukung PTP 3 dan PTP 2, lewat USB maupun IP, tanpa catatan kaki
- Shutter: `DPC_S1_BUTTON` / `DPC_S2_BUTTON` lewat `SDIOControlDevice`
- **Status AF: `DPC_AF_STATUS` — tersedia.** Ini jawaban paling penting
- **Pemberitahuan foto siap: `DPC_SHOOTING_FILE_INFOMATION` — tersedia**
- Transfer JPEG: `GetObjectInfo` + `ExecuteGetObject` pada `SHOT_OBJECT_HANDLE`
- Transport WIA — **tidak perlu Zadig, tidak perlu ganti driver ke WinUSB**

Yang tersisa murni eksekusi: P1, P2, P5, P6, P7, P8.

Satu penghalang nyata sebelum P1 bisa dicoba: **kamera saat ini terikat driver
libusbK dan tidak muncul sebagai Portable Device**, padahal WIA membutuhkannya.

---

## 7. Langkah berikutnya

### Langkah 0 — amankan baseline SEBELUM menyentuh driver

Melepas binding libusbK kemungkinan membuat Imaging Edge berhenti bekerja.
Sebelum itu:

1. Ambil satu foto lewat Imaging Edge Remote
2. Simpan JPEG-nya ke `tools/sony_camera_remote_poc/results/`
3. Catat dimensi dan ukuran file-nya

Kalau POC gagal dan Imaging Edge juga rusak, kita kehilangan dua-duanya.

### Langkah 1 — pindahkan kamera ke Portable Devices

Di kamera: `Setting > USB > USB Connection Mode` = **"Sel. When Connect"**
(bukan "PC Remote" yang dipatok). Colok USB, lalu di layar kamera pilih
**"Remote Shoot (PC Remote)"**.

Lalu di Device Manager, pastikan kamera muncul di bawah **Portable Devices**.
Kalau masih di bawah "libusbK Usb Devices": klik kanan perangkat itu →
Uninstall device → centang hapus driver → cabut dan colok ulang kamera.

Jalankan `probe-camera.ps1` lagi untuk memastikan.

### Langkah 2 — bangun dan jalankan contoh Sony

```powershell
# buka di Visual Studio 2022
E:\sony-crc\CameraRemoteCommand-2.02.00\Examples\example-v3-windows\CameraControlPTP.sln
# build Release, lalu jalankan Release\CameraControlPTP.exe
```

Pakai **v3** lebih dulu (fitur lebih lengkap); v2 sebagai cadangan.

Ini menguji P1, P2, P5, P6, P7 sekaligus, tanpa menulis satu baris kode pun.

#### Masalah build yang sudah ditemui

**MSB8020 — Platform Toolset v143 tidak ditemukan.**
Solusi Sony dibuat untuk Visual Studio 2022 (`v143`); laptop memakai Visual
Studio 18 (`v180`). Bukan masalah path.

Perbaikan: klik kanan **solution** (bukan project) → **Retarget solution** →
pilih toolset yang tersedia + Windows SDK terbaru. Tidak perlu unduh apa pun.

**Kemungkinan menyusul: MFC dan ATL belum terpasang.**
Contoh ini berbasis MFC (`afxdialogex.h`, `atlimage.h`, `CComPtr`), dan
komponen itu tidak ikut terpasang secara default. Kalau muncul
`cannot open source file "afxdialogex.h"`, buka Visual Studio Installer →
Modify → Individual components, centang **C++ MFC** dan **C++ ATL** untuk
build tools terbaru (x86 & x64).

**Cadangan bila retarget gagal:** pasang Build Tools untuk Visual Studio 2022
(v143) berdampingan dengan VS 18. Unduhannya besar tapi menghilangkan seluruh
variabel versi compiler.

### Langkah 3 — catat hasilnya

Isi tabel §3 dan §4 dokumen ini dengan hasil sungguhan. Untuk P7, ukur file di
disk — bukan tampilan di GUI.

### Langkah 4 — sepuluh capture berturut-turut

P8. Perhatikan hang, crash, JPEG korup, nama file bertabrakan, dan pertumbuhan
memori.

### Baru setelah P1-P7 PASS

Rancang helper produksi. Ingat: **contoh Sony tidak boleh dipakai di produk** —
implementasi ditulis sendiri berdasarkan Command Reference, dengan contoh
sebagai rujukan pemahaman.
