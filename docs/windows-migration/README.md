# Migrasi Kiosk SnapTechBooth: Android → Windows

Kumpulan dokumen untuk pemindahan aplikasi kiosk **sisi pelanggan** dari tablet
Android ke Windows desktop. Backend Laravel dan Admin Panel Filament tidak ikut
pindah.

Status per 2026-09-01: **disetujui untuk Fase 0 (spike cetak)**.

## Urutan baca

| Dokumen | Untuk siapa |
|---|---|
| [00 — PRD](00-prd.md) | Semua. Tujuan, non-tujuan, persyaratan WR/NFR, fase |
| [01 — Matriks Paritas Fitur](01-feature-parity-matrix.md) | QA & produk. Nasib tiap FR-01…FR-29 |
| [02 — Arsitektur Target](02-target-architecture.md) | Engineer. Lapisan, facade, struktur file, jalur cetak & capture |
| [03 — BOM & Hardware](03-hardware-bom.md) | Pengadaan. Spesifikasi mini PC, monitor, UPS |
| [04 — Rencana Uji & Penerimaan](04-test-acceptance.md) | QA. Baseline, penerimaan per fase, injeksi kegagalan, soak test |
| [05 — Daftar Risiko](05-risk-register.md) | Pemilik proyek |
| [06 — Rencana Cycle & Papan Pelacakan](06-cycle-plan.md) | **Papan kerja harian.** Checklist per cycle, gerbang, catatan harian |
| [Prompt untuk AI Agent](../windows-migration-prompt.md) | Instruksi kerja rinci per fase |

## Inti Persoalan

Ketiga jalur hardware di Android berjalan di atas workaround, bukan API resmi:
cetak ditambal Accessibility + overlay, shutter memakai opcode vendor hasil
rekayasa balik, preview butuh fork plugin yang dipatch sendiri. Di Windows
ketiganya punya API resmi yang didukung vendor.

## Empat Tujuan Bernama

1. Silent print sejati
2. Status printer terbaca
3. Shutter di atas API resmi
4. Setup unit baru yang bisa diulang

Perubahan yang tidak melayani salah satu dari empat ini berada di luar cakupan.

## Yang **Tidak** Diperbaiki Migrasi Ini

Kualitas cetak (dibatasi kanvas template backend 1333x2000), kecepatan decode
gambar (dibatasi package `image` yang pure Dart), dan kecepatan transfer foto
(dibatasi USB 2.0 pada ZV-E10). Lihat PRD §4.
