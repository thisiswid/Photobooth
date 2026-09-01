# PRD — Migrasi Kiosk LumaBooth dari Android ke Windows

| | |
|---|---|
| **Status** | Disetujui untuk Fase 0 (spike) |
| **Tanggal** | 2026-09-01 |
| **Cakupan** | Aplikasi kiosk sisi pelanggan saja |
| **Tidak termasuk** | Backend Laravel, Admin Panel Filament, skema database |

---

## 1. Ringkasan Eksekutif

Aplikasi kiosk LumaBooth saat ini berjalan di tablet Android (Lenovo Legion
Y700). Ketiga jalur hardware yang menopang produk ini — cetak, shutter kamera,
dan preview — semuanya berjalan di atas workaround, bukan API resmi, karena
Android secara desain mencegah aplikasi mengendalikan perangkat tanpa pengawasan
manusia.

Dokumen ini mengusulkan pemindahan aplikasi kiosk ke Windows desktop, di mana
ketiga jalur tersebut punya API resmi yang didukung vendor. Backend, admin panel,
dan seluruh alur pelanggan tidak berubah.

**Yang tidak berubah bagi pelanggan:** alur dari Welcome sampai Selesai persis
sama. Migrasi ini tidak terlihat oleh pelanggan — itu memang tujuannya.

---

## 2. Latar Belakang & Masalah

### 2.1 Cetak — masalah utama

`android.print.PrintManager.print()` **selalu** membuka print spooler UI. Android
tidak menyediakan API silent print, dan ini bukan bug melainkan keputusan desain.

Solusi yang berjalan sekarang:

```text
PrintManager → Epson Print Service → dialog preview muncul
                                   → KioskAutoPrintService (Accessibility)
                                     menekan tombol Print secara otomatis
                                   → overlay TYPE_APPLICATION_OVERLAY
                                     menutupi dialog dari mata pelanggan
```

Konsekuensi operasional: Android dapat mematikan Accessibility Service setelah
reboot atau update sistem. Pengecekan panel AUTO-PRINT HELPER sudah masuk
checklist buka-kios harian. Ini beban permanen pada mesin yang seharusnya jalan
tanpa penjaga.

Referensi lengkap: `print_architecture.md` (memori proyek).

### 2.2 Shutter kamera

`SonyPtpCameraManager.kt` memicu shutter dengan menulis properti vendor Sony
`0xD2C1` (half-press) dan `0xD2C2` (full-press) — nilai hasil rekayasa balik dari
libgphoto2, bukan dari dokumentasi Sony. Di sekelilingnya ada 1,1 detik delay
yang di-hardcode, termasuk `delay(500)` yang hanya **menebak** bahwa autofocus
sudah lock.

Dua risiko: foto lembut ketika AF butuh lebih dari 500 ms, dan seluruh jalur bisa
patah diam-diam kalau firmware kamera diperbarui.

### 2.3 Preview

Membutuhkan fork `flutter_uvc_camera` yang dipatch sendiri di `packages/`, plus
workaround penomoran generasi view untuk mengatasi bug single-view factory di
plugin upstream.

### 2.4 Skala

Arsitektur produk ini dibangun untuk armada: `DEVICE PAIRING KEY`,
`ProvisioningService`, heartbeat telemetri tiap 60 detik ke dashboard admin,
multi-tenant. Ritual setup manual per unit di Android (aktifkan Accessibility,
beri izin overlay, verifikasi ulang tiap reboot) tidak akan menskala melewati
beberapa unit.

---

## 3. Tujuan

| ID | Tujuan | Ukuran keberhasilan |
|---|---|---|
| G-1 | Silent print sejati | 0 dialog cetak muncul dalam 200 sesi berturut-turut |
| G-2 | Status printer terbaca | Kertas habis terdeteksi dan sampai ke dashboard ≤ 60 detik |
| G-3 | Shutter di atas API resmi | Tidak ada opcode vendor hasil rekayasa balik di jalur produksi |
| G-4 | Setup unit baru yang berulang | Dari mesin kosong sampai siap jual ≤ 30 menit, tanpa langkah manual di luar installer |

## 4. Non-Tujuan

Hal-hal berikut **tidak** akan diperbaiki oleh migrasi ini, dan tidak boleh
dijadikan alasan atau ukuran keberhasilan:

| Non-tujuan | Alasan |
|---|---|
| Menaikkan kualitas cetak | Plafonnya ada di kanvas template backend `1333x2000` (333 DPI di 4x6), bukan di OS. Perubahan terpisah. |
| Mempercepat pemrosesan gambar | `img.decodeImage` di package `image` itu pure Dart. Mini PC murah belum tentu menang lawan Snapdragon Y700. |
| Mempercepat transfer foto | Dibatasi USB 2.0 pada ZV-E10. Peningkatan nyata tapi kecil (~2-3 detik → <1 detik). |
| Mengubah alur atau desain UI pelanggan | Di luar cakupan. Hanya kalibrasi ukuran yang diizinkan. |
| Memindahkan backend atau admin panel | Sudah berkomunikasi lewat HTTP, tidak terpengaruh OS kiosk. |

---

## 5. Pengguna & Dampak

| Pengguna | Dampak |
|---|---|
| **Pelanggan** | Tidak ada perubahan alur. Dialog cetak yang selama ini ditutupi overlay tidak lagi ada sama sekali. Sesi tidak lagi bisa macet menunggu tombol ditekan. |
| **Operator kios** | Checklist harian berkurang: tidak ada lagi verifikasi Accessibility Service. Status printer terlihat sebelum kertas benar-benar habis. |
| **Admin / tenant** | Telemetri lebih kaya (status printer sesungguhnya, bukan tebakan). Unit baru bisa di-onboard tanpa kunjungan teknis. |
| **Tim pengembang** | Kehilangan 1.384 baris Kotlin workaround. Debugging lewat remote desktop, bukan ADB. |

