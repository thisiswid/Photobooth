# POC Camera Remote Command — Sony ZV-E10 Gen 1

Proyek **terpisah**. Tidak menyentuh Flutter, Android, HDMI preview, maupun
jalur cetak. Tujuannya satu: membuktikan apakah Camera Remote Command bisa
menggantikan Imaging Edge Remote sebagai jalur shutter + transfer JPEG.

Status: **BLOCKED** — menunggu pengajuan akses ke Sony.
Laporan hasil: [`docs/windows-migration/08-camera-remote-command-poc.md`](../../docs/windows-migration/08-camera-remote-command-poc.md)

---

## Yang sudah bisa dijalankan sekarang

```powershell
cd E:\Photobooth\tools\sony_camera_remote_poc\scripts
powershell -ExecutionPolicy Bypass -File .\probe-camera.ps1
```

Skrip ini **hanya membaca** — tidak mengubah driver, tidak mengubah setelan
kamera, tidak mengirim perintah apa pun. Keluarannya menjawab:

1. Apakah Windows melihat ZV-E10 di USB, dan berapa VID/PID-nya
2. Driver apa yang sedang memegang perangkat (WPD/MTP bawaan, atau WinUSB)
3. Apakah kamera muncul sebagai perangkat portabel
4. Apakah Imaging Edge sedang berjalan dan memegang kamera
5. Versi Windows

Nomor 2 dan 4 yang paling menentukan. Satu perangkat USB hanya bisa dipegang
satu pemilik — kalau Imaging Edge masih jalan, POC tidak akan bisa connect, dan
kegagalannya akan terlihat seperti kesalahan API padahal bukan.

Simpan keluarannya ke `results/`.

---

## Yang MASIH DIBUTUHKAN dan hanya bisa kamu lakukan

Camera Remote Command **hanya tersedia untuk pelanggan korporat**. Pengguna
perorangan tidak bisa mengunduh. Pengajuannya lewat halaman resmi Sony, per
wilayah (Asia-Pacific untuk Indonesia).

Yang akan diterima setelah disetujui, menurut halaman resminya:

- **Command Reference** — daftar perintah beserta model yang mendukungnya
- **Example Code**

Sampai berkas itu ada di tangan, POC **tidak bisa dilanjutkan** tanpa mengarang
nama perintah — dan itu dilarang.

---

## Prasyarat kamera

- **Firmware ZV-E10 harus versi terbaru.** Halaman resmi menyatakan
  "Only supports the latest firmware version."
- `MENU > Setup > USB > USB Connection = PC Remote`
- Imaging Edge Remote **ditutup** saat POC dijalankan

> ⚠️ **Perbarui firmware = risiko ke jalur Android.** Jalur PTP di Android
> memakai properti vendor `0xD2C1`/`0xD2C2` hasil rekayasa balik. Update
> firmware bisa mengubah perilakunya. Uji ulang tablet setelah update, dan
> catat versi firmware sebelum & sesudah.

---

## Struktur

```text
tools/sony_camera_remote_poc/
├── README.md          <- berkas ini
├── scripts/
│   └── probe-camera.ps1
├── source/            <- kode POC, DIISI setelah Command Reference diterima
└── results/           <- keluaran log, foto uji, catatan
```

`source/` sengaja dibiarkan kosong. Mengisinya sebelum dokumentasi resmi ada
berarti menebak nama API, dan itu justru yang membuat jalur Android rapuh.
