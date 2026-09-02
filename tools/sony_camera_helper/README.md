# sony_camera_helper

Helper produksi untuk SnapTechBooth: mengendalikan Sony ZV-E10 lewat
**Camera Control PTP** (transport WIA) dan mengeksposnya sebagai socket
localhost berbasis baris JSON.

Helper ini dibuat setelah POC P1–P8 lulus (lihat
`docs/windows-migration/08-camera-remote-command-poc.md`).

## Kenapa proses terpisah

1. Kalau lapisan kamera macet, aplikasi kiosk tidak ikut mati. Setiap perintah
   punya batas waktu; helper menjawab `timeout`/`busy`, bukan menggantung.
2. WIA/COM butuh apartment STA dengan pompa pesan. Di sini itu terisolasi di
   satu thread khusus, tidak mengganggu event loop Flutter.
3. Crash pada driver WIA hanya menjatuhkan `sony_camera_helper.exe`; kiosk
   tinggal degradasi ke `windowsCamera` dan sesi pelanggan tetap jalan.

## Status hak cipta

Kode di folder ini **ditulis sendiri** berdasarkan:

- *Camera Control PTP 3 Reference* (spesifikasi protokol Sony)
- Dokumentasi Microsoft `IWiaItemExtras::Escape` (transport)

Program contoh Sony **tidak** disalin ke dalam produk. *Camera Control PTP
Example Instruction Manual* menyatakan contoh tersebut tidak boleh dipakai di
dalam produk, jadi contoh hanya dipakai sebagai rujukan pemahaman selama POC.
Paket berlisensi Sony disimpan di luar repo (`E:\sony-crc`).

## Build

Butuh CMake ≥ 3.20 dan Visual Studio Build Tools (Desktop development with
C++). **Tidak** butuh MFC atau ATL, jadi toolset apa pun yang terpasang bisa
dipakai — ini sengaja berbeda dari program contoh Sony yang mengunci ke v141.

```
tools\sony_camera_helper\build.bat
```

Hasil: `tools\sony_camera_helper\build\Release\sony_camera_helper.exe`
(runtime C++ ditaut statis, jadi tidak perlu VC++ redistributable).

## Pemakaian

```
sony_camera_helper.exe --list
sony_camera_helper.exe --selftest --verbose
sony_camera_helper.exe --serve --port 45455 --out-dir "C:\SnapTechBooth\captures"
```

Opsi lengkap: `sony_camera_helper.exe --help`.

## Protokol socket

TCP di `127.0.0.1:<port>`. Satu permintaan = satu baris JSON, satu balasan =
satu baris JSON. Selalu ada field `ok` (boolean); saat gagal ada `error`
(kode stabil) dan `detail` (teks untuk manusia).

### connect

```json
{"cmd":"connect"}
{"cmd":"connect","ok":true,"already_connected":false,"device":"ZV-E10","device_id":"{...}","af_status":1,"af_label":"unlock","af_focused":false,"shooting_file_info":0,"file_ready":false,"pending_files":0}
```

### status

```json
{"cmd":"status"}
{"cmd":"status","connected":true,"ok":true,"device":"ZV-E10","device_id":"{...}","af_status":2,"af_label":"afs_focused","af_focused":true,"shooting_file_info":0,"file_ready":false,"pending_files":0}
```

Kalau kamera berhenti menjawab, `status` mengembalikan `ok:false` dengan
`error:"status_read_failed"` **dan** `connected:false` — helper tidak pernah
melaporkan kamera siap padahal sudah tidak.

### capture

```json
{"cmd":"capture","path":"C:\\SnapTechBooth\\captures\\shot.jpg"}
{"cmd":"capture","ok":true,"af_wait_ms":412,"file_wait_ms":880,"elapsed_ms":1503,"af_status":2,"af_label":"afs_focused","af_timed_out":false,"path":"C:\\...\\shot.jpg","bytes":13112834,"width":6000,"height":4000,"camera_filename":"DSC05118.JPG"}
```

