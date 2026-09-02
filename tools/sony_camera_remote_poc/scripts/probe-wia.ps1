<#
    probe-wia.ps1 — Apakah contoh Sony akan MELIHAT kamera?
    =======================================================

    HANYA MEMBACA.

    Contoh Camera Control PTP memakai WIA (IWiaDevMgr). Jadi pertanyaan yang
    sebenarnya bukan "apakah kamera muncul di Device Manager", melainkan
    "apakah kamera terdaftar di WIA Device Manager".

    Skrip ini menanyakannya langsung lewat COM yang sama dengan yang dipakai
    contoh Sony. Kalau kamera muncul di bagian [A], contoh itu akan melihatnya.

    Jalankan: powershell -ExecutionPolicy Bypass -File .\probe-wia.ps1
#>

$ErrorActionPreference = 'Continue'
Write-Host ""
Write-Host "=== PROBE WIA - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -ForegroundColor Cyan
Write-Host ""

# ── [A] Perangkat WIA — INI YANG MENENTUKAN ─────────────────────────────────
Write-Host "[A] Perangkat terdaftar di WIA Device Manager" -ForegroundColor Yellow
Write-Host "    (contoh Sony memakai antarmuka yang sama persis)" -ForegroundColor DarkGray
try {
    $wia = New-Object -ComObject WIA.DeviceManager
    $n = $wia.DeviceInfos.Count
    if ($n -eq 0) {
        Write-Host "    KOSONG - WIA tidak melihat perangkat apa pun." -ForegroundColor Red
        Write-Host "    Contoh Sony TIDAK akan menemukan kamera." -ForegroundColor Red
    } else {
        for ($i = 1; $i -le $n; $i++) {
            $d = $wia.DeviceInfos.Item($i)
            $name = try { $d.Properties("Name").Value } catch { "?" }
            $desc = try { $d.Properties("Description").Value } catch { "" }
            $id   = try { $d.DeviceID } catch { "" }
            $type = switch ($d.Type) { 1 {"Scanner"} 2 {"Camera"} 3 {"Video"} default {"Type=$($d.Type)"} }
            Write-Host "    OK  $name  [$type]" -ForegroundColor Green
            Write-Host "        $desc"
            Write-Host "        $id"
        }
    }
} catch {
    Write-Host "    GAGAL membuka WIA.DeviceManager: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# ── [B] Perangkat Sony yang BENAR-BENAR tercolok sekarang ───────────────────
Write-Host "[B] Perangkat Sony yang tercolok SAAT INI (Present saja)" -ForegroundColor Yellow
$present = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
           Where-Object { $_.InstanceId -match 'VID_054C' }
if (-not $present) {
    Write-Host "    Tidak ada perangkat Sony tercolok." -ForegroundColor Red
} else {
    foreach ($d in $present) {
        $svc = (Get-PnpDeviceProperty -InstanceId $d.InstanceId `
                -KeyName 'DEVPKEY_Device_Service' -ErrorAction SilentlyContinue).Data
        Write-Host "    $($d.FriendlyName)"
        Write-Host "      kelas   : $($d.Class)"
        Write-Host "      service : $svc"
        Write-Host "      id      : $($d.InstanceId)"
        Write-Host "      ---"
    }
}
Write-Host ""

# ── [C] Kelas Image (WIA) di Device Manager ────────────────────────────────
Write-Host "[C] Perangkat kelas Image / Camera / WPD yang tercolok" -ForegroundColor Yellow
$img = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
       Where-Object { $_.Class -in @('Image','Camera','WPD') }
if ($img) {
    $img | ForEach-Object { Write-Host "    [$($_.Class)] $($_.FriendlyName)  ($($_.Status))" }
} else {
    Write-Host "    Tidak ada." -ForegroundColor DarkGray
}
Write-Host ""

Write-Host "=== CARA MEMBACA ===" -ForegroundColor Cyan
Write-Host "Bagian [A] memuat ZV-E10  -> contoh Sony akan menemukannya. LANJUT."
Write-Host "Bagian [A] kosong/tanpa ZV-E10 -> kamera masih dipegang driver lain"
Write-Host "  (lihat 'service' di [B]; 'libusbK' berarti masih milik Imaging Edge)."
Write-Host ""