---

## 6. Persyaratan

### 6.1 Fungsional (WR)

- **WR-01** Aplikasi kiosk berjalan fullscreen di Windows 11 Pro tanpa taskbar, tanpa border, tanpa notifikasi sistem terlihat.
- **WR-02** Mencetak ke Epson L8050 tanpa dialog apa pun muncul di layar.
- **WR-03** Cetak menghasilkan 4R borderless sesuai setelan tersimpan (`paperSize`, `borderless`, `quality`, margin).
- **WR-04** Menjaga garansi 1 aksi = 1 PrintJob = 1 lembar, dilindungi lock terhadap eksekusi ganda.
- **WR-05** Membaca status printer dari spooler: siap, kertas habis, tinta habis, offline, error.
- **WR-06** Mengirim status printer di payload `HeartbeatService`.
- **WR-07** Menampilkan live preview dari HDMI capture card pada 1920x1080.
- **WR-08** Memicu shutter Sony ZV-E10 lewat Camera Remote SDK resmi.
- **WR-09** Menunggu properti AF lock sebelum melepas shutter — bukan delay tetap.
- **WR-10** Menerima file foto full-res langsung dari SDK ke penyimpanan lokal.
- **WR-11** Jatuh otomatis ke mode `hdmiOnly` bila jalur PTP gagal atau terputus saat runtime, tanpa mematikan sesi pelanggan.
- **WR-12** Melaporkan degradasi mode capture lewat heartbeat.
- **WR-13** Menyediakan installer sekali-jalan yang memasang aplikasi, VC++ Redistributable, driver printer, autostart, dan autologin.
- **WR-14** Mempertahankan alur provisioning yang ada (`DEVICE PAIRING KEY` + API Base URL) tanpa perubahan pada backend.
- **WR-15** Mendukung pembaruan aplikasi jarak jauh melalui field versi di heartbeat.
- **WR-16** Memblokir jalan keluar dari aplikasi: `Alt+F4`, tombol Windows, dan pintasan sistem lain.

### 6.2 Non-fungsional (NFR)

- **NFR-01** Kiosk berjalan **7 hari berturut-turut** tanpa intervensi manual.
- **NFR-02** Waktu boot dari listrik menyala sampai layar Welcome siap ≤ 90 detik.
- **NFR-03** Windows Update tidak boleh me-reboot mesin di dalam jam operasional.
- **NFR-04** Kehilangan daya mendadak tidak boleh merusak sesi yang sedang berjalan maupun filesystem (mitigasi: UPS).
- **NFR-05** Build Android harus tetap bisa di-build dan berjalan sampai keputusan pensiun tablet diambil.
- **NFR-06** Satu codebase. Tidak ada fork permanen.

### 6.3 Paritas fitur

Seluruh FR-01 sampai FR-29 di `docs/requirements/01-functional-requirements.md`
harus tetap terpenuhi. Rinciannya di
[Matriks Paritas Fitur](01-feature-parity-matrix.md).

---

## 7. Fase & Gerbang

| Fase | Isi | Gerbang |
|---|---|---|
| 0 | Spike cetak di proyek Flutter kosong | ⛔ **Wajib lulus sebelum apa pun dimulai** |
| 1 | Kerangka Windows, fullscreen, provisioning | — |
| 2 | Jalur cetak + status printer | — |
| 3 | Kamera via capture card (`hdmiOnly`) | ✅ **Sudah bisa produksi di 1080p** |
| 4 | Shutter Sony via Camera Remote SDK | ⛔ **Cek lisensi & dukungan model dulu** |
| 5 | Settings & diagnostik | — |
| 6 | Kalibrasi layar sentuh | — |
| 7 | Packaging & penguncian kiosk | — |

Estimasi total: **4-6 minggu**, dengan variansi terbesar di Fase 4.

Instruksi kerja rinci untuk AI agent: [`../windows-migration-prompt.md`](../windows-migration-prompt.md)

---

## 8. Asumsi & Ketergantungan

| | Catatan |
|---|---|
| Driver Epson L8050 untuk Windows | Diasumsikan tersedia dan menangani rasterisasi ESC/P-R. **Diverifikasi di Fase 0.** |
| Lisensi Sony Camera Remote SDK | Ketentuan penggunaan komersial **belum diverifikasi**. Gerbang Fase 4. |
| Dukungan model ZV-E10 di SDK terbaru | **Belum diverifikasi.** Gerbang Fase 4. |
| Resolusi capture card di Windows | Diasumsikan 1080p dapat dipaksa. Diverifikasi di Fase 3. |
| Windows 11 **Pro** | Wajib untuk Shell Launcher & Group Policy. Home tidak cukup. |
| UPS | Wajib. Tablet punya baterai bawaan; mini PC tidak. |

---

## 9. Keputusan yang Masih Terbuka

1. **Pensiun tablet Android** — kapan build Android berhenti dipelihara. Sampai
   keputusan ini diambil, seluruh kode Kotlin dan stack IPP tetap di repo.
2. **Jumlah unit dalam 12 bulan** — menentukan seberapa besar investasi
   penguncian kiosk dan otomasi instalasi yang sepadan.
3. **Nasib stack IPP** (`lib/core/services/ipp/`, 1.226 baris) — tidak terpakai
   untuk L8050, tetapi siap pakai bila suatu saat pindah ke printer ber-AirPrint.
   Rekomendasi: simpan, jangan hapus.
