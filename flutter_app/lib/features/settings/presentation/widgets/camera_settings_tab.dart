import 'dart:io' as dart_io;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/camera_service.dart';
import '../../../../core/services/sony_ptp_camera_service.dart';
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

  // ── SONY ZV-E10 USB PTP STATE ─────────────────────────────────────────────
  SonyCameraStatus? _sonyStatus;
  bool _isSonyCapturing = false;
  String? _sonyCaptureMessage;
  dart_io.File? _sonyCapturedFile;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  @override
  void dispose() {
    _previewController?.dispose();
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
        setState(() => _sonyStatus = status);
      }
    } catch (e) {
      debugPrint('Error load Sony status: $e');
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
    CameraService.setSelectedCamera(cam);
    await CameraService.saveSelectedCamera(cam.name);
    await _initPreviewController();
    if (mounted) setState(() {});
  }

  Future<void> _takeTestPhoto() async {
    if (_previewController == null || !_previewController!.value.isInitialized) return;

    setState(() => _isTestingCapture = true);
    try {
      final xFile = await _previewController!.takePicture();
      if (mounted) {
        setState(() {
          _testResult = dart_io.File(xFile.path);
        });
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
              '${_cameras.length} Kamera Terdeteksi',
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
        if (_cameras.isEmpty)
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
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              if (_previewController != null && _previewController!.value.isInitialized)
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
              if (_previewController != null && _previewController!.value.isInitialized)
                Text(
                  '${_previewController!.description.name}\nResolusi: High',
                  style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontSize: 11.sp),
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

        SizedBox(height: 16.h),

        // ── SECTION 4: SONY ZV-E10 USB PC REMOTE (PTP TEST) ───────────────
        _buildSectionHeader('SONY ZV-E10 USB PC REMOTE (PTP DIRECT)'),
        SizedBox(height: 8.h),
        _buildSonyPtpTestCard(),
      ],
    );
  }

  Widget _buildSonyPtpTestCard() {
    final status = _sonyStatus;
    final isDetected = status?.isDetected == true;
    final hasPerm = status?.hasPermission == true;

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
                  Icon(Icons.usb_rounded, color: isDetected ? Colors.greenAccent : Colors.white38, size: 20.r),
                  SizedBox(width: 8.w),
                  Text(
                    status?.productName ?? 'Sony ZV-E10 (USB PTP)',
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
                  isDetected ? '● Terdeteksi USB' : '● Disconnected',
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
                '0x054C : 0x0D97 (Sony Corp)',
                style: GoogleFonts.montserrat(color: AppColors.gold, fontSize: 11.sp),
              ),
            ),
            _buildSettingRow(
              label: 'Node Path',
              child: Text(
                status?.devicePath ?? '/dev/bus/usb/002/004',
                style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 11.sp),
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
                      hasPerm ? '✓ Granted' : '⚠️ Permission Needed',
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
                      onPressed: _handleRequestSonyPermission,
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
              onPressed: (!isDetected || _isSonyCapturing) ? null : _handleSonyCaptureTest,
              icon: _isSonyCapturing
                  ? SizedBox(width: 16.r, height: 16.r, child: const CircularProgressIndicator(color: AppColors.darkBrown, strokeWidth: 2))
                  : const Icon(Icons.camera_enhance_rounded),
              label: Text(
                _isSonyCapturing ? 'Memicu Shutter Sony & Mentransfer Foto...' : 'Test Shutter Capture (PTP Direct)',
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

  Widget _buildCameraCard(CameraDescription cam) {
    final isSelected = CameraService.selectedCamera?.name == cam.name;
    final isExternal = CameraService.isExternalCamera(cam);
    final typeLabel = CameraService.getCameraTypeLabel(cam);

    IconData camIcon = Icons.camera_alt_rounded;
    if (cam.lensDirection == CameraLensDirection.external) {
      camIcon = Icons.usb_rounded;
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
              Icon(camIcon, color: AppColors.gold, size: 24.r),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cam.name,
                      style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontWeight: FontWeight.bold, fontSize: 13.sp),
                    ),
                    Text(
                      typeLabel,
                      style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 11.sp),
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
