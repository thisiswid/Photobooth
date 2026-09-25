<?php

// Each entry: field state-path suffix, heading, explanation.
return [
    'cafes' => [
        ['name', 'Identitas cafe', 'Isi nama dan logo yang mewakili booth Anda.'],
        ['session_price', 'Harga sesi', 'Tentukan harga satu sesi photobooth dalam rupiah. Periksa nilainya sebelum menyimpan.'],
        ['pic_phone', 'Kontak penanggung jawab', 'Lengkapi nama PIC, telepon, email, dan alamat agar informasi operasional mudah ditemukan.'],
        ['show_kiosk_settings', 'Tampilan & fitur kiosk', 'Atur visibilitas tombol setting pada kiosk dan fitur AI sesuai kebutuhan cafe.'],
    ],
    'events' => [
        ['name', 'Nama & deskripsi', 'Beri nama yang mudah dikenali untuk menghubungkan perangkat dan konten ke event ini.'],
        ['starts_at', 'Jadwal event', 'Isi waktu mulai dan selesai sesuai pelaksanaan event.'],
        ['active', 'Status event', 'Periksa status aktif sebelum menyimpan. Gunakan event yang sama saat menyiapkan perangkat dan konten.'],
    ],
    'devices' => [
        ['name', 'Nama mesin', 'Gunakan nama sesuai lokasi mesin agar mudah dibedakan saat memantau perangkat.'],
        ['device_key', 'Kunci pemasangan', 'Simpan perangkat terlebih dahulu, lalu salin Device Pairing Key ini ke layar aktivasi aplikasi kiosk.'],
        ['event_id', 'Event terkait', 'Pilih event yang kontennya akan dipakai oleh mesin ini.'],
        ['platform', 'Platform & status', 'Pilih sistem operasi mesin dan periksa status aktif sebelum menyimpan.'],
    ],
    'frames' => [
        ['event_id', 'Event & nama frame', 'Pilih event tujuan dan isi nama desain yang akan dikenali pelanggan.'],
        ['layout_type', 'Layout foto', 'Pilih tipe layout yang sesuai desain. Periksa urutan pose kolom kanan jika opsi tersebut muncul.'],
        ['pose_count', 'Jumlah pose', 'Tentukan jumlah pose yang perlu diambil kamera untuk frame ini.'],
        ['asset_url', 'Unggah desain', 'Unggah file desain frame, lalu periksa preview dan area transparan untuk foto.'],
        ['layout_config', 'Kanvas pensil', 'Gunakan editor untuk menyiapkan area foto transparan. Periksa hasilnya sebelum menyimpan frame.'],
        ['active', 'Aktifkan frame', 'Pastikan status aktif sesuai kebutuhan agar frame tersedia untuk pelanggan.'],
    ],
    'filters' => [
        ['event_id', 'Event & nama filter', 'Pilih event terkait dan beri nama efek foto.'],
        ['parameters', 'Preset filter', 'Pilih preset efek warna yang ingin ditawarkan di aplikasi.'],
        ['thumbnail_url', 'Thumbnail', 'Tambahkan gambar thumbnail jika diperlukan untuk membantu mengenali filter.'],
        ['sort_order', 'Urutan & status', 'Atur urutan tampilan dan aktifkan filter sebelum menyimpan.'],
    ],
    'screen-configs' => [
        ['event_id', 'Event tujuan', 'Konten layar harus menggunakan event yang sama dengan perangkat kiosk.'],
        ['screen_type', 'Jenis layar', 'Pilih Welcome untuk sambutan atau Tutorial untuk panduan pelanggan.'],
        ['title', 'Isi layar', 'Atur judul, deskripsi, background, dan teks tombol. Pada tipe Tutorial, lengkapi juga Tutorial Steps beserta gambar dan urutannya.'],
        ['status', 'Status konten', 'Gunakan draft saat menyiapkan konten. Periksa konten sebelum menerbitkan atau mengaktifkannya melalui daftar.'],
    ],
    'timer-settings' => [
        ['name', 'Profil timer', 'Beri nama profil dan pilih event yang akan memakai pengaturan waktu ini.'],
        ['camera_countdown_seconds', 'Countdown kamera', 'Atur waktu hitung mundur agar pelanggan sempat bersiap sebelum foto diambil.'],
        ['session_timeout_seconds', 'Batas waktu sesi', 'Sesuaikan total sesi dan batas pembayaran dengan kebutuhan operasional.'],
        ['result_screen_timeout_seconds', 'Hasil & retake', 'Atur durasi layar hasil dan waktu retake. Beri pelanggan cukup waktu untuk mengambil atau memindai hasil.'],
        ['is_active', 'Aktifkan & uji', 'Simpan profil yang aktif lalu uji satu sesi lengkap pada kiosk.'],
    ],
    'vouchers' => [
        ['code', 'Identitas promo', 'Isi nama promo dan kode yang akan dimasukkan pelanggan pada layar pembayaran.'],
        ['type', 'Jenis & nilai diskon', 'Pilih jenis diskon, isi nilainya, lalu periksa batas diskon persen dan minimum transaksi jika digunakan.'],
        ['event_id', 'Batas penggunaan', 'Tentukan event, kuota total, dan batas per perangkat sesuai kebutuhan promo.'],
        ['expires_at', 'Masa berlaku', 'Periksa waktu mulai, waktu berakhir, dan status aktif sebelum menyimpan voucher.'],
    ],
    'users' => [
        ['name', 'Identitas pengguna', 'Isi nama dan email pengguna. Email harus unik.'],
        ['role', 'Peran pengguna', 'Pilih peran yang sesuai dengan tugas pengguna.'],
        ['password', 'Password', 'Isi password untuk akun baru. Saat mengedit, ikuti petunjuk kolom jika password tidak perlu diganti.'],
    ],
    'withdrawals' => [
        ['type', 'Jenis penarikan', 'Baca ketentuan dan pilih jenis penarikan yang tersedia.'],
        ['amount', 'Jumlah & estimasi', 'Isi saldo yang ingin dipotong. Periksa biaya dan estimasi dana diterima sebelum mengajukan.'],
        ['bank_account_number', 'Rekening tujuan', 'Pastikan bank, nomor rekening, dan nama pemilik rekening benar.'],
        ['notes', 'Catatan pengajuan', 'Tambahkan catatan jika diperlukan. Setelah pengajuan disimpan, pantau status melalui daftar penarikan.'],
    ],
];
