import 'dart:io' as dart_io;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/camera_service.dart';
import '../../../../core/services/sony_ptp_camera_service.dart';
import '../../../../core/services/uvc_camera_service.dart';
import '../../../../shared/widgets/uvc_preview.dart';
import '../../../../core/theme/app_colors.dart';

class CameraSettingsTab extends StatefulWidget {
  const CameraSettingsTab({super.key});

  @override
  State<CameraSettingsTab> createState() => _CameraSettingsTabState();
}

class _CameraSettingsTabState extends State<CameraSettingsTab> {
  List<CameraDescription> _cameras = [];
  bool _isLoadingCameras = true;
  CameraController? _previewController;
  bool _isTestingCapture = false;
  dart_io.File? _testResult;
  bool _autoSelectExternal = true;
  String? _errorMessage;

  // ── SONY ZV-E10 USB PTP / HDMI UVC STATE ──────────────────────────────────
  SonyCameraStatus? _sonyStatus;
  bool _isSonyCapturing = false;
  String? _sonyCaptureMessage;
  dart_io.File? _sonyCapturedFile;
  bool _isUvcActive = false;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  @override
  void dispose() {
    _previewController?.dispose();
    // Kamera UVC tidak ditutup di sini — UvcPreview yang mengelola siklus
    // view-nya, sehingga halaman berikutnya bisa membuka ulang dengan bersih.
    super.dispose();
  }

