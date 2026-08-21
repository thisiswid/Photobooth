import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/provisioning_service.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/tenant_provider.dart';

/// Layar Setup Wizard & Aktivasi Perangkat Kiosk SnapTechBooth.
/// Ditampilkan saat perangkat baru pertama kali dinyalakan atau setelah di-reset.
class ProvisioningScreen extends ConsumerStatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  ConsumerState<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends ConsumerState<ProvisioningScreen> {
  final _keyController = TextEditingController();
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _showAdvancedSettings = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialValues();
  }

  Future<void> _loadInitialValues() async {
    final customUrl = await ProvisioningService.instance.getCustomBaseUrl();
    _urlController.text = customUrl ?? AppConstants.apiBaseUrlProd;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleActivation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deviceKey = _keyController.text.trim().toUpperCase();
      final customUrl = _urlController.text.trim();

      final config = await ref.read(tenantNotifierProvider.notifier).activateDevice(
            deviceKey: deviceKey,
            customBaseUrl: customUrl.isNotEmpty ? customUrl : null,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Aktivasi Berhasil! Terhubung ke: ${config.cafe.name}',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Pindah ke Welcome Screen
      context.go(AppRoutes.welcome);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B08),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 24.h),
            child: Container(
              constraints: BoxConstraints(maxWidth: 680.w),
              padding: EdgeInsets.all(36.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1611),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: const Color(0xFFD97706).withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Brand Logo SnapTech ──────────────────────────────────
                    Container(
                      width: 90.w,
                      height: 90.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97706).withOpacity(0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(45.r),
                        child: Image.asset(
                          AppConstants.logoSnaptechAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFD97706),
                            child: Icon(
                              Icons.camera_alt,
                              size: 40.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 18.h),

                    // ── Title & Subtitle ─────────────────────────────────────
                    Text(
                      'SNAPTECH BOOTH',
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: const Color(0xFFFDE68A),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Universal Multi-Tenant Kiosk Setup',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFFD97706),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Masukkan Device Pairing Key yang terdaftar pada dashboard admin untuk mengaktifkan mesin kiosk ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFFA8A29E),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 28.h),

                    // ── Error Banner ─────────────────────────────────────────
                    if (_errorMessage != null) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFF87171)),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],

                    // ── Device Key Input ─────────────────────────────────────
                    TextFormField(
                      controller: _keyController,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: const Color(0xFFFFFBEB),
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'DEVICE PAIRING KEY',
                        labelStyle: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFFD97706),
                          fontWeight: FontWeight.w600,
                        ),
                        hintText: 'CONTOH: SNAP-FK-8821',
                        hintStyle: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.white24,
                          letterSpacing: 1.5,
                        ),
                        prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFFD97706)),
                        filled: true,
                        fillColor: const Color(0xFF140E0A),
                        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: const BorderSide(color: Color(0xFF451A03)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: const BorderSide(color: Color(0xFF78350F)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Device Pairing Key wajib diisi.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24.h),

                    // ── Tombol Aktivasi ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleActivation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 22.w,
                                    height: 22.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Text(
                                    'Menghubungkan ke Server...',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 24),
                                  SizedBox(width: 10.w),
                                  Text(
                                    'AKTIFKAN & PASANG MESIN',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // ── Opsi Pengaturan Server Lanjutan (Advanced Settings) ───
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAdvancedSettings = !_showAdvancedSettings;
                        });
                      },
                      icon: Icon(
                        _showAdvancedSettings
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.settings_outlined,
                        size: 18.sp,
                        color: const Color(0xFF9CA3AF),
                      ),
                      label: Text(
                        _showAdvancedSettings
                            ? 'Sembunyikan Pengaturan Server'
                            : 'Pengaturan Server API (Kustom)',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),

                    if (_showAdvancedSettings) ...[
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: _urlController,
                        style: TextStyle(fontSize: 14.sp, color: Colors.white70),
                        decoration: InputDecoration(
                          labelText: 'API Base URL',
                          labelStyle: TextStyle(fontSize: 12.sp, color: Colors.white60),
                          hintText: 'https://snaptechbooth.my.id/api',
                          hintStyle: TextStyle(fontSize: 12.sp, color: Colors.white24),
                          prefixIcon: const Icon(Icons.cloud_outlined, color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF140E0A),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
