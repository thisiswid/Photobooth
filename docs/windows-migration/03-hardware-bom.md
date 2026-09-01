# BOM & Spesifikasi Hardware — Unit Kiosk Windows

> **Dua mesin yang berbeda, jangan tertukar:**
>
> - **Mesin development** — laptop Windows yang dipakai ngoding. Cukup untuk
>   seluruh pekerjaan koding dan untuk **spike Cycle C0**. Tidak perlu beli apa
>   pun. Lihat bagian 0.
> - **Mesin produksi kiosk** — yang berdiri di lokasi dan jalan seharian.
>   Spesifikasinya di bagian 1-5. Bisa mini PC, bisa juga laptop (bagian 2.5).

---

## 0. Mesin Development (Laptop)

Untuk ngoding dan menjalankan spike C0, **laptop Windows biasa sudah cukup**.
Tidak perlu menunggu pengadaan hardware kiosk.

Prasyarat yang harus terpasang di laptop:

| # | Kebutuhan | Catatan |
|---|---|---|
| D-1 | Windows 10 / 11 (edisi apa pun) | Pro baru wajib untuk **mesin produksi**, bukan untuk ngoding |
| D-2 | Flutter SDK | `flutter doctor` harus hijau untuk target Windows |
| D-3 | **Visual Studio Build Tools + workload "Desktop development with C++"** | **Wajib.** Tanpa ini `flutter build windows` gagal. Sering terlewat |
| D-4 | Driver Epson L8050 resmi | |
| D-5 | Kabel USB ke printer | Atau printer di jaringan yang sama |

Dengan lima hal ini, **Cycle C0 bisa dijalankan hari itu juga** tanpa menunggu
mini PC datang.

Yang **tidak** bisa dibuktikan di laptop development: perilaku kiosk jangka
panjang (Cycle C8), penguncian Shell Launcher, autologin, dan ketahanan terhadap
mati listrik. Itu semua butuh mesin produksi sungguhan.


## 1. Daftar Belanja per Unit

| # | Item | Wajib | Catatan |
|---|---|---|---|
| 1 | Mini PC | ✅ | Spesifikasi di bagian 2 |
| 2 | Lisensi Windows 11 **Pro** asli | ✅ | Home tidak cukup |
| 3 | Monitor sentuh | ✅ | Spesifikasi di bagian 3 |
| 4 | **UPS ~500VA** | ✅ | Menggantikan baterai tablet |
| 5 | Powered USB hub | ✅ | Sudah dipakai di setup Android |
| 6 | Epson L8050 | ✅ | Sudah ada |
| 7 | Sony ZV-E10 + dummy battery / USB PD | ✅ | Sudah ada |
| 8 | HDMI capture card (MS2109 dsb.) | ✅ | Sudah ada |
| 9 | Kabel USB-C ke USB-C (PC Remote) | ✅ | Sudah ada |
| 10 | Enclosure + ventilasi | ✅ | Baru — tablet dulu all-in-one |

---

## 2. Mini PC

### Yang menentukan

**CPU single-thread lebih penting daripada jumlah core.** `img.decodeImage` di
package `image` adalah pure Dart dan single-threaded per isolate. Ini beban
komputasi terbesar di pipeline setelah setiap jepretan.

> ⚠️ **Peringatan:** mini PC kelas N100 yang paling murah belum tentu menang
> melawan Snapdragon di Lenovo Legion Y700. Memilih CPU terlalu lemah bisa
> menghasilkan kiosk yang **lebih lambat** dari tablet yang digantikan.

### Spesifikasi minimum

| Komponen | Minimum | Disarankan |
|---|---|---|
| CPU | Intel i3 gen 12 / Ryzen 5 5000 | i5 gen 12+ / Ryzen 5 7000+ |
| RAM | 8 GB | 16 GB |
| Storage | SSD 256 GB | SSD 512 GB |
| USB | 4 port, capture card di controller terpisah | 4+ port, minimal 2 jalur USB 3.x |
| Pendinginan | Berkipas bila enclosure tertutup | — |
| OS | Windows 11 **Pro** | — |

### Beban USB — hitung sebelum membeli

Empat perangkat aktif bersamaan:

```text
1. HDMI capture card   (streaming terus-menerus — butuh bandwidth stabil)
2. Kamera Sony         (PC Remote / PTP)
3. Printer Epson       (USB)
4. Kabel sentuh monitor (HID)
```

Banyak mini PC punya 4 port tetapi berbagi satu controller. Pastikan capture card
mendapat jalur sendiri, karena dialah yang paling sensitif terhadap bandwidth.

### Lisensi Windows

Banyak mini PC murah di marketplace datang dengan lisensi Windows abu-abu. Bila
suatu hari terdeaktivasi, muncul watermark di layar dan personalisasi terkunci —
di mesin komersial yang dilihat pelanggan, itu memalukan sekaligus melanggar.
**Anggarkan lisensi asli.**

---

### 2.5 Laptop sebagai Mesin Produksi — Opsi yang Sah

Laptop bisa dipakai sebagai mesin kiosk, dan punya satu keunggulan besar yang
sering tidak disadari.

**Keuntungan:**

