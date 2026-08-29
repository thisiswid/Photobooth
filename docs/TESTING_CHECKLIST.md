# 📋 SNAPTECH PHOTOBOOTH — MASTER TESTING CHECKLIST & MATRIX

Dokumen ini berisi panduan pengujian menyeluruh (Quality Assurance & End-to-End Testing) untuk seluruh alur aplikasi Kiosk Customer, Integrasi Hardware (Kamera & Printer), Sistem Timer, Pembayaran QRIS, dan Admin Panel Backend.

---

## 📌 Format Status Pengujian
- `[ ]` : Belum Diuji
- `[x]` : Berhasil / Passed
- `[!]` : Ada Bug / Perlu Diperbaiki

---

## 1. Setup, Provisioning & Branding Tenant

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| PRV-01 | Pairing Device Baru | Masukkan Device Key valid di layar `/provisioning` | Konfigurasi cafe berhasil diunduh, logo & nama tenant tersimpan di secure storage | `[ ]` | |
| PRV-02 | Validasi Device Key Salah | Masukkan Device Key acak / salah | Muncul pesan error "Device Key tidak ditemukan" & tetap di layar setup | `[ ]` | |
| PRV-03 | Cache Offline Config | Matikan koneksi internet setelah pairing, lalu restart app | Aplikasi tetap dapat berjalan menggunakan cache lokal `TenantConfig` | `[ ]` | |
| PRV-04 | Unpair Device | Buka Kiosk Settings via PIN > pilih tombol "Unpair Device" | Cache terhapus dan aplikasi kembali ke layar setup `/provisioning` | `[ ]` | |
| PRV-05 | Tampilan Nama Tenant Halaman Awal | Buka Welcome Screen saat aplikasi start | Menampilkan **Nama Cafe Tenant** (bukan *Lumabooth*) sebagai judul utama | `[ ]` | |
| PRV-06 | Tampilan Logo Cafe | Cek logo di Welcome Screen & Customer Header | Menampilkan logo custom cafe tenant (atau default logo jika logo kosong) | `[ ]` | |
| PRV-07 | Custom Theme Color | Ganti warna tema primer cafe di database/admin | Warna aksen, border, dan tombol di aplikasi otomatis mengikuti warna tenant | `[ ]` | |

---

## 2. Welcome Screen & Kiosk Access

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| WLC-01 | Background Live Camera Preview | Buka Welcome Screen | Background menampilkan live video dari kamera tablet/kiosk secara halus | `[ ]` | |
| WLC-02 | Status Indikator Online | Amati badge status di pojok kiri atas | Titik hijau bertuliskan "ONLINE" tampil jelas | `[ ]` | |
| WLC-03 | Emergency Gesture Tap 5x | Ketuk logo lingkaran di tengah sebanyak 5 kali berturut-turut | Muncul popup dialog "Akses Pengelola Kiosk" dengan input PIN 4 digit | `[ ]` | |
| WLC-04 | Validasi PIN Admin Kiosk | Masukkan PIN salah (misal: 9999), lalu coba PIN default (1234) | PIN salah memunculkan SnackBar error; PIN benar (1234) membuka Device Settings | `[ ]` | |
| WLC-05 | Tombol Mulai Sesi Foto | Tekan tombol utama "MULAI SESI FOTO" | Navigasi berpindah secara mulus ke layar Panduan Tutorial (`/tutorial`) | `[ ]` | |
| WLC-06 | Reset Sesi Otomatis | Masuk ke Welcome Screen dari kondisi apapun | Sesi sebelumnya di-reset total, tidak ada state/timer yang tertinggal | `[ ]` | |

---

## 3. Tutorial Screen (Panduan 5 Langkah)

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| TUT-01 | Tampilan 5 Kotak Panduan | Buka layar `/tutorial` | Menampilkan 5 kotak langkah berurutan (Bayar, Frame, Foto, Filter, Cetak) | `[ ]` | |
| TUT-02 | Dynamic Pricing Label | Periksa harga di tombol "LANJUT KE PEMBAYARAN" | Harga sesuai konfigurasi cafe (contoh: `Rp 25.000` atau custom pricing) | `[ ]` | |
| TUT-03 | Brand Lockup Header | Periksa bagian atas layar | Menampilkan logo dan format `[Nama Cafe] Photobooth` | `[ ]` | |
| TUT-04 | Tanpa Timer Chip | Amati pojok kanan atas layar tutorial | **TIDAK ADA** chip timer `00:00` yang muncul sebelum pembayaran | `[ ]` | |
| TUT-05 | Navigasi ke Pembayaran | Tekan tombol "LANJUT KE PEMBAYARAN" | Aplikasi berpindah ke halaman QRIS (`/payment`) | `[ ]` | |

---

