# Spike C0 — Uji Silent Print Epson L8050 di Windows

Gerbang pertama migrasi Windows. Tujuannya **satu**: membuktikan Epson L8050
bisa dicetak dari Flutter Windows **tanpa dialog**, dengan hasil **4R
borderless** yang benar.

Kalau uji ini gagal, seluruh premis migrasi gugur — dan lebih baik tahu
sekarang dengan biaya satu hari daripada setelah dua minggu.

## Prasyarat

| # | Kebutuhan | Cara cek |
|---|---|---|
| 1 | Flutter SDK | `flutter --version` |
| 2 | **Visual Studio Build Tools + workload "Desktop development with C++"** | `flutter doctor` — baris "Visual Studio" harus centang hijau |
| 3 | Driver Epson L8050 resmi | Printer muncul di Settings → Printers & scanners |
| 4 | **Developer Mode Windows aktif** | `start ms-settings:developers` → nyalakan. Tanpa ini: *"Building with plugins requires symlink support"* |
| 5 | Printer tersambung & menyala | **Lewat USB** untuk spike (hilangkan variabel jaringan). Isi kertas foto **4R (10x15 cm)** |

> ⚠️ Nomor 2 paling sering terlewat. Tanpa itu `flutter build windows` gagal
> dengan pesan yang membingungkan.
>
> ⚠️ Nomor 4 hanya perlu di **mesin development**. Mesin kiosk yang menjalankan
> `.exe` hasil installer tidak memerlukan Developer Mode.
>
> Setelah menyalakan Developer Mode, **tutup dan buka ulang PowerShell** sebelum
> menjalankan `flutter run` lagi.

## Menjalankan

Folder ini hanya berisi `pubspec.yaml` dan `lib/main.dart`. Scaffolding Windows
digenerate oleh Flutter:

```powershell
# 1. Buat proyek baru di luar repo
cd C:\
flutter create --platforms=windows spike_print_run
cd spike_print_run

# 2. Timpa dua file ini dengan yang ada di folder tools/spike_print
copy E:\Photobooth\tools\spike_print\pubspec.yaml .\pubspec.yaml
copy E:\Photobooth\tools\spike_print\lib\main.dart .\lib\main.dart

# 3. Jalankan
flutter pub get
flutter run -d windows
```

## Urutan hemat: jangan bakar kertas foto dulu

### Putaran 1 — nol kertas, nol tinta

**Pause printernya dulu** sebelum menjalankan spike:

> Settings → Bluetooth & devices → Printers & scanners → Epson L8050 →
> Open print queue → menu Printer → **Pause Printing**

Lalu jalankan spike dan tekan tombol cetak. Job masuk antrean tanpa mencetak
apa pun, dan kamu sudah bisa membuktikan bagian terpenting dari C0:

- **C0-4** tidak ada dialog muncul sama sekali
- job diterima dengan nama dan ukuran halaman yang benar (lihat di print queue)
- **C0-1** printer terdeteksi

Ulangi sebanyak yang kamu mau. Nol biaya. Hapus job dari antrean setelah dicek.

### Putaran 2 — satu lembar untuk borderless

Resume printing, pastikan mode **Hemat tinta** menyala (default), lalu cetak
**satu** lembar. Coverage tintanya sekitar 2% — kertas dibiarkan putih, yang
dicetak hanya garis tepi dan tangga penanda.

### Putaran 3 — hanya bila perlu

Mode **Warna penuh** (blok solid sampai tepi, ~95% coverage) baru dipakai
menjelang go-live, saat kamu ingin memeriksa warna dan cakupan penuh. Jangan
dipakai untuk uji berulang.

---

## Yang diuji

Tekan tombolnya berurutan, catat hasilnya di
[`06-cycle-plan.md`](../../docs/windows-migration/06-cycle-plan.md).

| Tombol | Checklist | Lulus bila |
|---|---|---|
| 1. DETEKSI PRINTER | **C0-1** | Epson L8050 muncul di daftar |
| 2. CETAK UJI (format aplikasi) | **C0-2, C0-3, C0-4** | Kertas keluar, borderless benar, **nol dialog** |
| 3. CETAK UJI (setelan driver) | pembanding | Bandingkan mana yang borderless-nya benar |

### Cara menilai borderless (mode hemat tinta)

Halaman ujinya tidak cuma bilang lulus/gagal — dia **mengukur**:

