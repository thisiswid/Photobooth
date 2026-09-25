<?php

// Shared by the page tours and documentation. Screenshot paths are relative to public/.
return [
    'admin' => [
        'dashboard' => [
            'title' => 'Dashboard',
            'intro' => 'Mulai dari sini untuk memantau kondisi photobooth dan aktivitas cafe.',
            'steps' => ['Baca kartu ringkasan untuk melihat sesi dan pendapatan.', 'Gunakan grafik sesi untuk melihat aktivitas, lalu periksa log error terbaru.', 'Baca informasi saldo dan penarikan sebelum mengajukan pencairan dana.'],
            'shot' => 'Dashboard lengkap: kartu statistik, grafik sesi, dan informasi saldo.',
        ],
        'cafes' => [
            'title' => 'Pengaturan Cafe & Harga',
            'intro' => 'Kelola identitas cafe, harga sesi, kontak, serta fitur yang tersedia di kiosk.',
            'steps' => ['Pilih Ubah Harga & Info pada cafe.', 'Isi nama, harga sesi, logo, dan kontak penanggung jawab.', 'Atur tombol setting kiosk dan fitur AI sesuai kebutuhan, lalu simpan.'],
            'shot' => 'Form pengaturan cafe yang menampilkan harga, logo, dan fitur kiosk.',
        ],
        'events' => [
            'title' => 'Event',
            'intro' => 'Event menghubungkan perangkat dengan konten photobooth yang digunakan.',
            'steps' => ['Buat event dengan nama dan deskripsi yang mudah dikenali.', 'Atur waktu mulai, selesai, dan status aktif.', 'Gunakan event yang sama pada perangkat, frame, dan konten layar yang terkait.'],
            'shot' => 'Form event dengan nama, jadwal, dan sakelar aktif.',
        ],
        'devices' => [
            'title' => 'Perangkat / Mesin Kiosk',
            'intro' => 'Daftarkan mesin dan hubungkan aplikasi menggunakan Device Pairing Key.',
            'steps' => ['Tambahkan nama mesin, event, platform, dan status perangkat.', 'Salin Device Pairing Key ke layar Aktivasi Mesin pada aplikasi.', 'Pantau heartbeat dan waktu aktivasi. Reset Aktivasi App digunakan saat perlu memasangkan ulang mesin.'],
            'shot' => 'Daftar perangkat dengan event, heartbeat, dan status aktivasi; samarkan pairing key.',
        ],
        'frames' => [
            'title' => 'Frame',
            'intro' => 'Siapkan bingkai foto yang dapat dipilih pelanggan pada event ini.',
            'steps' => ['Pilih Impor dari Master Library atau Upload Frame Kustom Sendiri.', 'Untuk frame kustom, pilih event, nama, layout, jumlah pose, dan unggah desain frame.', 'Gunakan kanvas pensil untuk mengatur area transparan. Periksa preview dan status aktif sebelum menyimpan.'],
            'shot' => 'Editor frame dengan desain, area foto transparan, layout, dan jumlah pose.',
        ],
        'filters' => [
            'title' => 'Filter',
            'intro' => 'Atur pilihan efek warna foto untuk pelanggan.',
            'steps' => ['Pilih event dan beri nama filter.', 'Pilih tipe preset; tambahkan thumbnail jika diperlukan.', 'Atur urutan tampilan dan aktifkan filter, lalu simpan.'],
            'shot' => 'Form filter berisi preset, thumbnail, urutan, dan status aktif.',
        ],
        'screen-configs' => [
            'title' => 'Screen Content',
            'intro' => 'Sesuaikan layar sambutan dan tutorial pelanggan di aplikasi kiosk.',
            'steps' => ['Pilih event dan tipe layar Welcome atau Tutorial.', 'Isi judul, deskripsi, background, dan teks tombol. Untuk Tutorial, isi gambar serta urutan langkah.', 'Periksa konten sebelum menggunakan aksi Publish atau Activate yang tersedia pada daftar.'],
            'shot' => 'Form konten Tutorial dengan background dan daftar Tutorial Steps.',
        ],
        'timer-settings' => [
            'title' => 'Pengaturan Timer',
            'intro' => 'Atur durasi pengalaman pelanggan dari pembayaran sampai layar hasil.',
            'steps' => ['Buat atau edit profil timer dan tentukan event yang terkait.', 'Sesuaikan countdown kamera, batas sesi, batas pembayaran, retake, dan reset layar hasil.', 'Aktifkan profil dan uji alur di kiosk agar pelanggan punya waktu yang cukup.'],
            'shot' => 'Form timer dengan countdown kamera dan batas waktu tiap tahap.',
        ],
        'vouchers' => [
            'title' => 'Voucher',
            'intro' => 'Buat promo untuk cafe dengan aturan diskon dan batas penggunaan.',
            'steps' => ['Isi nama promo, kode voucher, jenis, dan nilai diskon.', 'Atur minimum transaksi, batas diskon, event, kuota, dan batas per perangkat sesuai kebutuhan.', 'Tentukan masa berlaku dan status aktif. Simpan lalu uji kode pada layar pembayaran kiosk.'],
            'shot' => 'Form voucher yang menampilkan diskon, kuota, dan masa berlaku.',
        ],
        'voucher-redemptions' => [
            'title' => 'Pemakaian Voucher',
            'intro' => 'Lacak penggunaan promo pada sesi dan pembayaran pelanggan.',
            'steps' => ['Cari kode voucher atau promo pada daftar.', 'Cocokkan potongan, perangkat, sesi, dan pembayaran.', 'Periksa status serta waktu pemakaian saat menelusuri laporan promo.'],
            'shot' => 'Tabel pemakaian voucher berisi potongan, sesi, status, dan waktu.',
        ],
        'sessions' => [
            'title' => 'Sesi Foto',
            'intro' => 'Pantau perjalanan sesi pelanggan dan buka detail untuk menelusuri kendala.',
            'steps' => ['Cari sesi yang ingin diperiksa dan gunakan filter yang tersedia.', 'Buka detail untuk mencocokkan event, perangkat, dan status sesi.', 'Gunakan identitas sesi untuk mencocokkan pembayaran, hasil foto, atau pekerjaan cetak.'],
            'shot' => 'Detail sesi yang memperlihatkan status, perangkat, dan informasi sesi.',
        ],
        'payments' => [
            'title' => 'Pembayaran',
            'intro' => 'Periksa transaksi pelanggan beserta status pembayarannya.',
            'steps' => ['Cari transaksi dan saring berdasarkan status yang tersedia.', 'Buka detail untuk mencocokkan nominal, sesi, dan referensi transaksi.', 'Jika status perlu ditelusuri, periksa juga riwayat Rekonsiliasi Pakasir.'],
            'shot' => 'Detail pembayaran dengan nominal dan status; samarkan informasi pelanggan.',
        ],
        'withdrawals' => [
            'title' => 'Penarikan Dana',
            'intro' => 'Ajukan pencairan saldo dan pantau progresnya.',
            'steps' => ['Periksa ringkasan saldo dan ketentuan penarikan yang ditampilkan.', 'Buat pengajuan, isi jumlah dan rekening tujuan; periksa estimasi dana diterima sebelum mengirim.', 'Pantau status pengajuan dan buka detail untuk melihat catatan atau bukti transfer.'],
            'shot' => 'Form penarikan berisi saldo dipotong, biaya, dan estimasi dana; samarkan rekening.',
        ],
        'results' => [
            'title' => 'Hasil Foto',
            'intro' => 'Temukan hasil sesi pelanggan dan periksa media yang dihasilkan.',
            'steps' => ['Cari hasil yang sesuai dengan sesi pelanggan.', 'Buka detail untuk memeriksa preview dan informasi hasil.', 'Gunakan tautan unduh yang tersedia selama hasil masih tersedia.'],
            'shot' => 'Detail hasil foto dengan preview strip dan informasi unduhan; gunakan foto contoh.',
        ],
        'print-jobs' => [
            'title' => 'Pekerjaan Cetak',
            'intro' => 'Pantau antrean dan hasil proses cetak photobooth.',
            'steps' => ['Periksa status pekerjaan pada daftar dan cari sesi terkait.', 'Buka detail pekerjaan untuk melihat informasi cetak dan kendala.', 'Jika cetak gagal, periksa koneksi printer dan pengaturan printer pada aplikasi kiosk.'],
            'shot' => 'Daftar pekerjaan cetak dengan status dan contoh detail pekerjaan.',
        ],
        'operational-alerts' => [
            'title' => 'Peringatan Operasional',
            'intro' => 'Prioritaskan masalah operasional yang masih aktif.',
            'steps' => ['Periksa level, kategori, dan waktu terakhir masalah terdeteksi.', 'Baca keterangan, lalu cek perangkat atau transaksi yang berkaitan.', 'Gunakan aksi penyelesaian yang tersedia setelah masalah ditangani.'],
            'shot' => 'Tabel peringatan aktif dengan level, kategori, dan keterangan.',
        ],
        'payment-reconciliations' => [
            'title' => 'Rekonsiliasi Pakasir',
            'intro' => 'Lihat hasil pencocokan status transaksi lokal dengan gateway pembayaran.',
            'steps' => ['Cari Order ID transaksi yang ingin ditelusuri.', 'Bandingkan status lokal, status Pakasir, serta nominal tagihan dan gateway.', 'Baca hasil dan keterangan pemeriksaan untuk memahami perbedaannya.'],
            'shot' => 'Tabel rekonsiliasi dengan hasil, status lokal, status gateway, dan nominal.',
        ],
        'users' => [
            'title' => 'Pengguna',
            'intro' => 'Kelola akun yang dapat menggunakan sistem sesuai perannya.',
            'steps' => ['Tambahkan pengguna dengan nama dan email yang benar.', 'Pilih role yang sesuai dan isi password saat membuat akun.', 'Saat mengedit akun, periksa kembali role sebelum menyimpan perubahan.'],
            'shot' => 'Form pengguna dengan nama, email contoh, dan pilihan role; jangan tampilkan password.',
        ],
        'activity-logs' => [
            'title' => 'Log Aktivitas',
            'intro' => 'Telusuri siapa melakukan perubahan dan kapan perubahan terjadi.',
            'steps' => ['Cari aktivitas berdasarkan pengguna atau deskripsi yang tersedia.', 'Cocokkan waktu, aksi, dan pengguna.', 'Buka detail untuk melihat informasi perubahan saat melakukan penelusuran.'],
            'shot' => 'Detail log aktivitas dengan aksi, waktu, dan perubahan data contoh.',
        ],
        'error-logs' => [
            'title' => 'Log Error',
            'intro' => 'Temukan catatan masalah aplikasi untuk membantu pemeriksaan teknis.',
            'steps' => ['Gunakan kategori dan tingkat keparahan untuk mempersempit daftar.', 'Buka Lihat Detail untuk membaca pesan, perangkat, dan waktu kejadian.', 'Sertakan identitas error dan waktu kejadian saat meminta bantuan teknis.'],
            'shot' => 'Detail error dengan tingkat keparahan, kategori, dan pesan contoh.',
        ],
    ],
    'app' => [
        'aktivasi' => ['title' => '1. Aktivasi mesin', 'intro' => 'Hubungkan instalasi aplikasi dengan perangkat milik cafe.', 'steps' => ['Siapkan perangkat dan Device Pairing Key dari admin.', 'Buka aplikasi, masukkan key pada layar aktivasi, lalu tunggu proses pairing.', 'Pastikan identitas cafe benar. Jika lisensi penuh, periksa slot perangkat melalui admin.'], 'shot' => 'Layar aktivasi aplikasi dengan kolom pairing key kosong.'],
        'pengaturan' => ['title' => '2. Pengaturan perangkat', 'intro' => 'Siapkan printer dan kamera sebelum melayani pelanggan.', 'steps' => ['Buka pengaturan perangkat yang tersedia di kiosk.', 'Periksa tab Printer dan Kamera, pilih perangkat yang digunakan, lalu uji perangkat.', 'Tab Perangkat memuat identitas cafe serta opsi ganti key atau lepas perangkat.'], 'shot' => 'Halaman pengaturan dengan tab Printer, Kamera, dan Perangkat.'],
        'welcome' => ['title' => '3. Sambutan & tutorial', 'intro' => 'Pelanggan memulai sesi dari layar sambutan.', 'steps' => ['Tekan tombol mulai di layar sambutan.', 'Ikuti tutorial yang ditampilkan sebelum melanjutkan ke pembayaran.', 'Konten layar ini dikelola melalui Screen Content pada event terkait di admin.'], 'shot' => 'Layar Welcome aplikasi dengan logo cafe dan tombol mulai.'],
        'pembayaran' => ['title' => '4. Pembayaran & voucher', 'intro' => 'Selesaikan pembayaran untuk memulai sesi foto.', 'steps' => ['Periksa harga dan masukkan voucher jika tersedia.', 'Ikuti instruksi pembayaran yang tampil dan selesaikan sebelum batas waktunya.', 'Tunggu konfirmasi aplikasi sebelum melanjutkan ke pemilihan frame.'], 'shot' => 'Layar pembayaran dengan harga, input voucher, dan area QRIS contoh.'],
        'frame' => ['title' => '5. Pilih frame', 'intro' => 'Pilih desain bingkai untuk hasil foto.', 'steps' => ['Lihat pilihan frame yang tersedia pada event.', 'Pilih desain dan periksa jumlah pose yang dibutuhkan.', 'Lanjutkan ke kamera setelah pilihan sesuai.'], 'shot' => 'Layar pilihan frame dengan satu desain terpilih.'],
        'kamera' => ['title' => '6. Ambil foto', 'intro' => 'Ikuti countdown dan ambil pose sesuai frame.', 'steps' => ['Berdiri di area kamera dan periksa preview.', 'Ikuti hitung mundur untuk setiap pose.', 'Gunakan retake jika tersedia sebelum batas waktu berakhir, lalu lanjutkan.'], 'shot' => 'Layar kamera dengan preview, countdown, dan indikator pose; gunakan model yang setuju difoto.'],
        'filter' => ['title' => '7. Pilih filter', 'intro' => 'Sesuaikan tampilan foto sebelum menghasilkan strip akhir.', 'steps' => ['Pilih filter yang tersedia dan periksa preview.', 'Pastikan semua foto sesuai keinginan.', 'Konfirmasi pilihan untuk memproses hasil.'], 'shot' => 'Layar filter dengan preview strip dan pilihan efek warna.'],
        'hasil' => ['title' => '8. Hasil, cetak & unduh', 'intro' => 'Ambil hasil foto sebelum layar kembali ke awal.', 'steps' => ['Periksa strip akhir dan status cetak yang tampil.', 'Pindai QR unduhan dengan ponsel untuk membuka portal hasil.', 'Unduh media yang tersedia sebelum masa akses berakhir. Sesi berikutnya dimulai setelah kiosk kembali ke layar sambutan.'], 'shot' => 'Layar hasil dengan preview strip, status cetak, dan QR contoh.'],
        'portal' => ['title' => '9. Portal unduhan', 'intro' => 'Pelanggan mengakses media melalui tautan QR hasil sesi.', 'steps' => ['Buka tautan dari QR pada ponsel.', 'Pilih media yang tersedia, seperti strip, foto, video, atau GIF.', 'Simpan hasil ke perangkat; jika tautan tidak tersedia, minta operator memeriksa hasil sesi.'], 'shot' => 'Portal unduhan pada ponsel dengan preview dan tombol unduh menggunakan sesi contoh.'],
    ],
];