## 4. Payment Flow & QRIS

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| PAY-01 | Generate Dinamis QRIS | Masuk ke layar `/payment` | QRIS ter-generate dengan nominal yang tepat dan order ID terbit | `[ ]` | |
| PAY-02 | Polling Status Pembayaran | Lakukan pembayaran via e-wallet (atau gunakan Modal Simulator "Simulate Success") | Kiosk otomatis mendeteksi status "PAID" dalam 2-3 detik tanpa refresh | `[ ]` | |
| PAY-03 | Countdown Timeout Pembayaran | Biarkan halaman pembayaran selama waktu timeout (default: 180s) | Timer pembayaran menghitung mundur; saat 0 otomatis kembali ke Welcome | `[ ]` | |
| PAY-04 | Modal Simulator Pembayaran | Tekan tombol simulator (lingkungan dev/staging) > pilih status | Simulasi Success memulai sesi foto; Simulasi Failed memunculkan feedback gagal | `[ ]` | |
| PAY-05 | Inisialisasi Sesi Saat Sukses | Selesaikan pembayaran | Session model aktif, timer sesi 5-10 menit mulai berjalan, pindah ke `/frame` | `[ ]` | |

---

## 5. Session Lifecycle & Timer Management

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| TIM-01 | Timer Chip Berjalan | Masuk ke layar Frame Selection setelah bayar | Chip timer di pojok kanan atas menghitung mundur (misal: `09:59` → `09:58`) | `[ ]` | |
| TIM-02 | Peringatan Sisa Waktu (< 60s) | Biarkan sisa waktu timer berada di bawah 60 detik | Chip timer berubah warna menjadi **Merah (Warning Style)** | `[ ]` | |
| TIM-03 | Waktu Sesi Habis Otomatis | Biarkan timer sesi mencapai `00:00` di layar frame/kamera/filter | Aplikasi otomatis redirect ke Welcome Screen, sesi di-reset penuh | `[ ]` | |
| TIM-04 | Hilangnya Timer 00:00 di Welcome | Amati layar Welcome setelah waktu sesi habis | Chip timer merah `00:00` **TIDAK TERTINGGAL** di layar Welcome | `[ ]` | |
| TIM-05 | Hilangnya Timer di Sesi Baru | Mulai kembali dari Welcome ke Tutorial & Payment | Layar Tutorial & Payment bersih tanpa timer `00:00` merah | `[ ]` | |
| TIM-06 | Persistence Timer Antar Layar | Navigasi dari Frame → Camera → Preview → Filter | Hitungan detik timer tetap sinkron dan konsisten di seluruh layar | `[ ]` | |

---

## 6. Frame Selection Screen

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| FRM-01 | Grid Frame dari Backend | Buka layar `/frame` | Menampilkan seluruh template frame aktif yang terikat pada event cafe | `[ ]` | |
| FRM-02 | Seleksi Frame | Ketuk salah satu kartu frame | Frame terpilih memiliki border highlight emas / tema cafe | `[ ]` | |
| FRM-03 | Simpan Konfigurasi Pose | Pilih frame dengan 4 slot foto lalu tekan Lanjut | Session menyimpan `frameId` dan target total foto (misal: 4 pose) | `[ ]` | |
| FRM-04 | Validasi Sebelum Lanjut | Jangan pilih frame lalu coba lanjut | Tombol lanjut disabled / mewajibkan customer memilih salah satu frame | `[ ]` | |

---

## 7. Camera & Photo Capture Screen

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| CAM-01 | Live View Kamera | Masuk ke layar `/camera` | Kamera live view tampil jernih dengan rasio yang tepat (tanpa distorsi) | `[ ]` | |
| CAM-02 | Deteksi Sony PTP Camera | Hubungkan kamera Sony via USB/PTP | Layar mendeteksi dan beralih ke Sony Camera Service jika tersedia | `[ ]` | |
| CAM-03 | Tombol Mirror Toggle | Tekan tombol cermin (Mirror ON/OFF) | Preview video membalik secara horizontal (flip horizontal) | `[ ]` | |
| CAM-04 | Countdown Timer Pengambilan Foto | Tekan tombol Shutter / Ambil Foto | Tampil angka hitung mundur besar (5, 4, 3, 2, 1) dengan animasi shutter flash | `[ ]` | |
| CAM-05 | Progress Slot Pose | Ambil foto pose ke-1, ke-2, dst. | Indikator slot pose terisi bertahap sesuai jumlah slot frame (misal: 1/4, 2/4) | `[ ]` | |
| CAM-06 | Batas Retake Per Pose | Coba lakukan retake pada pose yang sama | Retake maksimal 2x per slot pose sesuai aturan bisnis | `[ ]` | |
| CAM-07 | Otomatis Lanjut ke Preview | Selesaikan seluruh slot pose (misal: 4/4) | Kiosk otomatis berpindah ke layar Photo Preview (`/preview`) | `[ ]` | |

---