- **Garis hitam tepi** harus tercetak di keempat sisi. Sisi yang garisnya hilang
  adalah sisi yang terpotong.
- **Penanda sudut L** harus utuh sampai ke pojok kertas.
- **Tangga milimeter** di tepi atas dan kiri: angka terkecil yang **masih
  terlihat** menunjukkan berapa milimeter yang dipotong printer di sisi itu.
  Kalau angka 1 dan 2 hilang tapi 3 terlihat, berarti terpotong sekitar 3 mm.
- Garis abu-abu 3 mm dari tepi adalah pembanding — kalau garis hitam tepi hilang
  tapi yang abu-abu ada, potongannya di bawah 3 mm.

Informasi ini yang kamu butuhkan untuk mengatur ulang setelan driver, bukan
sekadar tahu bahwa borderless gagal.

Kalau tombol 2 memberi garis putih tapi tombol 3 tidak, berarti jawabannya ada
di setelan default driver Epson — atur 4R borderless di Printing Preferences
Windows, lalu pakai `usePrinterSettings: true` di aplikasi utama.

### ⚠️ Yang paling penting diperhatikan

**Pandangi layar selama mencetak.** Kalau ada dialog apa pun yang muncul —
sekejap pun — itu kegagalan C0-4, dan harus dilaporkan. Justru dialog inilah
seluruh alasan migrasi ini ada.

## Belum tercakup: C0-5 (baca status printer)

Package `printing` tidak mengekspos status printer. Untuk C0-5 (deteksi kertas
habis / offline) coba salah satu: `printing_ffi`, `windows_printer`, atau
PowerShell `Get-PrintJob` / `Get-Printer` sebagai pembanding cepat.

Catat pustaka mana yang berhasil — itu yang akan dipakai di Cycle C2 untuk
mengisi telemetri heartbeat.

## Melaporkan hasil

Isi di `06-cycle-plan.md` → Cycle C0, dan lampirkan:

1. Foto fisik hasil cetak (untuk menilai borderless)
2. Rekaman layar saat mencetak (untuk membuktikan tidak ada dialog)
3. Isi log dari panel hitam di aplikasi

---

## Kalau borderless jalan di satu sumbu saja

Gejala umum: **kiri-kanan sudah penuh, atas-bawah masih putih.** Artinya
borderless aktif tapi penskalaannya tidak menutup seluruh tinggi kertas.

Coba berurutan, satu perubahan per lembar:

| # | Yang dicoba | Di mana |
|---|---|---|
| 1 | Ganti ukuran halaman di dropdown: `10x15 cm` lalu `4R 102x152` | Aplikasi spike |
| 2 | Naikkan **Expansion / Perbesaran** ke Medium atau Max | Printing Preferences → Borderless |
| 3 | Pastikan paper size driver memakai varian **Borderless**, bukan yang biasa | Printing Preferences → Paper Size |
| 4 | Coba varian **BLEED +2mm / +4mm** di dropdown | Aplikasi spike |
| 5 | Coba tombol **3. CETAK UJI (setelan driver)** | Aplikasi spike |

Varian BLEED sengaja membuat halaman lebih besar dari kertas supaya isinya
melimpah keluar. Untuk foto sungguhan inilah cara yang benar: beri bleed, biar
printer yang memotong. Kalau BLEED menutup atas-bawah dengan sempurna, catat
angkanya — itu yang nanti dipakai di `printer_service_windows.dart` pada Cycle C2.

## Menekan pemakaian tinta lebih jauh

Selain mode hemat tinta di aplikasi, atur di **Printing Preferences** driver:

- **Quality: Draft / Economy** — untuk uji geometri, kualitas foto tidak relevan
- **Grayscale / Black ink only** — uji borderless tidak butuh warna sama sekali
- Kembalikan ke Photo/High **hanya** saat uji warna menjelang go-live

Kombinasi mode hemat tinta + Draft + grayscale membuat satu lembar uji hampir
tidak berbiaya tinta.

---

## Strip 2x6

Ada dua cara mencetak strip photobooth, dan keduanya tersedia di dropdown:

