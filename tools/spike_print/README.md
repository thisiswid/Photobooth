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