`path` opsional; tanpa itu helper memakai `--out-dir`. Bisa juga menimpa
`af_mode`, `af_timeout_ms`, `capture_timeout_ms` per permintaan.

### disconnect / ping / shutdown

```json
{"cmd":"disconnect"}
{"cmd":"ping"}
{"cmd":"shutdown"}
```

### Kode error

| Kode | Arti |
| --- | --- |
| `no_camera` | tidak ada kamera WIA yang cocok |
| `connect_failed` | urutan SDIO_Connect ditolak kamera |
| `not_connected` | `capture`/`status` dipanggil sebelum `connect` |
| `s1_failed` / `s2_failed` | kamera menolak perintah tombol rana |
| `af_timeout` | AF tidak mengunci sampai batas waktu |
| `af_failed` | AF melaporkan gagal fokus (kontras rendah) |
| `status_read_failed` | pembacaan status kamera gagal di tengah jalan |
| `capture_timeout` | kamera tidak melaporkan berkas hasil |
| `transfer_failed` | GetObjectInfo/GetObject gagal |
| `transfer_corrupt` | penanda JPEG SOI/EOI tidak ditemukan |
| `write_failed` | penulisan berkas ke disk gagal |
| `busy` | perintah sebelumnya masih berjalan |
| `timeout` | lapisan kamera tidak merespons dalam `--command-timeout` |
| `unauthorized` | `--token` diaktifkan tapi token salah/tidak ada |
| `bad_request` | baris bukan JSON valid atau `cmd` tidak dikenal |

## Urutan capture

1. `SDIO_ControlDevice(0xD2C1 S1, DOWN)` — setengah tekan.
2. Baca **Focus Indication (0xD213)** berulang sampai bernilai `0x02`
   (AF-S terkunci) atau `0x06` (AF-C terkunci), atau sampai `--af-timeout`.
3. `SDIO_ControlDevice(0xD2C2 S2, DOWN)`, tahan `--s2-hold` ms, lalu `UP`.
4. `S1 UP` — lepas setengah tekan (juga di semua jalur gagal).
5. Baca **Shooting File Info (0xD215)** berulang sampai MSB (`0x8000`) menyala.
6. `GetObjectInfo(0xFFFFC001)` lalu `GetObject(0xFFFFC001)`.
7. Validasi SOI/EOI, tulis ke `<path>.part`, lalu `MoveFileEx` atomik.

### Soal "polling" dan "delay"

- **Tidak ada delay tebakan yang menggantikan status AF.** Langkah 2 dan 5
  menunggu properti status kamera yang sebenarnya. Satu-satunya `Sleep` di
  jalur capture adalah `--s2-hold` (durasi tahan tombol rana) dan jeda antar
  pembacaan status (`--poll-interval`).
- **Polling di sini adalah mekanisme resmi, bukan jalan pintas.** *Camera
  Control PTP 3 Reference* (bagian Overview) menyatakan Initiator sebaiknya
  **tidak** memakai PTP vendor event karena model kamera lama tidak menjamin
  semua event terkirim, dan Initiator **harus** membaca properti (status)
  Responder secara berkala memakai `SDIO_GetAllExtDevicePropInfo`. Transport
  WIA `Escape` juga tidak menyediakan kanal event sama sekali.

## Fokus manual

`--af-mode skip` melewati S1 sepenuhnya (untuk lensa manual focus).
`--af-mode prefer` tetap menjepret walau AF tidak mengunci, tetapi balasan
selalu memuat `"af_timed_out":true` — helper tidak pernah menyembunyikan
kegagalan fokus.

## Batasan yang diketahui

- Satu klien pada satu waktu (kiosk memang satu proses).
- Live view belum diimplementasikan; preview tetap lewat capture card HDMI.
  Kegagalan helper **tidak boleh** mematikan preview HDMI.
- Kamera harus di `USB Connection = PC Remote` dan tidak boleh dipegang
  driver lain (libusbK dari Imaging Edge akan memblokir WIA).