| Opsi | Kapan dipakai |
|---|---|
| **Strip 2x6 inci — 50,8 x 152,4 mm** | Kalau kamu sudah mendaftarkan ukuran kertas custom 2x6 di driver Epson (Printing Preferences → User-Defined Paper Size). Printer memakan kertas selebar 2 inci |
| **4x6 isi 2 strip 2x6** | **Cara yang lazim.** Cetak di kertas 4R biasa, dua strip bersebelahan, lalu dipotong di tengah. Tidak perlu kertas khusus, tidak perlu daftar ukuran custom |

Opsi kedua mencetak garis potong putus-putus di tengah beserta label STRIP 1 /
STRIP 2, jadi kamu bisa memeriksa geometrinya sebelum dipotong sungguhan.
Posisi garis dihitung dari tengah **kertas**, bukan tengah halaman PDF, sehingga
tetap benar walau bleed-nya asimetris.

## Bleed per sisi — obat borderless yang timpang

Kalau borderless hanya menutup satu sumbu (misal kiri-kanan penuh tapi
atas-bawah masih putih), penyebabnya halaman PDF pas persis seukuran kertas.
Begitu driver menskalakan supaya muat, sisi yang lain menyisakan pita putih.

Obatnya: **buat halaman PDF sedikit lebih besar dari kertas**, biar isinya
melimpah keluar dan dipotong printer. Itu memang cara cetak foto borderless yang
benar di dunia percetakan — bukan akal-akalan.

Empat stepper (Atas / Bawah / Kiri / Kanan) menaikkan halaman 0,5 mm per klik.
Baris biru di bawahnya menunjukkan ukuran halaman PDF yang dihasilkan.

### Cara mencari angkanya

1. Mulai dari 0 semua, cetak sekali → lihat sisi mana yang putih
2. Naikkan **hanya sisi yang bermasalah** 1 mm, cetak lagi
3. Ulangi sampai putihnya hilang, lalu **turunkan 0,5 mm** untuk cari batas minimum
4. Bleed berlebihan tidak merusak apa-apa, hanya memotong lebih banyak gambar —
   jadi ambil angka terkecil yang sudah menutup

Nilainya bisa asimetris. Wajar: mekanisme penarik kertas kebanyakan printer
memang tidak simetris antara tepi depan dan tepi belakang.

> 📌 **Catat angka yang menang.** Kombinasi ukuran kertas + bleed per sisi +
> setelan Expansion driver adalah keluaran utama Cycle C0, dan langsung dipakai
> di `printer_service_windows.dart` pada Cycle C2.

---

## ⚠️ TEMUAN C0 TERPENTING: ukuran kertas datang dari DRIVER

Gejala: print queue menunjukkan **Paper Size: A4** padahal aplikasi mengirim
50,8 x 152,4 mm.

Penyebabnya bukan bug di halaman uji. Parameter `format:` pada
`Printing.directPrintPdf()` **hanya menentukan ukuran kanvas PDF**. Di Windows,
package `printing` mengirim job ke spooler memakai DEVMODE default printer yang
sedang aktif — dan kalau default-nya A4, driver akan menskalakan PDF kita agar
muat di A4.

Ini menjelaskan gejala borderless yang timpang: driver tidak pernah tahu kita
sedang mencetak 4R atau strip.

### Yang harus dilakukan sekarang

1. Tekan tombol **BUKA PRINTING PREFERENCES** di aplikasi (atau Settings >
   Printers & scanners > EPSON L8050 Series > Printing preferences)
2. **Paper Size** > pilih varian **Borderless** untuk 4x6 / 10x15 cm.
   Untuk strip 2x6, daftarkan dulu **User-Defined Paper Size** 50,8 x 152,4 mm
3. **Borderless** > centang, **Expansion** > Medium
4. Set juga di **Printer Properties > Advanced > Printing Defaults** — dua
   tempat ini terpisah, dan sebagian aplikasi membaca yang kedua
5. Cetak lagi dengan tombol **3. CETAK UJI (setelan driver)**
6. Pastikan print queue sekarang menunjukkan ukuran yang benar, bukan A4

### Implikasi untuk Cycle C2 — catat ini

Kalau kiosk hanya pernah mencetak SATU ukuran, mengandalkan default driver sudah
cukup dan `printing` saja memadai.

Tapi LumaBooth mencetak **4R dan strip 2x6**. Berpindah ukuran per job berarti
aplikasi harus bisa mengubah DEVMODE saat mengirim job — dan `printing` tidak
menyediakan itu. Artinya `printer_service_windows.dart` kemungkinan besar butuh
**`printing_ffi`** atau **`windows_printer`**, bukan `printing` saja.