## 8. Photo Preview Screen

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| PRV-01 | Tampilan Galeri Pose | Buka layar `/preview` | Seluruh hasil jepretan foto tampil rapi dalam thumbnail grid | `[ ]` | |
| PRV-02 | Tombol Ambil Ulang Semua | Tekan tombol "AMBIL ULANG SEMUA" | Foto dikosongkan, sesi foto tetap aktif (tanpa bayar lagi), kembali ke `/camera` | `[ ]` | |
| PRV-03 | Lanjut ke Filter | Tekan tombol "LANJUT PILIH FILTER" | Navigasi berpindah ke layar Filter Selection (`/filter`) | `[ ]` | |

---

## 9. Filter Selection Screen

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| FLT-01 | Daftar Filter dari Database | Buka layar `/filter` | Menampilkan pilihan filter aktif (Normal, Warm Vintage, B&W, Sepia, Soft Glow, dll.) | `[ ]` | |
| FLT-02 | Real-time Preview Filter | Pilih filter berbeda satu per satu | Tampilan foto preview strip berubah secara instan sesuai efek filter | `[ ]` | |
| FLT-03 | Tombol Selesai & Generate | Tekan tombol "SELESAI & PROSES HASIL" | Filter tersimpan di sesi dan proses kompilasi foto strip dimulai | `[ ]` | |

---

## 10. Final Result, QR Download & Print Screen

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| RES-01 | Render Photo Strip & GIF | Tunggu layar `/result` selesai memproses | Menampilkan gambar final photo strip & animasi GIF hasil sesi foto | `[ ]` | |
| RES-02 | QR Code Download Pelanggan | Scan QR Code yang tampil di layar menggunakan HP | Membuka halaman galeri customer di browser (`https://snaptechbooth.my.id/d/{token}`) | `[ ]` | |
| RES-03 | Download Foto Strip & GIF di HP | Tekan tombol download di halaman web browser HP | File JPG strip resolusi tinggi & GIF berhasil terunduh ke galeri HP | `[ ]` | |
| RES-04 | Cetak Foto Fisik (Printer Epson L8050) | Tekan tombol "CETAK FOTO" (atau auto-print) | Printer merespons dan mencetak foto strip pada kertas 4R tanpa error | `[ ]` | |
| RES-05 | Auto-return ke Welcome | Biarkan layar result selama timeout (default: 45 detik) atau tekan tombol Selesai | Sesi di-reset penuh dan kiosk kembali ke Welcome Screen dalam kondisi siap pakai | `[ ]` | |

---

## 11. Kiosk Settings & Hardware Management

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| SET-01 | Test Print Halaman Diagnostik | Buka Kiosk Settings > Tab Printer > Tekan "Print Test Page" | Printer mencetak halaman tes tanpa menghabiskan banyak tinta | `[ ]` | |
| SET-02 | Ganti Paper Size & Orientasi | Ubah ukuran kertas ke 4R / A4 atau Landscape / Portrait | Konfigurasi tersimpan dan diterapkan pada pencetakan berikutnya | `[ ]` | |
| SET-03 | Telemetri Heartbeat | Cek log backend saat printer / kamera offline | Backend menerima telemetry alert dan mencatat status di tabel `error_logs` | `[ ]` | |
| SET-04 | Exit App / Tutup Kiosk | Masukkan PIN Admin di Kiosk Settings > pilih "Keluar Aplikasi" | Aplikasi menutup mode immersive/kiosk dengan aman | `[ ]` | |

---

## 12. Backend Admin Panel (Laravel Filament)

| ID | Fitur / Skenario Uji | Langkah Pengujian | Hasil yang Diharapkan | Status | Catatan |
|---|---|---|---|---|---|
| ADM-01 | Login Super Admin & Cafe Admin | Login dengan kredensial masing-masing role | Super Admin dapat melihat semua tenant; Cafe Admin hanya melihat data cafenya | `[ ]` | |
| ADM-02 | Manajemen Template Frame | Tambah / edit frame dengan editor koordinat slot | Frame tersimpan dan otomatis muncul di Kiosk Cafe terkait | `[ ]` | |
| ADM-03 | Pengaturan Timer Cafe | Buka menu Timer Settings > ubah durasi sesi / countdown | Konfigurasi timer sinkron ke perangkat Kiosk saat sync/refresh config | `[ ]` | |
| ADM-04 | Monitoring Perangkat & Heartbeat | Buka menu Devices di Admin Panel | Status device (Active, Last Seen, IP Address, App Version) terupdate real-time | `[ ]` | |
| ADM-05 | Cleanup Cron Job | Jalankan `php artisan photobooth:cleanup` | Menghapus data/foto kedaluwarsa (> 30 hari) secara otomatis | `[ ]` | |

---

## ✍️ Catatan Hasil & Rekomendasi Pengujian
| Tanggal | Penguji | Modul / Fitur | Temuan / Catatan | Tindak Lanjut |
|---|---|---|---|---|
| - | - | - | - | - |
| - | - | - | - | - |
