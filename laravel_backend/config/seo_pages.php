<?php

/*
|--------------------------------------------------------------------------
| Konten halaman SEO (layanan & area)
|--------------------------------------------------------------------------
|
| Semua teks halaman layanan (/photobooth-wedding, dst.) dan halaman kota
| (/photobooth-madiun, dst.) ada di sini supaya gampang diedit tanpa
| menyentuh Blade. Setiap halaman sengaja punya teks yang berbeda; Google
| menganggap halaman kota yang isinya cuma ganti nama kota sebagai
| "doorway page" dan bisa menurunkan peringkat seluruh situs.
|
| Jarak & waktu tempuh dihitung kasar dari pusat Kabupaten Magetan lewat
| rute tercepat (termasuk tol bila ada). Perbarui kalau ada data lebih akurat.
|
*/

return [

    'business' => [
        'name' => 'SnapTechBooth',
        'url' => 'https://snaptechbooth.my.id',
        'whatsapp' => '6287877946981',
        'phone_display' => '0878-7794-6981',
        'phone_schema' => '+62-878-7794-6981',
        'base_city' => 'Magetan',
        'base_region' => 'Jawa Timur',
        // Koordinat pusat Kabupaten Magetan (bukan alamat persis).
        'geo' => ['lat' => -7.6493, 'lng' => 111.3381],
    ],

    /*
    | Tingkat jangkauan dari Magetan. Dipakai sebagai badge & pengelompokan.
    */
    'tiers' => [
        'base' => ['label' => 'Base kami', 'note' => 'Tim dan perangkat berangkat dari sini.'],
        'utama' => ['label' => 'Area utama', 'note' => 'Kota tetangga Magetan. Paling mudah dijadwalkan, termasuk acara di hari kerja.'],
        'reguler' => ['label' => 'Jangkauan reguler', 'note' => 'Dilayani langsung oleh tim. Sebaiknya dijadwalkan lebih awal; biaya perjalanan menyesuaikan lokasi.'],
        'luar' => ['label' => 'Luar kota (by request)', 'note' => 'Bisa untuk acara tertentu dengan konfirmasi jadwal dan biaya perjalanan lebih dulu.'],
        'jauh' => ['label' => 'Jarak jauh: software & by request', 'note' => 'Untuk cafe dan vendor: software dipasang dan dikonfigurasi dari jarak jauh. Kehadiran tim on-site hanya dengan kesepakatan khusus.'],
    ],

    /*
    |----------------------------------------------------------------------
    | Halaman layanan
    |----------------------------------------------------------------------
    */
    'services' => [

        'photobooth-wedding' => [
            'name' => 'Photobooth Wedding',
            'short' => 'Wedding',
            'image' => 'photobooth-wedding',
            'image_alt' => 'Ilustrasi photobooth wedding dengan photo strip dan dekorasi bunga',
            'title' => 'Photobooth Wedding Magetan, Madiun & Sekitarnya | SnapTechBooth',
            'description' => 'Photobooth wedding self-service: frame nama pengantin, cetak instan 300 DPI sebagai souvenir, GIF & video, dan QR download untuk tamu. Berbasis di Magetan, melayani Jatim & Jateng.',
            'eyebrow' => 'Resepsi • Akad • Lamaran',
            'h1' => 'Photobooth Wedding yang Bikin Tamu Betah Antre',
            'lead' => 'Tamu foto sendiri, hasilnya langsung tercetak jadi souvenir, dan file digitalnya bisa diunduh lewat QR. Frame didesain dengan nama mempelai, tanggal, dan warna dekorasi supaya menyatu dengan acara.',
            'why_title' => 'Kenapa photobooth cocok untuk pernikahan',
            'why' => [
                ['Souvenir yang benar-benar disimpan', 'Photo strip cetak 300 DPI keluar beberapa detik setelah sesi selesai. Tamu pulang membawa kenangan dari hari bahagia kalian, bukan sekadar suvenir pajangan.'],
                ['Frame personal untuk kalian berdua', 'Nama mempelai, inisial, tanggal akad atau resepsi, sampai palet warna dekorasi dimasukkan ke desain frame. Bisa disiapkan beberapa pilihan frame untuk tamu.'],
                ['Momen yang tidak tertangkap fotografer', 'Semua sesi tersimpan. Setelah acara, kalian bisa melihat ekspresi tamu, teman lama, dan keluarga jauh yang mungkin terlewat dari kamera fotografer.'],
                ['Alur cepat, antrean tetap jalan', 'Hitung mundur 5 detik di setiap pose, maksimal 2 kali ulang per pose, lalu pilih filter. Satu sesi dibatasi waktunya supaya tamu berikutnya tidak menunggu lama.'],
            ],
            'suitable' => ['Resepsi di gedung', 'Pernikahan di rumah & tenda', 'Garden party & outdoor', 'Lamaran & tunangan', 'Ngunduh mantu', 'Pernikahan adat Jawa'],
            'first_step' => ['Pilih frame pengantin', 'Tamu memilih salah satu frame yang sudah didesain dengan nama dan tema kalian.'],
            'faq' => [
                ['Bisa pakai frame dengan nama pengantin?', 'Bisa. Kirim nama, tanggal, dan tema warna acara. Frame disiapkan sebelum hari H dan bisa direvisi sampai cocok.'],
                ['Tamu harus bayar untuk foto?', 'Tidak harus. Untuk acara pernikahan, sesi bisa dibuka dengan voucher sehingga tamu langsung foto tanpa membayar. Detailnya kita atur saat konsultasi.'],
                ['Apakah tamu dapat file digitalnya?', 'Ya. Setiap sesi menampilkan QR code untuk mengunduh foto, GIF, dan video langsung ke HP tamu.'],
                ['Melayani pernikahan di luar Magetan?', 'Ya. Area utama kami Magetan, Madiun, Ngawi, Ponorogo, dan sekitarnya. Untuk kota yang lebih jauh, hubungi kami untuk cek jadwal dan biaya perjalanan.'],
            ],
            'wa' => 'Halo SnapTechBooth, saya ingin tanya photobooth untuk acara pernikahan.',
        ],

        'photobooth-cafe' => [
            'name' => 'Photobooth untuk Cafe',
            'short' => 'Cafe',
            'image' => 'photobooth-cafe',
            'image_alt' => 'Ilustrasi photobooth self-service di cafe dengan cangkir kopi dan photo strip',
            'title' => 'Photobooth Cafe Self-Service, Bayar QRIS Tanpa Operator | SnapTechBooth',
            'description' => 'Pasang photobooth self-service di cafe: pengunjung bayar QRIS, foto, cetak 300 DPI, dan download ke HP tanpa operator. Frame bisa pakai branding cafe dan sesi tanpa batas.',
            'eyebrow' => 'Cafe • Coffee shop • Resto',
            'h1' => 'Photobooth Self-Service untuk Cafe, Jalan Sendiri Tanpa Operator',
            'lead' => 'Satu sudut kecil di cafe bisa jadi daya tarik baru. Pengunjung bayar lewat QRIS, sesi terbuka otomatis, hasilnya tercetak dan bisa diunduh. Kamu tinggal pantau transaksi dari dashboard.',
            'why_title' => 'Yang didapat cafe dari photobooth',
            'why' => [
                ['Pemasukan tambahan per sesi', 'Pengunjung membayar per sesi lewat QRIS dinamis. Pembayaran terverifikasi otomatis sebelum sesi dimulai, jadi tidak perlu kasir tambahan.'],
                ['Konten gratis untuk media sosial', 'Frame dengan logo dan nama cafe ikut terbawa setiap kali pengunjung membagikan foto, GIF, atau video mereka ke Instagram dan TikTok.'],
                ['Tidak perlu operator', 'Kiosk menuntun pengunjung dari layar sambutan, tutorial, pembayaran, pilih frame, sesi foto, sampai cetak dan QR download.'],
                ['Kelola dari HP atau laptop', 'Ganti frame musiman, cek transaksi, dan pantau perangkat dari dashboard tanpa harus datang ke lokasi.'],
            ],
            'suitable' => ['Coffee shop', 'Cafe tematik & aesthetic', 'Resto keluarga', 'Dessert & boba bar', 'Co-working space', 'Tempat wisata & rest area'],
            'first_step' => ['Bayar dengan QRIS', 'Pengunjung memindai QRIS dinamis. Begitu pembayaran terkonfirmasi, sesi 5 menit langsung dimulai.'],
            'faq' => [
                ['Berapa biaya langganannya?', 'Langganan dihitung per bulan dengan sesi foto tanpa batas. Perbandingan paket ada di halaman utama, atau konsultasikan kebutuhan cafe kamu lewat WhatsApp.'],
                ['Perangkat apa yang dibutuhkan?', 'Tablet atau display Android (versi Windows juga tersedia), kamera, dan printer foto. Kami bantu pilih setup yang pas dengan ruang dan budget cafe.'],
                ['Bagaimana uang dari pengunjung masuk?', 'Pembayaran memakai QRIS dinamis. Setiap transaksi tercatat di dashboard sehingga mudah dicocokkan.'],
                ['Bisa ganti frame sesuai musim atau promo?', 'Bisa. Upload desain PNG baru dan atur area fotonya lewat frame editor di dashboard.'],
            ],
            'wa' => 'Halo SnapTechBooth, saya ingin pasang photobooth self-service di cafe saya.',
        ],

        'photobooth-event' => [
            'name' => 'Photobooth Event',
            'short' => 'Event',
            'image' => 'photobooth-event',
            'image_alt' => 'Ilustrasi photobooth event dengan confetti, balon, dan photo strip',
            'title' => 'Photobooth Event, Ulang Tahun & Gathering Kantor | SnapTechBooth',
            'description' => 'Photobooth untuk event kantor, gathering, launching produk, bazar, dan ulang tahun. Frame dengan logo brand atau sponsor, cetak instan, GIF & video. Melayani Magetan, Madiun, Solo, dan sekitarnya.',
            'eyebrow' => 'Corporate • Ulang tahun • Festival',
            'h1' => 'Photobooth Event yang Bikin Brand Kamu Ikut Dibawa Pulang',
            'lead' => 'Dari gathering kantor sampai pesta ulang tahun, photobooth membuat tamu berkumpul dan berinteraksi. Setiap hasil cetak dan file digital membawa logo acara, brand, atau sponsor kamu.',
            'why_title' => 'Kenapa photobooth efektif di event',
            'why' => [
                ['Branding di setiap lembar foto', 'Logo perusahaan, nama acara, hashtag, atau logo sponsor dimasukkan ke frame. Setiap kali tamu membagikan hasilnya, acaramu ikut terlihat.'],
                ['Titik kumpul yang ramai', 'Photobooth jadi tempat tamu berkumpul, saling ajak, dan mencairkan suasana, terutama di gathering atau acara networking.'],
                ['Format digital yang siap dibagikan', 'Selain cetak, tamu mendapat foto, GIF, dan video pendek lewat QR code yang mudah diunggah ke media sosial.'],
                ['Bisa gratis atau berbayar', 'Untuk event internal, sesi dibuka dengan voucher. Untuk bazar atau festival, sesi bisa berbayar QRIS sebagai pemasukan tambahan.'],
            ],
            'suitable' => ['Gathering & family day kantor', 'Launching produk', 'Ulang tahun & sweet seventeen', 'Bazar & pameran', 'Festival & konser kecil', 'Seminar & expo'],
            'first_step' => ['Masuk dengan voucher atau QRIS', 'Panitia bisa membagikan voucher untuk tamu undangan, atau sesi dibuka lewat pembayaran QRIS untuk acara publik.'],
            'faq' => [
                ['Bisa pakai logo perusahaan atau sponsor di frame?', 'Bisa. Kirim logo dalam format PNG atau vektor, kami bantu susun frame-nya. Beberapa frame bisa disiapkan untuk sponsor yang berbeda.'],
                ['Acara kami publik, bisa dibuat berbayar?', 'Bisa. Sesi dibuka setelah pembayaran QRIS terverifikasi, dan semua transaksi tercatat di dashboard.'],
                ['Berapa lama satu sesi foto?', 'Satu sesi dibatasi 5 menit sejak foto dimulai, dengan hitung mundur 5 detik di setiap pose. Ini menjaga antrean tetap bergerak.'],
                ['Melayani event di Solo atau Surabaya?', 'Ya. Solo dan sekitarnya termasuk jangkauan reguler kami; Surabaya, Malang, dan Semarang bisa dengan konfirmasi jadwal dan biaya perjalanan.'],
            ],
            'wa' => 'Halo SnapTechBooth, saya ingin tanya photobooth untuk event.',
        ],

        'photobooth-wisuda' => [
            'name' => 'Photobooth Wisuda & Sekolah',
            'short' => 'Wisuda & Sekolah',
            'image' => 'photobooth-wisuda',
            'image_alt' => 'Ilustrasi photobooth wisuda dengan topi toga dan photo strip',
            'title' => 'Photobooth Wisuda, Perpisahan Sekolah & Reuni | SnapTechBooth',
            'description' => 'Photobooth untuk wisuda, perpisahan sekolah, pensi, dan reuni. Frame dengan logo sekolah atau kampus, cetak langsung, GIF & video via QR. Berbasis di Magetan, melayani Jatim & Jateng.',
            'eyebrow' => 'Wisuda • Perpisahan • Reuni',
            'h1' => 'Photobooth Wisuda & Perpisahan Sekolah',
            'lead' => 'Hari kelulusan cuma sekali. Siswa, mahasiswa, guru, dan orang tua bisa foto bersama dengan frame berlogo sekolah atau kampus, lalu membawa pulang hasil cetaknya hari itu juga.',
            'why_title' => 'Kenapa photobooth pas untuk acara sekolah & kampus',
            'why' => [
                ['Frame dengan identitas sekolah', 'Logo sekolah atau kampus, nama angkatan, tahun lulus, dan slogan kelas dimasukkan ke frame. Hasilnya jadi kenang-kenangan resmi angkatan.'],
                ['Ramah untuk antrean panjang', 'Alur foto dipandu layar: pilih frame, pose dengan hitung mundur, pilih filter, cetak. Satu sesi dibatasi waktunya sehingga antrean cepat berganti.'],
                ['Foto bareng keluarga', 'Orang tua yang datang ke wisuda bisa ikut foto bersama, dan file digitalnya diunduh lewat QR untuk dikirim ke keluarga lain.'],
                ['Bisa jadi dana kegiatan', 'Panitia bisa membuka sesi berbayar lewat QRIS di acara pensi atau bazar sekolah, atau memakai voucher untuk acara resmi.'],
            ],
            'suitable' => ['Wisuda kampus', 'Perpisahan SMA/SMK', 'Pentas seni (pensi)', 'Reuni angkatan', 'Dies natalis', 'Wisuda TK & SD'],
            'first_step' => ['Pilih frame angkatan', 'Peserta memilih frame berlogo sekolah atau kampus yang sudah disiapkan panitia.'],
            'faq' => [
                ['Bisa pakai logo sekolah atau kampus?', 'Bisa. Panitia cukup mengirim logo dan nama angkatan; kami bantu desain frame-nya sebelum hari acara.'],
                ['Acara wisuda biasanya ramai, apakah antrean lama?', 'Setiap sesi dibatasi 5 menit dengan hitung mundur di setiap pose, dan hasil cetak keluar otomatis. Untuk peserta yang sangat banyak, konsultasikan opsi lebih dari satu booth.'],
                ['Bisa untuk acara di aula atau lapangan?', 'Bisa, selama tersedia listrik dan area yang terlindung dari hujan atau sinar matahari langsung.'],
            ],
            'wa' => 'Halo SnapTechBooth, saya panitia acara sekolah/kampus dan ingin tanya photobooth.',
        ],

        'sewa-photobooth' => [
            'name' => 'Sewa Photobooth',
            'short' => 'Sewa',
            'image' => 'sewa-photobooth',
            'image_alt' => 'Ilustrasi sewa photobooth dengan properti foto dan photo strip',
            'title' => 'Sewa Photobooth Magetan, Madiun, Ngawi & Sekitarnya | SnapTechBooth',
            'description' => 'Sewa photobooth self-service untuk wedding, event, dan acara sekolah. Frame custom, cetak instan 300 DPI, GIF & video via QR. Berbasis di Magetan, melayani Jawa Timur dan Jawa Tengah.',
            'eyebrow' => 'Sewa booth • Frame custom • Cetak instan',
            'h1' => 'Sewa Photobooth dari Magetan untuk Acara di Jawa Timur & Jawa Tengah',
            'lead' => 'Booth self-service lengkap dengan kamera, layar, dan printer. Kami siapkan frame sesuai acara, pasang di lokasi, dan semua hasil foto tersimpan untuk diunduh tamu lewat QR.',
            'why_title' => 'Yang kamu dapat saat menyewa',
            'why' => [
                ['Frame custom sesuai acara', 'Desain frame mengikuti tema, nama, atau logo acara. Bisa beberapa pilihan frame dalam satu acara.'],
                ['Cetak langsung di lokasi', 'Photo strip 300 DPI keluar otomatis setelah setiap sesi, langsung bisa dibawa pulang tamu.'],
                ['File digital untuk semua tamu', 'Foto, GIF, dan video pendek bisa diunduh lewat QR code. Tidak perlu aplikasi tambahan di HP tamu.'],
                ['Berangkat dari Magetan', 'Area sekitar seperti Madiun, Ngawi, Ponorogo, Sragen, dan Karanganyar mudah kami jangkau, jadi penjadwalan lebih fleksibel.'],
            ],
            'suitable' => ['Pernikahan', 'Event kantor', 'Ulang tahun', 'Wisuda & perpisahan', 'Bazar & festival', 'Acara komunitas'],
            'first_step' => ['Pilih frame acara', 'Tamu memilih frame yang sudah didesain khusus untuk acaramu.'],
            'faq' => [
                ['Bagaimana cara memesan?', 'Hubungi kami lewat WhatsApp dengan tanggal, lokasi, dan jenis acara. Kami cek ketersediaan, lalu siapkan desain frame sebelum hari H.'],
                ['Berapa lama sebelum acara sebaiknya memesan?', 'Semakin awal semakin baik, terutama untuk musim pernikahan dan wisuda. Untuk luar kota, pesan lebih awal agar perjalanan bisa diatur.'],
                ['Apa yang perlu disiapkan di lokasi?', 'Area sekitar 2×2 meter, stopkontak listrik, dan tempat yang terlindung dari hujan atau matahari langsung.'],
                ['Apakah ada biaya transport?', 'Untuk area di luar Magetan, biaya perjalanan menyesuaikan jarak. Detailnya dikonfirmasi saat konsultasi.'],
            ],
            'wa' => 'Halo SnapTechBooth, saya ingin sewa photobooth.',
        ],

        'aplikasi-photobooth' => [
            'name' => 'Aplikasi Photobooth',
            'short' => 'Aplikasi',
            'image' => 'aplikasi-photobooth',
            'image_alt' => 'Ilustrasi aplikasi photobooth di tablet dengan QRIS, pilihan frame, dan printer',
            'title' => 'Aplikasi Photobooth Android & Windows, QRIS & Auto-Print | SnapTechBooth',
            'description' => 'Software photobooth self-service untuk Android & Windows: pembayaran QRIS otomatis, cetak 300 DPI, frame editor, GIF & video, QR download, dan dashboard multi-device untuk vendor dan cafe.',
            'eyebrow' => 'Software • Android & Windows • Dashboard',
            'h1' => 'Aplikasi Photobooth Self-Service untuk Vendor & Pemilik Cafe',
            'lead' => 'Punya kamera dan printer tapi butuh software yang rapi? SnapTechBooth menjalankan seluruh alur photobooth: pembayaran QRIS, sesi foto, filter, cetak otomatis, sampai QR download, lengkap dengan dashboard untuk mengelola semuanya.',
            'why_title' => 'Fitur utama aplikasinya',
            'why' => [
                ['QRIS dinamis & voucher', 'Pembayaran QRIS terverifikasi otomatis sebelum sesi dimulai. Untuk acara khusus, sesi bisa dibuka dengan kode voucher.'],
                ['Auto-print 300 DPI', 'Photo strip dirender dalam resolusi cetak dan dikirim ke printer foto begitu sesi selesai.'],
                ['Frame editor & filter', 'Upload frame PNG, atur posisi slot foto, dan sediakan filter yang bisa dipilih pengunjung di akhir sesi.'],
                ['Dashboard multi-device', 'Pantau transaksi, kelola frame dan event, serta atur beberapa kiosk dan cabang dari satu dashboard.'],
            ],
            'suitable' => ['Vendor photobooth & rental', 'Cafe & resto', 'Studio foto self-service', 'Wedding organizer', 'Event organizer', 'Tempat wisata'],
            'first_step' => ['Layar sambutan & tutorial', 'Kiosk menampilkan kamera live dan tutorial singkat, lalu meminta pembayaran QRIS atau voucher.'],
            'faq' => [
                ['Aplikasinya jalan di perangkat apa?', 'Kiosk tersedia untuk Android dan Windows. Dashboard admin dibuka lewat browser di laptop atau HP.'],
                ['Bisa dipakai untuk beberapa booth sekaligus?', 'Bisa. Paket Pro mendukung hingga 2 device, dan Studio Pack hingga 6 device dengan dukungan multi-cabang dan multi-event.'],
                ['Saya di luar Jawa Timur, bisa pakai?', 'Bisa. Software dipasang dan dikonfigurasi dari jarak jauh, jadi bisa dipakai di Jakarta, Bekasi, atau kota lain.'],
                ['Apakah ada batas jumlah sesi?', 'Tidak. Paket saat ini mendukung sesi foto tanpa batas; kapasitas penyimpanan cloud menyesuaikan paket.'],
            ],
            'wa' => 'Halo SnapTechBooth, saya ingin tanya aplikasi/software photobooth.',
        ],
    ],

    /*
    |----------------------------------------------------------------------
    | Halaman kota
    |----------------------------------------------------------------------
    */
    'cities' => [

        'photobooth-magetan' => [
            'name' => 'Magetan',
            'province' => 'Jawa Timur',
            'tier' => 'base',
            'intro' => 'SnapTechBooth berbasis di Magetan. Perangkat, printer, dan tim berangkat dari sini, sehingga acara di Magetan paling mudah dijadwalkan, termasuk persiapan dan uji coba frame sehari sebelumnya.',
            'local' => 'Dari pernikahan di rumah warga di Maospati dan Plaosan, acara sekolah di pusat kota, sampai cafe dan villa di kawasan Telaga Sarangan, photobooth bisa menyesuaikan suasana. Untuk acara di dataran tinggi seperti Sarangan, kami siapkan area booth yang terlindung dari angin dan embun.',
            'venues' => ['Pernikahan di rumah & gedung', 'Cafe & villa di Sarangan', 'Acara sekolah', 'Event desa & instansi', 'Ulang tahun', 'Bazar UMKM'],
            'nearby' => ['photobooth-madiun', 'photobooth-ngawi', 'photobooth-ponorogo', 'photobooth-karanganyar'],
            'faq' => ['Bisa survei lokasi dulu sebelum acara?', 'Untuk acara di Magetan, survei lokasi atau uji coba frame bisa dijadwalkan sebelum hari H karena tim berbasis di sini.'],
        ],

        'photobooth-madiun' => [
            'name' => 'Madiun',
            'province' => 'Jawa Timur',
            'tier' => 'utama',
            'intro' => 'Madiun adalah tetangga terdekat Magetan. Kota Madiun maupun Kabupaten Madiun masuk area utama kami, jadi cocok untuk acara di akhir pekan maupun hari kerja.',
            'local' => 'Gedung pertemuan, hotel, dan restoran di pusat Kota Madiun sering dipakai untuk resepsi, wisuda, dan gathering kantor. Kota yang ramai anak muda di sekitar kawasan Pahlawan Street Center juga punya banyak cafe yang cocok untuk photobooth self-service.',
            'venues' => ['Resepsi di gedung & hotel', 'Wisuda kampus', 'Gathering kantor', 'Cafe di pusat kota', 'Acara perguruan silat', 'Ulang tahun'],
            'nearby' => ['photobooth-magetan', 'photobooth-ngawi', 'photobooth-ponorogo', 'photobooth-nganjuk'],
            'faq' => ['Apakah melayani Kota dan Kabupaten Madiun?', 'Ya, keduanya. Kecamatan seperti Caruban, Dolopo, dan Jiwan tetap masuk area utama dari Magetan.'],
        ],

        'photobooth-ngawi' => [
            'name' => 'Ngawi',
            'province' => 'Jawa Timur',
            'tier' => 'utama',
            'intro' => 'Ngawi berada di perbatasan Jawa Timur dan Jawa Tengah, bersebelahan dengan Magetan. Akses tol Ngawi juga memudahkan kami menjangkau lokasi acara di berbagai kecamatan.',
            'local' => 'Banyak pernikahan di Ngawi digelar di rumah dan tenda, sehingga booth dengan cetak instan menjadi hiburan yang menyenangkan untuk tamu dari desa sekitar. Ikon seperti Benteng Van den Bosch juga bisa jadi inspirasi frame bertema sejarah untuk acara sekolah atau event kabupaten.',
            'venues' => ['Pernikahan di rumah & tenda', 'Acara sekolah', 'Event kabupaten', 'Cafe & resto', 'Lamaran', 'Reuni'],
            'nearby' => ['photobooth-magetan', 'photobooth-madiun', 'photobooth-sragen', 'photobooth-bojonegoro'],
            'faq' => ['Acara di desa yang aksesnya sempit, bisa?', 'Bisa, selama kendaraan dapat mendekat dan tersedia listrik. Ceritakan kondisi lokasinya saat konsultasi agar kami siapkan perangkat yang sesuai.'],
        ],

        'photobooth-ponorogo' => [
            'name' => 'Ponorogo',
            'province' => 'Jawa Timur',
            'tier' => 'utama',
            'intro' => 'Ponorogo termasuk area utama kami dari Magetan. Acara pernikahan, sekolah, maupun pondok pesantren di Ponorogo bisa dijadwalkan dengan nyaman.',
            'local' => 'Ponorogo dikenal dengan Reog dan perayaan Grebeg Suro yang meriah. Frame bertema budaya lokal bisa membuat hasil foto terasa khas Ponorogo, baik untuk resepsi, acara instansi, maupun festival.',
            'venues' => ['Resepsi pernikahan', 'Acara pondok & sekolah', 'Event budaya', 'Wisuda', 'Cafe', 'Gathering instansi'],
            'nearby' => ['photobooth-madiun', 'photobooth-magetan', 'photobooth-pacitan', 'photobooth-wonogiri'],
            'faq' => ['Bisa dibuatkan frame bertema Reog?', 'Bisa. Frame dapat mengangkat motif atau ikon budaya lokal sesuai keinginan, dengan desain yang kami siapkan sebelum acara.'],
        ],

        'photobooth-nganjuk' => [
            'name' => 'Nganjuk',
            'province' => 'Jawa Timur',
            'tier' => 'utama',
            'intro' => 'Nganjuk mudah dijangkau dari Magetan melalui Madiun, sehingga termasuk area utama kami untuk pernikahan, acara sekolah, dan event instansi.',
            'local' => 'Pernikahan di gedung dan rumah, acara sekolah, serta event instansi di Nganjuk bisa memakai photobooth dengan frame custom. Untuk acara yang dimulai pagi, kami berangkat lebih awal agar booth siap sebelum tamu datang.',
            'venues' => ['Pernikahan', 'Acara sekolah', 'Event instansi', 'Ulang tahun', 'Bazar', 'Cafe'],
            'nearby' => ['photobooth-madiun', 'photobooth-kediri', 'photobooth-bojonegoro', 'photobooth-ponorogo'],
            'faq' => ['Acara pagi di Nganjuk, booth siap jam berapa?', 'Kami menyesuaikan dengan jadwal acara dan berangkat lebih awal dari Magetan. Waktu siap dikonfirmasi saat pemesanan.'],
        ],

        'photobooth-pacitan' => [
            'name' => 'Pacitan',
            'province' => 'Jawa Timur',
            'tier' => 'reguler',
            'intro' => 'Pacitan masuk jangkauan reguler kami dari Magetan melalui Ponorogo. Acara di Pacitan sebaiknya dijadwalkan lebih awal agar perjalanan bisa diatur dengan baik.',
            'local' => 'Dengan garis pantai dan banyak destinasi wisata, Pacitan cocok untuk acara bertema outdoor seperti pernikahan di tepi pantai atau gathering di kawasan wisata. Untuk lokasi terbuka, booth perlu area yang teduh dan aman dari angin laut.',
            'venues' => ['Pernikahan outdoor', 'Gathering di kawasan wisata', 'Acara sekolah', 'Event kabupaten', 'Resepsi di rumah', 'Reuni'],
            'nearby' => ['photobooth-ponorogo', 'photobooth-wonogiri', 'photobooth-magetan'],
            'faq' => ['Bisa untuk acara di pinggir pantai?', 'Bisa, asalkan ada area beratap atau tenda yang melindungi perangkat dari angin, pasir, dan percikan air, serta sumber listrik yang stabil.'],
        ],

        'photobooth-bojonegoro' => [
            'name' => 'Bojonegoro',
            'province' => 'Jawa Timur',
            'tier' => 'reguler',
            'intro' => 'Bojonegoro dapat dijangkau dari Magetan lewat Ngawi. Kota ini masuk jangkauan reguler untuk pernikahan, acara perusahaan, dan event sekolah.',
            'local' => 'Selain pernikahan dan wisuda, Bojonegoro punya banyak kegiatan perusahaan dan instansi yang cocok memakai photobooth dengan frame berlogo untuk family day atau peringatan hari jadi.',
            'venues' => ['Family day perusahaan', 'Pernikahan', 'Wisuda', 'Event instansi', 'Ulang tahun', 'Cafe'],
            'nearby' => ['photobooth-ngawi', 'photobooth-nganjuk', 'photobooth-madiun'],
            'faq' => ['Bisa untuk family day perusahaan dengan banyak peserta?', 'Bisa. Untuk peserta yang banyak, kita diskusikan durasi, jumlah frame, dan kemungkinan lebih dari satu booth agar antrean tetap lancar.'],
        ],

        'photobooth-kediri' => [
            'name' => 'Kediri',
            'province' => 'Jawa Timur',
            'tier' => 'reguler',
            'intro' => 'Kediri dapat dijangkau dari Magetan melalui Madiun dan Nganjuk, masuk jangkauan reguler kami untuk acara yang dijadwalkan lebih awal.',
            'local' => 'Kota dan Kabupaten Kediri punya banyak gedung resepsi, sekolah, dan pondok pesantren. Photobooth dengan frame custom bisa melengkapi pernikahan, wisuda, maupun acara kampus di Kediri.',
            'venues' => ['Pernikahan di gedung', 'Wisuda & acara pondok', 'Acara kampus', 'Gathering kantor', 'Ulang tahun', 'Cafe'],
            'nearby' => ['photobooth-nganjuk', 'photobooth-madiun', 'photobooth-malang'],
            'faq' => ['Melayani Kota dan Kabupaten Kediri?', 'Ya, keduanya masuk jangkauan reguler. Konfirmasi lokasi persis saat konsultasi agar estimasi perjalanan lebih tepat.'],
        ],

        'photobooth-surabaya' => [
            'name' => 'Surabaya',
            'province' => 'Jawa Timur',
            'tier' => 'luar',
            'intro' => 'Surabaya bisa dijangkau dari Magetan melalui tol. Kami melayani acara di Surabaya berdasarkan permintaan, dengan konfirmasi jadwal dan biaya perjalanan lebih dulu.',
            'local' => 'Untuk cafe dan vendor di Surabaya yang ingin menjalankan photobooth sendiri, aplikasi SnapTechBooth bisa dipasang dan dikonfigurasi dari jarak jauh. Untuk acara besar seperti launching produk atau gathering perusahaan, tim kami bisa datang dengan perangkat lengkap.',
            'venues' => ['Launching produk', 'Gathering perusahaan', 'Pernikahan di hotel', 'Cafe (software)', 'Vendor photobooth (software)', 'Expo & pameran'],
            'nearby' => ['photobooth-malang', 'photobooth-madiun', 'photobooth-kediri'],
            'faq' => ['Cafe saya di Surabaya, bisa pakai software saja?', 'Bisa. Software dipasang dan dikonfigurasi dari jarak jauh; kamu cukup menyiapkan perangkat dan printer yang direkomendasikan.'],
        ],

        'photobooth-malang' => [
            'name' => 'Malang',
            'province' => 'Jawa Timur',
            'tier' => 'luar',
            'intro' => 'Acara di Malang dan Batu kami layani berdasarkan permintaan, sementara software photobooth bisa langsung dipakai cafe dan vendor di sana.',
            'local' => 'Malang dan Batu punya banyak cafe, villa, dan tempat wisata yang ramai pengunjung. Photobooth self-service dengan pembayaran QRIS cocok untuk tempat seperti ini karena berjalan tanpa operator sepanjang hari.',
            'venues' => ['Cafe & tempat wisata (software)', 'Pernikahan di villa', 'Acara kampus', 'Gathering', 'Vendor photobooth (software)', 'Event komunitas'],
            'nearby' => ['photobooth-surabaya', 'photobooth-kediri'],
            'faq' => ['Bisa dipasang di tempat wisata di Batu?', 'Bisa. Mode self-service dengan QRIS cocok untuk tempat wisata karena pengunjung bisa foto kapan saja tanpa operator.'],
        ],

        'photobooth-solo' => [
            'name' => 'Solo',
            'full_name' => 'Solo (Surakarta)',
            'province' => 'Jawa Tengah',
            'tier' => 'reguler',
            'intro' => 'Solo (Surakarta) mudah dicapai dari Magetan lewat tol Ngawi–Solo. Kota ini masuk jangkauan reguler kami untuk pernikahan, wisuda, dan event perusahaan.',
            'local' => 'Solo punya tradisi pernikahan adat Jawa yang kuat dan banyak gedung resepsi, hotel, serta kampus. Frame dengan sentuhan motif batik atau nuansa keraton bisa membuat hasil photobooth terasa menyatu dengan acara.',
            'venues' => ['Pernikahan adat Jawa', 'Resepsi di hotel', 'Wisuda kampus', 'Gathering perusahaan', 'Cafe', 'Event komunitas'],
            'nearby' => ['photobooth-karanganyar', 'photobooth-sragen', 'photobooth-wonogiri', 'photobooth-semarang'],
            'faq' => ['Bisa dibuatkan frame bernuansa batik untuk pernikahan adat?', 'Bisa. Kami siapkan frame dengan motif dan warna yang sesuai tema adat, termasuk nama dan tanggal pernikahan.'],
        ],

        'photobooth-sragen' => [
            'name' => 'Sragen',
            'province' => 'Jawa Tengah',
            'tier' => 'utama',
            'intro' => 'Sragen adalah kabupaten Jawa Tengah yang paling mudah kami jangkau dari Magetan lewat tol Ngawi.',
            'local' => 'Pernikahan di rumah dan gedung, acara sekolah, serta event desa di Sragen bisa dilengkapi photobooth dengan frame custom. Frame bertema sejarah purbakala juga menarik untuk acara edukasi atau kegiatan sekolah.',
            'venues' => ['Pernikahan', 'Acara sekolah', 'Event desa', 'Wisuda', 'Ulang tahun', 'Cafe'],
            'nearby' => ['photobooth-ngawi', 'photobooth-solo', 'photobooth-karanganyar'],
            'faq' => ['Dari Magetan ke Sragen lewat mana?', 'Biasanya lewat tol Ngawi–Solo karena paling cepat. Estimasi waktu tiba kami konfirmasi saat pemesanan.'],
        ],

        'photobooth-karanganyar' => [
            'name' => 'Karanganyar',
            'province' => 'Jawa Tengah',
            'tier' => 'utama',
            'intro' => 'Karanganyar bisa dicapai dari Magetan lewat jalur Cemoro Sewu–Tawangmangu. Kawasan wisata seperti Tawangmangu cukup dekat dari base kami.',
            'local' => 'Villa, resort, dan kebun teh di lereng Lawu sering dipakai untuk pernikahan outdoor dan gathering. Udara sejuk dan pemandangan pegunungan membuat photobooth jadi pelengkap yang pas, dengan catatan area booth terlindung dari embun dan angin.',
            'venues' => ['Pernikahan di villa', 'Gathering di resort', 'Acara outdoor', 'Cafe di kawasan wisata', 'Acara sekolah', 'Reuni'],
            'nearby' => ['photobooth-magetan', 'photobooth-solo', 'photobooth-sragen', 'photobooth-wonogiri'],
            'faq' => ['Bisa untuk acara di villa Tawangmangu?', 'Bisa. Tawangmangu termasuk yang dekat dari Magetan lewat Cemoro Sewu. Pastikan area booth beratap dan tersedia listrik.'],
        ],

        'photobooth-wonogiri' => [
            'name' => 'Wonogiri',
            'province' => 'Jawa Tengah',
            'tier' => 'reguler',
            'intro' => 'Wonogiri masuk jangkauan reguler kami dari Magetan, bisa lewat Ponorogo atau Solo tergantung lokasi acara.',
            'local' => 'Pernikahan di rumah dan gedung, acara sekolah, serta event kabupaten di Wonogiri bisa memakai photobooth dengan frame custom. Untuk acara di kawasan wisata waduk atau dataran tinggi, kami sesuaikan penempatan booth dengan kondisi lokasi.',
            'venues' => ['Pernikahan', 'Acara sekolah', 'Event kabupaten', 'Gathering', 'Ulang tahun', 'Reuni'],
            'nearby' => ['photobooth-solo', 'photobooth-ponorogo', 'photobooth-pacitan', 'photobooth-karanganyar'],
            'faq' => ['Lokasi saya di perbatasan Wonogiri–Ponorogo, masuk jangkauan?', 'Masuk. Lokasi di sisi timur Wonogiri justru lebih dekat dari Magetan lewat Ponorogo.'],
        ],

        'photobooth-semarang' => [
            'name' => 'Semarang',
            'province' => 'Jawa Tengah',
            'tier' => 'luar',
            'intro' => 'Semarang dapat dijangkau dari Magetan melalui tol Solo–Semarang. Acara di Semarang kami layani berdasarkan permintaan dengan konfirmasi jadwal dan biaya perjalanan.',
            'local' => 'Sebagai ibu kota Jawa Tengah, Semarang punya banyak hotel, convention hall, dan kampus untuk acara besar. Cafe dan vendor di Semarang juga bisa langsung memakai software SnapTechBooth tanpa menunggu tim datang.',
            'venues' => ['Pernikahan di hotel', 'Expo & convention', 'Wisuda kampus', 'Launching produk', 'Cafe (software)', 'Vendor photobooth (software)'],
            'nearby' => ['photobooth-solo', 'photobooth-sragen'],
            'faq' => ['Bisa untuk acara di convention hall?', 'Bisa, dengan pemesanan lebih awal. Untuk acara besar, kita bahas kebutuhan jumlah booth dan durasi sejak awal.'],
        ],

        'photobooth-jakarta' => [
            'name' => 'Jakarta',
            'province' => 'DKI Jakarta',
            'tier' => 'jauh',
            'intro' => 'Untuk Jakarta, layanan utama kami adalah software photobooth: aplikasi kiosk, pembayaran QRIS, auto-print, dan dashboard yang dipasang serta dikonfigurasi dari jarak jauh. Acara on-site di Jakarta bisa dibahas dengan kesepakatan khusus.',
            'local' => 'Pasar cafe, mall, dan event di Jakarta sangat ramai, dan banyak vendor photobooth butuh software yang stabil dengan pembayaran otomatis. SnapTechBooth mendukung beberapa device dan cabang dari satu dashboard, cocok untuk vendor yang mengelola beberapa booth sekaligus.',
            'venues' => ['Vendor photobooth (software)', 'Cafe & resto (software)', 'Booth di mall (software)', 'Studio foto self-service', 'Event brand (by request)', 'Rental multi-booth'],
            'nearby' => ['photobooth-bekasi'],
            'faq' => ['Tim bisa datang ke Jakarta untuk event?', 'Bisa untuk acara tertentu dengan kesepakatan jadwal dan biaya perjalanan. Untuk kebutuhan rutin, kami sarankan memakai software dengan perangkat di lokasi kamu.'],
        ],

        'photobooth-bekasi' => [
            'name' => 'Bekasi',
            'province' => 'Jawa Barat',
            'tier' => 'jauh',
            'intro' => 'Untuk Bekasi, kami fokus pada software photobooth yang dipasang dan dikonfigurasi dari jarak jauh. Cafe, studio, dan vendor di Bekasi bisa menjalankan booth sendiri dengan pembayaran QRIS dan cetak otomatis.',
            'local' => 'Bekasi punya banyak cafe, perumahan dengan acara komunitas, dan kawasan industri yang sering mengadakan family day. Vendor lokal bisa memakai SnapTechBooth untuk menjalankan beberapa booth dan memantau transaksi dari satu dashboard.',
            'venues' => ['Cafe & resto (software)', 'Vendor photobooth (software)', 'Family day kawasan industri', 'Acara komunitas perumahan', 'Studio foto self-service', 'Event (by request)'],
            'nearby' => ['photobooth-jakarta'],
            'faq' => ['Bagaimana proses pemasangan software dari jauh?', 'Kami bantu rekomendasi perangkat, lalu instalasi, aktivasi device, dan pengaturan frame dilakukan dari jarak jauh dengan panduan langkah demi langkah.'],
        ],
    ],

    /*
    |----------------------------------------------------------------------
    | Halaman provinsi
    |----------------------------------------------------------------------
    */
    'regions' => [
        'photobooth-jawa-timur' => [
            'name' => 'Jawa Timur',
            'title' => 'Photobooth Jawa Timur: Magetan, Madiun, Ngawi & Sekitarnya | SnapTechBooth',
            'description' => 'Photobooth wedding, event, dan cafe di Jawa Timur dari base kami di Magetan. Melayani Madiun, Ngawi, Ponorogo, Nganjuk, Pacitan, Bojonegoro, Kediri, Surabaya, dan Malang.',
            'h1' => 'Photobooth di Jawa Timur, Berangkat dari Magetan',
            'lead' => 'Base kami ada di Magetan, ujung barat Jawa Timur. Kota-kota di Karesidenan Madiun paling mudah kami jangkau, sementara kota lain di Jawa Timur dilayani dengan penjadwalan lebih awal atau lewat software.',
            'province' => 'Jawa Timur',
        ],
        'photobooth-jawa-tengah' => [
            'name' => 'Jawa Tengah',
            'title' => 'Photobooth Jawa Tengah: Solo, Sragen, Karanganyar & Sekitarnya | SnapTechBooth',
            'description' => 'Photobooth wedding, event, dan cafe di Jawa Tengah dari Magetan. Melayani Sragen, Karanganyar, Solo, Wonogiri, dan Semarang.',
            'h1' => 'Photobooth di Jawa Tengah, Dekat dari Magetan',
            'lead' => 'Magetan berbatasan langsung dengan Jawa Tengah. Lewat tol Ngawi–Solo atau jalur Cemoro Sewu–Tawangmangu, kota-kota seperti Sragen, Karanganyar, dan Solo justru lebih dekat daripada banyak kota di Jawa Timur.',
            'province' => 'Jawa Tengah',
        ],
    ],
];