Ini persis jenis temuan yang membuat spike C0 sepadan: ditemukan di hari
pertama, bukan di minggu ketiga.

## Peringatan font di log

```
Helvetica-Bold has no Unicode support
Unable to find a font to draw "—" (U+2014)
```

Font bawaan PDF tidak mendukung karakter non-ASCII. Sudah diperbaiki dengan
membersihkan teks lewat helper `ascii()` sebelum digambar. Kalau nanti aplikasi
utama perlu teks Indonesia bertanda khusus di PDF, harus memuat font TTF sendiri.

---

## ⛔ FAKTA TERBUKTI: kertas 2x6 sungguhan MUSTAHIL di Epson L8050

Diuji 2026-09-01 langsung di driver.

**User-Defined Paper Size** di Printing Preferences L8050 mentok pada **lebar
minimum 89 mm**. Strip 2x6 inci butuh 50,8 mm. Tidak bisa dikurangi, dan tidak
ada cara mengakalinya dari sisi aplikasi — batas itu ada di driver.

Tinggi 152,4 mm sendiri tidak masalah.

### Konsekuensi

Strip photobooth **wajib** dicetak sebagai dua strip di atas selembar 4R, lalu
dipotong tengah. Ini juga cara yang lazim di industri, dan sudah jadi rencana di
`docs/hardware/02-printer.md` sejak awal.

Opsi "kertas 2x6" sudah dibuang dari dropdown supaya tidak ada yang mencoba
ulang. Yang tersisa dua, keduanya memotong tengah:

- `STRIP: 4x6 isi 2 strip 2x6` — tiap strip 50,8 x 152,4 mm
- `STRIP: 10x15cm isi 2 strip` — tiap strip 50 x 150 mm

Lebar strip mengikuti lebar kertas yang dipilih, dan angkanya ikut tercetak di
halaman uji supaya bisa diverifikasi dengan penggaris.

### Dampak ke Cycle C2 — ini justru menyederhanakan

Karena semua cetakan memakai kertas 4R, **ukuran kertas di driver tidak pernah
berubah antar job**. Yang berubah hanya tata letak di dalam PDF: satu foto besar,
atau dua strip bersebelahan.

Itu berarti kebutuhan mengubah DEVMODE per job hilang, dan `printing` saja
kemungkinan sudah cukup untuk `printer_service_windows.dart` —
`printing_ffi` mungkin hanya diperlukan untuk membaca status printer (C0-5).

---

## Halaman uji: satu konten tetap

Isi halaman uji **tidak pernah berubah** — tidak ada tanggal, tidak ada angka
setelan yang ikut tercetak. Tujuannya supaya dua lembar dari percobaan berbeda
bisa ditumpuk dan dibandingkan langsung. Catatan setelan mana yang dipakai ada
di log layar, bukan di kertas.

Isinya:

| Elemen | Gunanya |
|---|---|
| Bingkai hitam tepat di tepi | Sisi yang garisnya hilang = sisi yang dipotong |
| Bingkai abu-abu 3 mm dari tepi | Kalau bingkai luar hilang tapi ini ada, potongan di bawah 3 mm |
| Penanda sudut L | Memastikan keempat pojok utuh |
| Kata **ATAS / BAWAH / KIRI / KANAN** dekat tiap tepi (1,5 mm) | Kata yang tidak tercetak menunjukkan sisi mana yang terpotong lebih dari 1,5 mm — tanpa perlu mengukur |
| Tulisan tengah: LUMABOOTH / TEST PRINT / BORDERLESS CHECK | Konfirmasi teks tercetak dan posisinya di tengah |
| Garis potong (khusus opsi STRIP) | Memeriksa geometri strip sebelum dipotong |

Coverage tinta sekitar **1%**. Mode warna penuh sudah dihapus — tidak dipakai
lagi.

### Membaca hasilnya

- Keempat kata muncul + bingkai luar utuh → **borderless benar**
- Kata `ATAS` hilang → tepi atas terpotong lebih dari 1,5 mm → naikkan bleed Atas
- Semua kata muncul tapi ada pita putih di pinggir → borderless kurang menutup →
  naikkan bleed di sisi itu, atau naikkan Expansion di driver
