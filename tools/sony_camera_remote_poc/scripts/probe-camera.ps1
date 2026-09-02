<#
    probe-camera.ps1 — Pemeriksaan awal POC Camera Remote Command
    ================================================================

    HANYA MEMBACA. Skrip ini tidak mengubah driver, tidak mengubah setelan
    kamera, dan tidak mengirim satu pun perintah ke kamera.

    Gunanya menjawab pertanyaan yang harus dijawab SEBELUM Camera Remote
    Command diterapkan:

      1. Apakah Windows melihat ZV-E10 di USB?
      2. Vendor/Product ID-nya berapa?
      3. Driver apa yang sedang memegang perangkat itu?
      4. Apakah kamera muncul sebagai perangkat WPD/MTP?
      5. Apakah Imaging Edge sedang berjalan dan memegang kamera?

    Pertanyaan ke-3 dan ke-5 penting: satu perangkat USB hanya bisa dipegang
    satu pemilik. Kalau Imaging Edge sedang jalan, POC tidak akan bisa connect
    — dan itu akan terlihat seperti kegagalan API padahal bukan.

    Jalankan:  powershell -ExecutionPolicy Bypass -File .\probe-camera.ps1
#>

$ErrorActionPreference = 'Continue'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Write-Host ""
Write-Host "=== PROBE KAMERA SONY - $stamp ===" -ForegroundColor Cyan
Write-Host ""

# ── 1. Perangkat USB Sony ────────────────────────────────────────────────────
# Sony Vendor ID = 0x054C
Write-Host "[1] Perangkat USB dengan Vendor ID Sony (054C)" -ForegroundColor Yellow
$sony = Get-PnpDevice | Where-Object { $_.InstanceId -match 'VID_054C' }
if (-not $sony) {
    Write-Host "    TIDAK DITEMUKAN perangkat Sony di USB." -ForegroundColor Red
    Write-Host "    Periksa: kamera menyala, kabel USB-C tersambung," -ForegroundColor Red
    Write-Host "    dan MENU > Setup > USB > USB Connection = PC Remote." -ForegroundColor Red
} else {
    $sony | ForEach-Object {
        Write-Host "    Nama       : $($_.FriendlyName)"
        Write-Host "    InstanceId : $($_.InstanceId)"
        Write-Host "    Kelas      : $($_.Class)"
        Write-Host "    Status     : $($_.Status)"
        Write-Host "    ---"
    }
}
Write-Host ""

# ── 2. Driver yang sedang memegang perangkat ────────────────────────────────
Write-Host "[2] Driver yang memegang perangkat" -ForegroundColor Yellow
if ($sony) {
    foreach ($d in $sony) {
        $svc = (Get-PnpDeviceProperty -InstanceId $d.InstanceId `
                -KeyName 'DEVPKEY_Device_Service' -ErrorAction SilentlyContinue).Data
        $desc = (Get-PnpDeviceProperty -InstanceId $d.InstanceId `
                -KeyName 'DEVPKEY_Device_DriverDesc' -ErrorAction SilentlyContinue).Data
        Write-Host "    $($d.FriendlyName)"
        Write-Host "      service    : $svc"
        Write-Host "      driverDesc : $desc"
    }
    Write-Host ""
    Write-Host "    CATATAN: 'WUDFWpdMtp' berarti kamera dipegang stack WPD/MTP bawaan"
    Write-Host "    Windows. 'WinUSB' berarti driver sudah diganti (mis. lewat Zadig)."
} else {
    Write-Host "    Dilewati - tidak ada perangkat Sony." -ForegroundColor DarkGray
}
Write-Host ""

# ── 3. Perangkat WPD (kamera/MTP) ───────────────────────────────────────────
Write-Host "[3] Perangkat portabel (WPD) yang terlihat Windows" -ForegroundColor Yellow
$wpd = Get-PnpDevice -Class 'WPD' -ErrorAction SilentlyContinue
if ($wpd) {
    $wpd | ForEach-Object { Write-Host "    $($_.FriendlyName)  [$($_.Status)]" }
} else {
    Write-Host "    Tidak ada perangkat WPD." -ForegroundColor DarkGray
}
Write-Host ""

# ── 4. Aplikasi Sony yang sedang memegang kamera ────────────────────────────
Write-Host "[4] Proses Sony yang sedang berjalan" -ForegroundColor Yellow
$procs = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -match 'Imaging|Remote|Sony|CaptureOne' }
if ($procs) {
    $procs | ForEach-Object {
        Write-Host "    $($_.ProcessName) (PID $($_.Id))" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "    PERINGATAN: satu perangkat USB hanya bisa dipegang SATU pemilik."
    Write-Host "    Tutup aplikasi di atas sebelum menjalankan POC, kalau tidak"
    Write-Host "    kegagalan connect akan terlihat seperti kesalahan API padahal bukan."
} else {
    Write-Host "    Tidak ada. Bagus - kamera tidak sedang dipegang aplikasi lain."
}
Write-Host ""

# ── 5. Ringkasan lingkungan ─────────────────────────────────────────────────
Write-Host "[5] Lingkungan" -ForegroundColor Yellow
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "    OS       : $($os.Caption) build $($os.BuildNumber)"
Write-Host "    Arsitektur: $env:PROCESSOR_ARCHITECTURE"
Write-Host ""
Write-Host "=== SELESAI ===" -ForegroundColor Cyan
Write-Host "Salin seluruh keluaran di atas ke docs/windows-migration/08-camera-remote-command-poc.md bagian 1."
Write-Host ""
