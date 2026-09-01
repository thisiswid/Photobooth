# Normalisasi CRLF — Sekali Jalan

Dikerjakan sebelum Cycle C1, supaya seluruh diff migrasi bisa dibaca.

## Masalahnya

Repo menampilkan **103 file "modified"** padahal isinya tidak berubah. Contoh:
`.gitignore` tampil sebagai 34 baris dihapus + 34 baris ditambah dengan isi yang
persis sama. Penyebabnya perbedaan line ending CRLF (Windows) vs LF.

Total noise: sekitar **15.000 baris** "perubahan" yang tidak mengubah apa pun.

Kalau dibiarkan, setiap file yang disentuh selama C1-C7 akan tampil sebagai
seluruh isinya berubah, dan tidak ada yang bisa membedakan perubahan asli dari
noise.

## Perintahnya

Jalankan dari **PowerShell di Windows**, bukan dari lingkungan lain, supaya git
memakai konfigurasi Windows-mu.

```powershell
cd E:\Photobooth

# 1. Pastikan tidak ada kerjaan yang belum di-commit selain noise ini.
#    Kalau ada perubahan asli yang belum di-commit, commit dulu SEBELUM lanjut.
git status

# 2. Pastikan berada di branch migrasi
git checkout feat/windows-migration

# 3. .gitattributes sudah dibuat dan di-commit. Sekarang minta git
#    menghitung ulang seluruh file memakai aturan itu.
git add --renormalize .

# 4. Lihat apa yang akan masuk — seharusnya BANYAK file, semuanya line ending
git status --short

# 5. Commit sebagai satu commit khusus, terpisah dari perubahan kode apa pun
git commit -m "chore: normalisasi line ending seluruh repo (CRLF -> LF)"
```

## Setelah itu

```powershell
git status
```

Harus bersih, atau hanya menyisakan perubahan yang memang kamu kerjakan.
Mulai saat itu setiap diff menunjukkan baris yang benar-benar berubah saja.

## Kalau `git status` masih ramai setelah normalisasi

Berarti ada perubahan asli yang belum di-commit dan tersembunyi di balik noise.
Periksa satu per satu:

```powershell
git diff --stat
git diff -- flutter_app/lib/core/services/printer_service.dart
```

## Catatan

- Commit normalisasi ini akan besar. Itu wajar dan memang tujuannya:
  **satu commit berisik, ditukar dengan semua commit setelahnya jadi bersih.**
- Jangan campur commit ini dengan perubahan kode apa pun.
- Kalau repo ini punya branch lain yang masih aktif, merge dari branch tersebut
  setelah normalisasi bisa memunculkan konflik line ending. Selesaikan dengan
  `git checkout --theirs` / `--ours` lalu `git add --renormalize` pada file itu.
