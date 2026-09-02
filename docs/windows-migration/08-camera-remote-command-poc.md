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
| Windows version | _belum diisi_ |
| Camera model | Sony ZV-E10 (generasi 1) |
| Camera firmware | _belum dibaca_ |
| USB VID/PID | _belum dibaca_ |
| Driver pemegang perangkat | _belum dibaca_ |
| Camera Remote Command version | _belum diunduh_ |
| Sample/version yang dipakai | _belum diunduh_ |

---

## 2. Compatibility

| Pertanyaan | Jawaban | Sumber |
|---|---|---|
| ZV-E10 didukung? | **YA** | daftar model resmi Camera Remote Command |
| Command apa yang didukung ZV-E10? | **UNKNOWN** | ada di Command Reference, belum diterima |
| Command apa yang tidak didukung? | **UNKNOWN** | idem |

Fungsi yang disebut halaman resmi untuk produk ini secara umum — **belum
dikonfirmasi berlaku untuk ZV-E10**: pengaturan kamera, shutter & pengambilan
gambar, live view, pembaruan firmware, transfer & penghapusan file, kontrol
pan/tilt (model tertentu), tampilan peaking/zebra dan marker.

Matriks per model ada di Command Reference. **Jangan menganggap satu fungsi
tersedia hanya karena namanya disebut di halaman ikhtisar.**

---

## 3. Test Results

| Test | Requirement | Result | Evidence |
|---|---|---|---|
| P1 | USB connect | **BLOCKED** | menunggu paket Sony |
| P2 | Shutter | **BLOCKED** | menunggu paket Sony |
| P3 | AF status | **UNKNOWN** | tidak dijelaskan di halaman publik; ada di Command Reference |
| P4 | Photo complete event | **UNKNOWN** | tidak dijelaskan di halaman publik; ada di Command Reference |
| P5 | JPEG transfer | **BLOCKED** | "file transfer" disebut sebagai fungsi produk, belum dikonfirmasi untuk ZV-E10 |
| P6 | Original JPEG | **BLOCKED** | menunggu eksekusi |
| P7 | Resolution | **BLOCKED** | baseline pembanding: 5328x4000 dari Imaging Edge Remote |
| P8 | 10 captures | **BLOCKED** | menunggu P1-P7 |

---

## 4. Actual JPEG

Baseline dari **Imaging Edge Remote** (bukan hasil POC, hanya pembanding):

| | Nilai |
|---|---|
| dimensions | **5328 x 4000** (~21,3 MP) |
| sumber | Imaging Edge Remote via USB |
| status | terbukti sebelum POC dimulai |

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

1. **Hanya untuk pelanggan korporat.** Pengguna perorangan tidak bisa mengunduh
   Camera Remote Command. Ini penghalang administratif, bukan teknis.
2. **Wajib firmware terbaru**, dengan risiko terhadap jalur PTP Android.
3. **Bentuknya spesifikasi, bukan pustaka siap pakai.** Transport PTP di Windows
   tetap harus disediakan sendiri kecuali Example Code menyertakannya.
4. **Satu perangkat USB, satu pemilik.** Imaging Edge Remote harus ditutup saat
   POC berjalan. Kegagalan connect karena hal ini mudah disalahartikan sebagai
   kegagalan API.
5. **AF status dan notifikasi foto selesai belum diketahui tersedia.** Kalau
   ternyata tidak ada, keunggulan utama atas jalur Android hilang — karena
   `delay(500)` yang menebak AF adalah kelemahan yang paling ingin diperbaiki.

---

## 6. Conclusion

**BLOCKED.**

Dokumentasi dan paket Camera Remote Command belum tersedia untuk diperiksa,
sehingga P1-P8 belum bisa dieksekusi. Menuliskan kode POC sekarang berarti
mengarang nama perintah dan callback — persis yang membuat jalur Android rapuh.

Yang **sudah terbukti** dan mengubah keadaan dibanding kesimpulan 2026-09-02:

> **ZV-E10 generasi pertama TERCANTUM sebagai didukung Camera Remote Command.**
> Kesimpulan sebelumnya bahwa kamera ini tidak bisa dikendalikan API resmi Sony
> hanya berlaku untuk Camera Remote **SDK**, bukan untuk Camera Remote
> **Command**. Opsi C4 terbuka kembali, dengan jalur yang berbeda.

---

## 7. Langkah berikutnya

Satu langkah, dan hanya bisa dilakukan pemilik usaha:

**Ajukan akses Camera Remote Command sebagai pelanggan korporat** lewat halaman
resmi Sony, wilayah Asia-Pacific. Siapkan nama badan usaha dan keterangan
penggunaan (kiosk photobooth komersial).

Sambil menunggu, yang bisa dikerjakan tanpa paket Sony:

1. Jalankan `probe-camera.ps1`, isi bagian 1 dokumen ini
2. Catat versi firmware ZV-E10 saat ini **sebelum** update apa pun
3. Simpan satu file JPEG hasil Imaging Edge Remote ke `results/` sebagai
   baseline pembanding resolusi

Setelah Command Reference diterima, urutan kerjanya:

```text
Baca Command Reference
  └─ matriks model: perintah apa yang berlaku untuk ZV-E10
  └─ apakah ada AF status?            -> isi P3
  └─ apakah ada event foto selesai?   -> isi P4
  └─ bagaimana JPEG diterima?         -> isi P5
Baca Example Code
  └─ apakah transport PTP disertakan? -> menentukan perlu Zadig atau tidak
Tulis POC console terpisah di tools/sony_camera_remote_poc/source/
  └─ P1 connect -> P2 shutter -> P5 transfer -> P7 resolusi -> P8 sepuluh kali
```

**Jangan** membuat helper produksi, `sony_camera_helper.exe`, atau integrasi
socket ke Flutter sebelum P1-P7 PASS.
