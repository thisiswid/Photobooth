; ============================================================================
;  SnapTechBooth — installer kiosk Windows
;  Inno Setup 6.x
;
;  Build dulu kedua komponennya, baru compile skrip ini:
;
;    cd flutter_app
;    flutter build windows --release
;
;    cd ..\tools\sony_camera_helper
;    build.bat
;
;  Lalu buka berkas ini dengan Inno Setup Compiler dan tekan Compile.
;  Hasilnya: installer\output\SnapTechBooth-Setup-<versi>.exe
;
;  CATATAN: installer ini memasang PERANGKAT LUNAK. Penguncian kiosk
;  (autologin, blokir tombol, jam aktif Windows Update) adalah setelan sistem
;  operasi yang TIDAK diotomatiskan di sini — mengubahnya diam-diam dari
;  installer berisiko dan sulit dilacak kalau salah. Langkah-langkahnya ada di
;  docs\deployment-windows.md sebagai checklist per unit.
; ============================================================================

#define AppName        "SnapTechBooth"
#define AppVersion     "1.0.0"
#define AppPublisher   "SnapTechBooth"
#define AppExeName     "snaptechbooth.exe"
#define HelperExeName  "sony_camera_helper.exe"

; Lokasi hasil build, relatif terhadap berkas .iss ini.
#define FlutterRelease "..\flutter_app\build\windows\x64\runner\Release"
#define HelperRelease  "..\tools\sony_camera_helper\build\Release"

[Setup]
AppId={{8F3C1A62-4D77-4C1E-9B2A-5E0C7A9D4411}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=SnapTechBooth-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Kiosk selalu 64-bit; ini juga memastikan {autopf} menunjuk Program Files asli.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "id"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "autostart"; Description: "Jalankan otomatis saat Windows menyala (disarankan untuk kiosk)"; GroupDescription: "Kiosk"
Name: "desktopicon"; Description: "Buat pintasan di desktop"; GroupDescription: "Pintasan"; Flags: unchecked

[Files]
; --- Aplikasi Flutter (exe + DLL + folder data) ---
Source: "{#FlutterRelease}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#FlutterRelease}\*.dll";         DestDir: "{app}"; Flags: ignoreversion
Source: "{#FlutterRelease}\data\*";        DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; --- Helper kamera Sony ---
; WAJIB berada tepat di samping .exe aplikasi: itu lokasi pertama yang dicari
; SonyCameraHelperClient.resolveExecutable(). Runtime C++-nya ditaut statis,
; jadi helper tidak butuh VC++ Redistributable.
Source: "{#HelperRelease}\{#HelperExeName}"; DestDir: "{app}"; Flags: ignoreversion

; --- VC++ Redistributable ---
; Dibutuhkan aplikasi Flutter-nya (bukan helper). Letakkan vc_redist.x64.exe di
; folder installer\redist\ sebelum compile. Kalau tidak ada, baris ini dilewati
; dan pemasangannya jadi langkah manual di checklist.
Source: "redist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall skipifsourcedoesntexist

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; \
  StatusMsg: "Memasang Visual C++ Redistributable..."; \
  Check: FileExists(ExpandConstant('{tmp}\vc_redist.x64.exe'))
Filename: "{app}\{#AppExeName}"; Description: "Jalankan {#AppName} sekarang"; \
  Flags: nowait postinstall skipifsilent

[Icons]
Name: "{group}\{#AppName}";        Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}";  Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
; Autostart lewat folder Startup, bukan registry Run: lebih mudah diperiksa dan
; dimatikan oleh teknisi di lapangan tanpa membuka regedit.
Name: "{userstartup}\{#AppName}";  Filename: "{app}\{#AppExeName}"; Tasks: autostart

[UninstallDelete]
; Folder kerja yang dibuat aplikasi saat berjalan.
Type: filesandordirs; Name: "{localappdata}\Temp\snaptechbooth_work"

[Code]
// Helper kamera menahan perangkat Sony selama berjalan. Kalau installer
// menimpa .exe-nya saat masih hidup, pemasangan gagal dengan berkas terkunci —
// dan itu sudah pernah terjadi saat build (LNK1104). Jadi hentikan dulu.
procedure StopRunningProcesses;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{cmd}'), '/C taskkill /IM {#AppExeName} /F',
       '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{cmd}'), '/C taskkill /IM {#HelperExeName} /F',
       '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  StopRunningProcesses;
  Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    StopRunningProcesses;
end;
