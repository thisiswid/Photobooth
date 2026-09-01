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

## Yang diuji

Tekan tombolnya berurutan, catat hasilnya di
[`06-cycle-plan.md`](../../docs/windows-migration/06-cycle-plan.md).

| Tombol | Checklist | Lulus bila |
|---|---|---|
| 1. DETEKSI PRINTER | **C0-1** | Epson L8050 muncul di daftar |
| 2. CETAK UJI (format aplikasi) | **C0-2, C0-3, C0-4** | Kertas keluar, borderless benar, **nol dialog** |
| 3. CETAK UJI (setelan driver) | pembanding | Bandingkan mana yang borderless-nya benar |

### Cara menilai borderless

Halaman uji dirancang supaya bisa dinilai dengan mata, tanpa alat ukur:

- **Bingkai kuning** harus menyentuh keempat tepi kertas
- **Empat kotak merah di sudut** harus utuh sampai ke pojok kertas
- Kalau ada **garis putih** di pinggir mana pun → borderless **belum** aktif

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
