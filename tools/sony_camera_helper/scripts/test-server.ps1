<#
.SYNOPSIS
  Klien uji untuk sony_camera_helper mode --serve.

.DESCRIPTION
  Menyambung ke helper di loopback, mengirim perintah, mencetak balasan.
  Tanpa argumen: menjalankan skenario C4-B5 (connect, status, tiga capture,
  status, disconnect).

.EXAMPLE
  # Terminal 1
  build\Release\sony_camera_helper.exe --serve --verbose

  # Terminal 2
  powershell -ExecutionPolicy Bypass -File scripts\test-server.ps1
  powershell -ExecutionPolicy Bypass -File scripts\test-server.ps1 -Commands 'status','capture'
  powershell -ExecutionPolicy Bypass -File scripts\test-server.ps1 -Interactive
#>
[CmdletBinding()]
param(
  [int]$Port = 45455,
  [string[]]$Commands,
  [switch]$Interactive
)

$ErrorActionPreference = 'Stop'

$client = New-Object System.Net.Sockets.TcpClient
try {
  $client.Connect('127.0.0.1', $Port)
} catch {
  Write-Host "Tidak bisa menyambung ke 127.0.0.1:$Port" -ForegroundColor Red
  Write-Host "Pastikan helper sudah jalan: sony_camera_helper.exe --serve" -ForegroundColor Yellow
  exit 1
}

$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$writer.AutoFlush = $true
$reader = New-Object System.IO.StreamReader($stream)

function Send-Cmd([string]$line) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $writer.WriteLine($line)
  $reply = $reader.ReadLine()
  $sw.Stop()
  Write-Host ("-> {0}" -f $line) -ForegroundColor Cyan
  if ($reply -match '"ok":true') {
    Write-Host ("<- {0}" -f $reply) -ForegroundColor Green
  } else {
    Write-Host ("<- {0}" -f $reply) -ForegroundColor Red
  }
  Write-Host ("   ({0} ms)" -f $sw.ElapsedMilliseconds) -ForegroundColor DarkGray
  Write-Host ''
  return $reply
}

function To-Line([string]$c) {
  if ($c.TrimStart().StartsWith('{')) { return $c }
  return '{"cmd":"' + $c + '"}'
}

try {
  if ($Interactive) {
    Write-Host "Ketik nama perintah (connect/status/capture/disconnect/ping) atau JSON penuh." -ForegroundColor Yellow
    Write-Host "Kosongkan lalu Enter untuk keluar.`n" -ForegroundColor Yellow
    while ($true) {
      $line = Read-Host 'cmd'
      if ([string]::IsNullOrWhiteSpace($line)) { break }
      Send-Cmd (To-Line $line) | Out-Null
    }
  }
  elseif ($Commands) {
    foreach ($c in $Commands) { Send-Cmd (To-Line $c) | Out-Null }
  }
  else {
    # Skenario C4-B5
    Send-Cmd '{"cmd":"ping"}'    | Out-Null
    Send-Cmd '{"cmd":"connect"}' | Out-Null
    Send-Cmd '{"cmd":"status"}'  | Out-Null
    for ($i = 1; $i -le 3; $i++) {
      Write-Host "--- capture $i dari 3 ---" -ForegroundColor Magenta
      Send-Cmd '{"cmd":"capture"}' | Out-Null
    }
    Send-Cmd '{"cmd":"status"}'     | Out-Null
    Send-Cmd '{"cmd":"disconnect"}' | Out-Null
  }
}
finally {
  $writer.Dispose()
  $reader.Dispose()
  $client.Close()
}
