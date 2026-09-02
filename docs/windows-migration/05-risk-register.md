# Daftar Risiko — Migrasi Windows

Skala: **T** tinggi · **S** sedang · **R** rendah

| ID | Risiko | Dampak | Peluang | Mitigasi | Gerbang |
|---|---|---|---|---|---|
| R-01 | Borderless 4R tidak keluar benar dari driver Epson Windows | **T** — premis migrasi gugur | R | Spike Fase 0 sebelum apa pun dikerjakan | Fase 0 |
| R-02 | Lisensi Sony Camera Remote SDK melarang / membatasi pemakaian komersial | **T** — jalur shutter 24 MP buntu | S | Baca ketentuan sebelum menulis kode. Fallback: `hdmiOnly` 1080p yang sudah jalan sejak Fase 3 | Fase 4 |
| R-03 | ZV-E10 tidak didukung versi SDK terbaru | **T** | S | Verifikasi daftar model di gerbang Fase 4 | Fase 4 |
| R-04 | Windows Update me-reboot mesin di jam operasional | **T** — kios mati saat ada antrean | **T** | Windows 11 Pro + Group Policy, active hours mencakup seluruh jam buka, tunda feature update | Fase 7 + soak |
| R-05 | Mini PC terlalu lemah, kiosk justru lebih lambat dari tablet | **S** | S | Ukur baseline Android dulu; jangan ambil N100 termurah; bandingkan sebelum membeli banyak unit | Sebelum beli |
| R-06 | Mati listrik merusak filesystem / job cetak | **T** | S | UPS ~500VA wajib + shutdown otomatis. Tablet punya baterai; mini PC tidak | Fase 7 |
| R-07 | Helper SDK Sony hang dan menyeret aplikasi kiosk | **T** | **T** | Wajib proses terpisah, bukan DLL in-process. Deteksi socket putus → `hdmiOnly` | Fase 4 |
| R-08 | Pelanggan berhasil keluar dari aplikasi ke desktop | **S** — memalukan | S | `window_manager` + blokir `Alt+F4`/tombol Windows + Shell Launcher | Fase 7 |
| R-09 | Sentuhan meleset 90° setelah monitor dirotasi portrait | **S** | **T** | Tablet PC Settings → Setup, ikat sentuh ke display yang benar. Masukkan ke checklist instalasi | Fase 6 |
| R-10 | Lisensi Windows abu-abu terdeaktivasi di mesin komersial | **S** | S | Anggarkan lisensi asli sejak awal | Sebelum beli |
| R-11 | Capture card terkunci di bawah 1080p di Windows | **S** | R | Verifikasi di Fase 3, laporkan bila terjadi | Fase 3 |
| R-12 | Migrasi melar karena tujuan samar | **S** — jadwal meleset jauh | **T** | Empat tujuan bernama di PRD. Perubahan di luar itu wajib ditanyakan dulu | Terus-menerus |
| R-13 | Repo rusak / build Android mati di tengah migrasi | **T** — jaring pengaman hilang | S | Satu codebase, tanpa fork. Build Android diuji tiap akhir fase (NFR-05) | Tiap fase |
| R-14 | Ekspektasi keliru: mengira Windows memperbaiki kualitas cetak & kecepatan | **S** — dianggap gagal padahal berhasil | **T** | Non-tujuan ditulis eksplisit di PRD §4 dan di prompt agent | Terus-menerus |
| R-15 | Bantuan AI dianggap bisa memotong seluruh jadwal | **S** | S | AI memotong bagian yang diukur dalam baris kode, bukan yang diukur dalam colok-kabel. Soak test 7 hari tidak bisa dipercepat | Terus-menerus |
| R-16 | Kehilangan portabilitas menghambat model bisnis event keliling | **S** | ? | Tergantung model bisnis. Tablet Android tetap dipelihara sebagai unit portabel | Keputusan bisnis |
| R-17 | Panas berlebih di enclosure tertutup | **S** | S | Ventilasi + mini PC berkipas. Pantau selama soak test | Soak |
| R-18 | Build Android mati sendiri di masa depan: `flutter_uvc_camera` (fork) dan `camera_android_camerax` masih memakai Kotlin Gradle Plugin, dan Flutter versi mendatang akan menolaknya | **S** — jaring pengaman tablet hilang | **T** | Jangan upgrade Flutter selama migrasi berlangsung. Setelah Windows terbukti stabil di lapangan, risiko ini otomatis mengecil karena jalur Android tidak lagi kritis | C8 |

---

## Risiko dengan Peluang Tinggi — Perhatian Khusus

Empat baris berpeluang **T** dan pantas mendapat perhatian sejak awal:

**R-04 (Windows Update)** — ini musuh nomor satu kiosk Windows 24/7, dan
satu-satunya cara menemukannya adalah menjalankan mesin berhari-hari. Karena itu
soak test 7 hari bersifat wajib, bukan formalitas.

**R-07 (helper SDK hang)** — pengalaman jalur PTP di Android menunjukkan lapisan
ini akan bermasalah. Batas proses bukan preferensi arsitektur, melainkan syarat.

**R-12 & R-14 (scope melar & ekspektasi keliru)** — keduanya risiko manusia, dan
justru yang paling sering menenggelamkan proyek migrasi. Mitigasinya adalah
membaca ulang §3 dan §4 PRD setiap kali muncul ide "sekalian saja".