  Future<void> _loadCameras() async {
    setState(() {
      _isLoadingCameras = true;
      _errorMessage = null;
    });

    try {
      await CameraService.loadSavedPreference();
      _autoSelectExternal = CameraService.autoSelectExternal;
      _cameras = await CameraService.getAvailableCamerasList();
      await _loadSonyStatus();

      // Hanya aktifkan jalur UVC bila capture card benar-benar terdeteksi.
      // Sebelumnya `isDetected` juga true untuk kamera PTP, sehingga UI mencoba
      // membuka UVC padahal yang tersambung hanya kabel C-to-C.
      // Cukup aktifkan flag — UvcPreview yang mendaftarkan generasi view baru
      // dan memanggil open(). Memanggil open() di sini akan mengenai view milik
      // halaman sebelumnya (factory native hanya menyimpan satu referensi view)
      // sehingga preview di halaman ini tampil hitam.
      if (_sonyStatus?.uvcDetected == true) {
        _isUvcActive = true;
      }

      await _initPreviewController();
    } catch (e) {
      _errorMessage = 'Gagal memuat kamera: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoadingCameras = false);
      }
    }
  }

  Future<void> _loadSonyStatus() async {
    try {
      final status = await SonyPtpCameraService.getStatus();
      if (mounted) {
        setState(() {
          _sonyStatus = status;
          if (status.uvcDetected) {
            _isUvcActive = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Error load Sony status: $e');
    }
  }

  Future<void> _handleRequestUvcPermission() async {
    final granted = await SonyPtpCameraService.requestUvcPermission();
    await _loadSonyStatus();
    if (granted && mounted) setState(() => _isUvcActive = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted
              ? 'Izin USB HDMI capture card diberikan!'
              : 'Izin USB capture card belum diberikan.'),
          backgroundColor: granted ? Colors.green : Colors.red,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _handleRequestSonyPermission() async {
    final granted = await SonyPtpCameraService.requestPermission();
    await _loadSonyStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted ? 'Izin USB Sony ZV-E10 diberikan!' : 'Izin USB belum diberikan.'),
          backgroundColor: granted ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSonyCaptureTest() async {
    setState(() {
      _isSonyCapturing = true;
      _sonyCaptureMessage = null;
    });

    // Prioritas: shutter PTP (resolusi penuh). Baru fallback ke frame HDMI.
    if (_sonyStatus?.ptpDetected == true) {
      if (_sonyStatus?.ptpHasPermission != true) {
        await SonyPtpCameraService.requestPermission();
      }
      await SonyPtpCameraService.connect();
      final ptpResult = await SonyPtpCameraService.capturePhoto();
      if (ptpResult.isSuccess && ptpResult.filePath != null) {
        final f = dart_io.File(ptpResult.filePath!);
        if (mounted) {
          setState(() {
            _isSonyCapturing = false;
            _testResult = f;
            _sonyCapturedFile = f;
            _sonyCaptureMessage =
                '✅ Foto resolusi penuh via shutter PTP (${(ptpResult.fileSizeBytes / 1048576).toStringAsFixed(1)} MB)';
          });
        }
        return;
      }
      debugPrint('⚠️ PTP capture gagal (${ptpResult.message}) — fallback ke frame HDMI.');
    }

    if (_isUvcActive) {
      final file = await UvcCameraService.instance.takePhoto();
      if (mounted) {
        setState(() {
          _isSonyCapturing = false;
          _testResult = file;
          _sonyCapturedFile = file;
          _sonyCaptureMessage = file != null
              ? '✅ Foto diambil dari frame HDMI (1080p ~2MP).'
              : '⚠️ Gagal mengambil foto dari stream UVC. ${UvcCameraService.instance.lastError ?? ""}';
        });
      }
      return;
    }

    final result = await SonyPtpCameraService.capturePhoto();

    if (mounted) {
      setState(() {
        _isSonyCapturing = false;
        _sonyCaptureMessage = result.message;
        if (result.isSuccess && result.filePath != null) {
          _sonyCapturedFile = dart_io.File(result.filePath!);
        }
      });
      await _loadSonyStatus();
    }
  }

  Future<void> _initPreviewController() async {
    _previewController?.dispose();
    _previewController = null;

    if (_cameras.isEmpty) return;

    try {
      _previewController = await CameraService.createController(
        resolution: ResolutionPreset.high,
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error init preview: $e');
    }
  }

  Future<void> _refreshCameras() async {
    await _loadCameras();
  }

  Future<void> _selectCamera(CameraDescription cam) async {
    _isUvcActive = false;
    CameraService.setSelectedCamera(cam);
    await CameraService.saveSelectedCamera(cam.name);
    await _initPreviewController();
    if (mounted) setState(() {});
  }

  /// Callback dari [UvcPreview] setelah percobaan membuka kamera HDMI selesai.
  void _onUvcOpenResult(bool opened) {
    if (!mounted) return;
    if (!opened) {
      final err = UvcCameraService.instance.lastError ?? 'Preview HDMI gagal dibuka.';
      setState(() => _isUvcActive = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      setState(() {});
    }
  }

  Future<void> _selectUvcCamera() async {
    // Cukup render UvcPreview; widget itu yang membuka kamera untuk view-nya
    // sendiri dan melapor lewat _onUvcOpenResult.
    setState(() => _isUvcActive = true);
    await _loadSonyStatus();
    if (mounted) setState(() {});
  }

  Future<void> _takeTestPhoto() async {
    setState(() => _isTestingCapture = true);
    try {
      if (_isUvcActive) {
        final file = await UvcCameraService.instance.takePhoto();
        if (mounted) {
          setState(() {
            _testResult = file;
          });
        }
      } else if (_previewController != null && _previewController!.value.isInitialized) {
        final xFile = await _previewController!.takePicture();
        if (mounted) {
          setState(() {
            _testResult = dart_io.File(xFile.path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingCapture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCameras) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        // ── SECTION 1: CAMERA CONNECTION ──────────────────────────────────
        _buildSectionHeader('CAMERA CONNECTION'),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_cameras.length + (_sonyStatus?.isDetected == true ? 1 : 0)} Sumber Kamera Terdeteksi',
              style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12.sp),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.darkBrown,
              ),
              onPressed: _refreshCameras,
              icon: Icon(Icons.refresh_rounded, size: 16.r),
              label: Text(
                'Refresh',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11.sp),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        // 1. Kartu Khusus HDMI Capture Card (UVC)
        if (_sonyStatus?.isDetected == true || _sonyStatus?.isUvc == true)
          // Kartu UVC memakai flutter_uvc_camera yang Android-only. Di Windows
          // capture card muncul sebagai kamera biasa di daftar di bawah.
          if (Platform.isAndroid) _buildUvcCameraCard(),

        if (_cameras.isEmpty && _sonyStatus?.isDetected != true)
          Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Text(
              _errorMessage ?? 'Tidak ada kamera terdeteksi. Pastikan kamera terhubung dan coba Refresh.',
              style: GoogleFonts.montserrat(color: Colors.amberAccent, fontSize: 12.sp),
            ),
          )
        else
          ..._cameras.map((cam) => _buildCameraCard(cam)),
        
        SizedBox(height: 16.h),

        // ── SECTION 2: LIVE PREVIEW TEST ──────────────────────────────────
        _buildSectionHeader('LIVE PREVIEW TEST'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: _isUvcActive ? Colors.greenAccent.withValues(alpha: 0.6) : AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              if (_isUvcActive)
                Container(
                  height: 240.h,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.greenAccent, width: 2),
                  ),
                  child: UvcPreview(onOpenResult: _onUvcOpenResult),
                )
              else if (_previewController != null && _previewController!.value.isInitialized)
                Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: AspectRatio(
                    aspectRatio: _previewController!.value.aspectRatio,
                    child: CameraPreview(_previewController!),
                  ),
                )
              else if (_previewController != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Text(
                    'Preview tidak tersedia.',
                    style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12.sp),
                  ),
                ),
              
              SizedBox(height: 12.h),
              Text(
                _isUvcActive
                    ? 'POV Kamera Sony ZV-E10 (USB Video HDMI Stream)\nResolusi: HD Video'
                    : (_previewController != null && _previewController!.value.isInitialized
                        ? 'Camera ID: ${_previewController!.description.name}\nResolusi: High'
                        : 'Kamera Standar'),
                style: GoogleFonts.montserrat(color: _isUvcActive ? Colors.greenAccent : AppColors.creamWhite, fontSize: 11.sp, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.darkBrown,
                    ),
                    onPressed: _isTestingCapture ? null : _takeTestPhoto,
                    icon: _isTestingCapture
                        ? SizedBox(width: 16.r, height: 16.r, child: const CircularProgressIndicator(color: AppColors.darkBrown, strokeWidth: 2))
                        : Icon(Icons.camera_rounded, size: 18.r),
                    label: Text(
                      'Test Capture',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11.sp),
                    ),
                  ),
                  if (_testResult != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => setState(() => _testResult = null),
                      icon: Icon(Icons.delete_rounded, size: 18.r),
                      label: Text(
                        'Hapus Hasil Test',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11.sp),
                      ),
                    ),
                ],
              ),
              
              if (_testResult != null) ...[
                SizedBox(height: 16.h),
                Text(
                  'Hasil Test:',
                  style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontSize: 12.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Image.file(_testResult!, height: 180.h, fit: BoxFit.contain),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // ── SECTION 3: CAMERA SETTINGS ──────────────────────────────────
        _buildSectionHeader('CAMERA SETTINGS'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              _buildSwitchRow(
                label: 'Auto-Prioritas Kamera Eksternal',
                value: _autoSelectExternal,
                onChanged: (val) {
                  setState(() => _autoSelectExternal = val);
                  CameraService.saveAutoSelectExternal(val);
                },
              ),
              const Divider(color: Colors.white12),
              _buildSettingRow(
                label: 'Reset ke Auto-Detect',
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.darkBrown,
                    minimumSize: Size.zero,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  ),
                  onPressed: () async {
                    await CameraService.clearSelectedCamera();
                    await _refreshCameras();
                  },
                  child: Text(
                    'Reset',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11.sp),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── SECTION 4: SONY ZV-E10 USB PC REMOTE (PTP TEST) ───────────────
        //
        // KHUSUS ANDROID. Seluruh kartu ini berbicara ke SonyPtpCameraManager
        // lewat MethodChannel, yang hanya ada di sisi Kotlin. Di Windows setiap
        // tombolnya mati — dan tombol mati di panel operator lebih buruk
        // daripada tidak ada tombol sama sekali.
        //
        // Jalur PTP di Windows adalah Cycle C4, dan per 2026-09-02 ditunda
        // karena ZV-E10 generasi pertama tidak didukung Sony Camera Remote SDK.
        if (Platform.isAndroid) ...[
          SizedBox(height: 16.h),
          _buildSectionHeader('SONY ZV-E10 USB PC REMOTE (PTP DIRECT)'),
          SizedBox(height: 8.h),
          _buildSonyPtpTestCard(),
        ],
      ],
    );
  }

  Widget _buildSonyPtpTestCard() {
    final status = _sonyStatus;
    final isDetected = status?.isDetected == true;
    final hasPerm = status?.hasPermission == true;
    final isUvc = status?.isUvc == true;

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Status USB Host
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isUvc ? Icons.videocam_rounded : Icons.usb_rounded,
                    color: isDetected ? Colors.greenAccent : Colors.white38,
                    size: 20.r,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    status?.productName ?? (isUvc ? 'USB Video (HDMI Capture Card)' : 'Sony ZV-E10'),
                    style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: (isDetected ? Colors.green : Colors.red).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(color: isDetected ? Colors.green : Colors.red),
                ),
                child: Text(
                  isDetected
                      ? (isUvc ? '● HDMI Capture Terhubung' : '● Terdeteksi USB')
                      : '● Disconnected',
                  style: TextStyle(
                    color: isDetected ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12),

          // Row 2: Info VID / PID & Node
          if (isDetected) ...[
            _buildSettingRow(
              label: 'VID / PID',
              child: Text(
                '0x${(status?.vendorId ?? 0).toRadixString(16).toUpperCase().padLeft(4, '0')} : '
                '0x${(status?.productId ?? 0).toRadixString(16).toUpperCase().padLeft(4, '0')} '
                '${isUvc ? '(MacroSilicon HDMI Capture)' : ((status?.vendorId == 0x054C) ? '(Sony Corp)' : '(Detected)')}',
                style: GoogleFonts.montserrat(color: AppColors.gold, fontSize: 11.sp),
              ),
            ),
            _buildSettingRow(
              label: 'Node Path (USB)',
              child: Text(
                status?.devicePath ?? '-',
                style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 11.sp, fontWeight: FontWeight.bold),
              ),
            ),
            if (isUvc) ...[
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 18.r),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Kamera terhubung via Kabel HDMI Capture Card (${status?.devicePath}). Stream video HDMI otomatis aktif di bagian Live Preview Test di atas.',
                        style: GoogleFonts.montserrat(color: Colors.greenAccent, fontSize: 10.5.sp, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(color: Colors.white12),
          ] else ...[
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 18.r),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Jika kamera sudah dicolok:\n1. Buka Pengaturan Tablet → USB Preferences: ubah "USB controlled by" ke "This device" (Mode Host).\n2. Atau hubungkan kamera lewat USB Type-C Hub / OTG Adapter.',
                      style: GoogleFonts.montserrat(color: Colors.amberAccent, fontSize: 10.5.sp, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
          ],

          // Row 3: Permission Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('USB Permission', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: (hasPerm ? Colors.green : Colors.amber).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: hasPerm ? Colors.green : Colors.amber),
                    ),
                    child: Text(
                      hasPerm ? '✓ Ready / Granted' : '⚠️ Permission Needed',
                      style: TextStyle(
                        color: hasPerm ? Colors.greenAccent : Colors.amberAccent,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isDetected && !hasPerm) ...[
                    SizedBox(width: 8.w),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.darkBrown,
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        minimumSize: Size.zero,
                      ),
                      // UVC (capture card) dan PTP (Sony) punya izin USB terpisah.
                      onPressed: isUvc
                          ? _handleRequestUvcPermission
                          : _handleRequestSonyPermission,
                      child: Text('Minta Izin', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Row 4: Shutter Trigger Test Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.darkBrown,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              onPressed: (!isDetected || _isSonyCapturing) ? null : () {
                if (isUvc) {
                  _takeTestPhoto();
                } else {
                  _handleSonyCaptureTest();
                }
              },
              icon: _isSonyCapturing
                  ? SizedBox(width: 16.r, height: 16.r, child: const CircularProgressIndicator(color: AppColors.darkBrown, strokeWidth: 2))
                  : Icon(isUvc ? Icons.camera_alt_rounded : Icons.camera_enhance_rounded),
              label: Text(
                _isSonyCapturing
                    ? 'Memicu Shutter Sony & Mentransfer Foto...'
                    : (isUvc ? 'Test Capture Stream HDMI (USB Video)' : 'Test Shutter Capture (PTP Direct)'),
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12.sp),
              ),
            ),
          ),

          if (_sonyCaptureMessage != null) ...[
            SizedBox(height: 8.h),
            Text(
              _sonyCaptureMessage!,
              style: TextStyle(
                color: _sonyCapturedFile != null ? Colors.greenAccent : Colors.amberAccent,
                fontSize: 11.sp,
              ),
            ),
          ],

          if (_sonyCapturedFile != null) ...[
            SizedBox(height: 12.h),
            Text(
              'Hasil Foto Sony ZV-E10 (Full Resolution):',
              style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontSize: 11.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.file(_sonyCapturedFile!, height: 160.h, fit: BoxFit.contain),
            ),
            SizedBox(height: 6.h),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _sonyCapturedFile = null),
                icon: Icon(Icons.delete_outline_rounded, size: 16.r, color: Colors.redAccent),
                label: Text('Hapus Preview Test', style: TextStyle(color: Colors.redAccent, fontSize: 10.sp)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUvcCameraCard() {
    final isSelected = _isUvcActive;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isSelected ? Colors.greenAccent : AppColors.gold.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.videocam_rounded, color: isSelected ? Colors.greenAccent : AppColors.gold, size: 26.r),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kamera Eksternal HDMI / Sony ZV-E10',
                      style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontWeight: FontWeight.bold, fontSize: 13.sp),
                    ),
                    Text(
                      'USB Video (${_sonyStatus?.devicePath ?? "/dev/bus/usb/002/012"})',
                      style: GoogleFonts.montserrat(color: Colors.greenAccent, fontSize: 11.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: (isSelected ? Colors.green : Colors.amber).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: isSelected ? Colors.greenAccent : Colors.amber),
                    ),
                    child: Text(
                      isSelected ? '● Kamera Aktif (POV Sony)' : '📷 HDMI Terhubung',
                      style: GoogleFonts.montserrat(
                        color: isSelected ? Colors.greenAccent : Colors.amberAccent,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.grey : AppColors.gold,
                  foregroundColor: isSelected ? Colors.black54 : AppColors.darkBrown,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  minimumSize: Size.zero,
                ),
                onPressed: isSelected ? null : _selectUvcCamera,
                child: Text(
                  isSelected ? 'Sedang Dipakai' : 'Gunakan Kamera Ini',
                  style: GoogleFonts.montserrat(fontSize: 11.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCameraCard(CameraDescription cam) {
    final isSelected = CameraService.selectedCamera?.name == cam.name;
    final isExternal = CameraService.isExternalCamera(cam);
    final typeLabel = CameraService.getCameraTypeLabel(cam);

    IconData camIcon = Icons.camera_alt_rounded;
    if (isExternal || cam.lensDirection == CameraLensDirection.external) {
      camIcon = Icons.videocam_rounded;
    } else if (cam.lensDirection == CameraLensDirection.front) {
      camIcon = Icons.camera_front_rounded;
    } else if (cam.lensDirection == CameraLensDirection.back) {
      camIcon = Icons.camera_rear_rounded;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isSelected ? Colors.green.withValues(alpha: 0.5) : AppColors.gold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(camIcon, color: isSelected ? Colors.greenAccent : AppColors.gold, size: 24.r),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Camera ${cam.name} — ${isExternal ? "Kamera Eksternal HDMI / UVC" : (cam.lensDirection == CameraLensDirection.front ? "Kamera Depan" : "Kamera Belakang")}',
                      style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontWeight: FontWeight.bold, fontSize: 13.sp),
                    ),
                    Text(
                      typeLabel,
                      style: GoogleFonts.montserrat(color: isExternal ? Colors.greenAccent : Colors.white70, fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isSelected)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        '● Kamera Aktif',
                        style: GoogleFonts.montserrat(color: Colors.greenAccent, fontSize: 10.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (isSelected && isExternal) SizedBox(width: 8.w),
                  if (isExternal)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Text(
                        '📷 Eksternal',
                        style: GoogleFonts.montserrat(color: Colors.amberAccent, fontSize: 10.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.grey : AppColors.gold,
                  foregroundColor: isSelected ? Colors.black54 : AppColors.darkBrown,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  minimumSize: Size.zero,
                ),
                onPressed: isSelected ? null : () => _selectCamera(cam),
                child: Text(
                  'Pilih Kamera Ini',
                  style: GoogleFonts.montserrat(fontSize: 11.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        color: AppColors.gold,
        fontSize: 11.sp,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingRow({required String label, required Widget child}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchRow({required String label, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
          Switch(
            value: value,
            activeTrackColor: AppColors.gold.withValues(alpha: 0.5),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return AppColors.gold;
              return null;
            }),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