| | |
|---|---|
| **Baterai = UPS bawaan** | Ini mengembalikan sifat yang hilang saat pindah dari tablet Android. Menghapus risiko R-06 dan menghemat biaya UPS terpisah |
| All-in-one | Lebih ringkas, lebih mudah dipindah — cocok bila photobooth dipakai untuk event keliling |
| Sudah punya layar | Berguna untuk servis, walau layar pelanggan tetap monitor sentuh eksternal |

**Kerugian yang harus ditangani:**

| Masalah | Penanganan |
|---|---|
| Layar laptop biasanya bukan touchscreen | Tetap butuh monitor sentuh eksternal, kecuali laptopnya memang layar sentuh |
| Menutup lid = sleep | Ubah ke "Do nothing" di Power Options. **Wajib**, kalau lupa kiosk mati sendiri |
| Keyboard & trackpad terjangkau pelanggan | Enclosure, atau lid ditutup dengan monitor eksternal sebagai layar utama |
| Port USB sedikit (2-3) | Powered USB hub wajib — ada 4 perangkat aktif |
| Sering Windows **Home** | Perlu upgrade ke Pro untuk Shell Launcher & Group Policy |
| **Baterai menggelembung** kalau colok 24/7 | Risiko nyata pada laptop yang selalu tersambung daya. Kalau laptopnya mendukung, batasi pengisian di ~80% lewat BIOS/utilitas pabrikan. Periksa fisik baterai secara berkala |
| Termal di enclosure tertutup | Laptop membuang panas lewat sisi dan bawah — jangan tutup ventilasinya |

**Kesimpulan:** untuk 1-2 unit yang sering dipindah, laptop masuk akal dan
baterainya bonus nyata. Untuk armada kiosk menetap, mini PC lebih murah per unit
dan tidak punya masalah baterai menggelembung.

## 3. Monitor Sentuh

| Aspek | Catatan |
|---|---|
| Sentuh | USB HID, plug and play, tidak butuh driver |
| Ukuran | 21-27 inci umum untuk kiosk |
| Resolusi | 1920x1080 memadai; `designSize` aplikasi saat ini 1280x800 (16:10) sehingga butuh kalibrasi |
| Orientasi | Portrait bila mengikuti kanvas hasil 1333x2000 |

### ⚠️ Jebakan rotasi portrait

**Rotasi tampilan dan rotasi sumbu sentuh adalah dua setelan terpisah.** Bila
salah satu tidak ikut diputar, sentuhan meleset 90 derajat dan pelanggan menekan
tombol yang salah.

Perbaikan: `Control Panel → Tablet PC Settings → Setup`, ikat sentuh ke display
yang benar setelah rotasi diterapkan.

### Ergonomi

Pada monitor besar berorientasi portrait, bagian atas layar berada di luar
jangkauan nyaman tangan. **Tombol aksi utama ditaruh di sepertiga bawah layar.**

---

## 4. UPS — Wajib, Bukan Opsional

Lenovo Legion Y700 punya baterai. Artinya kiosk yang berjalan sekarang punya
**UPS bawaan** tanpa disadari: listrik kedip, tablet tidak peduli.

Mini PC tidak punya itu, dan Windows jauh lebih rentan terhadap mati mendadak
daripada Android. Skenario terburuk: listrik padam saat sistem sedang menulis
file, atau saat printer sedang menerima job.

| Spesifikasi | Nilai |
|---|---|
| Kapasitas | ~500VA (cukup untuk mini PC + monitor) |
| Tujuan | Bertahan cukup lama untuk shutdown rapi, bukan untuk terus beroperasi |
| Konfigurasi | Aktifkan shutdown otomatis Windows saat baterai UPS rendah |
| Tidak disambungkan | Printer — beban puncaknya besar dan tidak perlu dilindungi |

---

## 5. Termal & Enclosure

Mini PC + monitor + printer + kamera + hub dalam satu enclosure menghasilkan
panas yang lumayan, dan kiosk sering berdiri di ruang tanpa AC.

- Sisakan jalur ventilasi masuk dan keluar
- Pilih mini PC berkipas bila enclosure tertutup rapat
- Kamera Sony sudah diatur `Auto Power OFF Temp = High`; pastikan sirkulasi
  udaranya tidak tertutup enclosure
- Rapikan kabel — empat perangkat USB plus daya plus HDMI mudah menjadi kusut
  yang menyulitkan servis

---

## 6. Perbandingan dengan Setup Android

| | Android (sekarang) | Windows |
|---|---|---|
| Perangkat utama | 1 tablet all-in-one | Mini PC + monitor terpisah |
| Sumber daya cadangan | Baterai bawaan | UPS eksternal (biaya baru) |
| Portabilitas | Tinggi — cocok untuk event pindah-pindah | Rendah — cocok untuk kios menetap |
| Jumlah kabel | Sedikit | Banyak |
| Biaya per unit | Lebih murah | Lebih mahal |
| Setup per unit | Ritual manual (Accessibility, overlay) | Installer sekali jalan |

**Implikasi:** bila model bisnisnya photobooth keliling untuk event, kerugian
portabilitas ini nyata dan perlu ditimbang. Bila kiosnya menetap, tidak relevan.
