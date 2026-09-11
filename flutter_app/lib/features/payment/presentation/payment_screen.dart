import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/services/provisioning_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_geometry.dart';
import '../../../features/provisioning/providers/tenant_provider.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/print_furniture.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';

/// Payment Screen — Integrasi QRIS Dinamis Pakasir dengan Auto-Polling & Realtime Transition
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isSuccess = false;

  String? _qrString;
  int? _paymentId;
  int? _sessionId;
  String? _orderId;
  int _totalAmount = 1000;

  Timer? _timeoutTimer;
  Timer? _pollTimer;
  int _timeoutLeft = 180;

  @override
  void initState() {
    super.initState();
    final tenantConfig = ref.read(tenantNotifierProvider).valueOrNull;
    _totalAmount = tenantConfig?.pricing.sessionPrice ?? 1000;
    _timeoutLeft = tenantConfig?.timers.paymentTimeoutSeconds ?? 180;

    _startTimeout();
    _initiatePayment();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_timeoutLeft > 0) {
          _timeoutLeft--;
        } else {
          t.cancel();
          _pollTimer?.cancel();
          context.go(AppRoutes.welcome);
        }
      });
    });
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatPrice(int price) {
    final formatted = NumberFormat('#,###', 'id_ID').format(price);
    return 'Rp $formatted';
  }

  /// Membuat transaksi QRIS via Backend / Pakasir
  Future<void> _initiatePayment() async {
    setState(() {
      _isLoading = true;
    });

    final tenantConfig = ref.read(tenantNotifierProvider).valueOrNull;
    final deviceKey = await ProvisioningService.instance.getDeviceKey();
    final installationId =
        await ProvisioningService.instance.getInstallationId();
    final payload = <String, dynamic>{
      'device_key': deviceKey,
      'installation_id': installationId,
      if (tenantConfig?.event?.id != null) 'event_id': tenantConfig!.event!.id,
    };

    try {
      final res = await DioClient.instance.dio.post('/payments', data: payload);

      if (res.data['success'] == true && res.data['data'] != null) {
        final data = res.data['data'];
        setState(() {
          _paymentId = data['payment_id'];
          _sessionId = data['session_id'];
          _qrString = data['qr_string'];
          _orderId = data['order_id'] ?? data['external_id'];
          _totalAmount =
              (data['total_payment'] ?? data['amount'] ?? _totalAmount) as int;
          _isLoading = false;
        });

        // Mulai polling status pembayaran
        _startPolling();
      } else {
        throw Exception(res.data['message'] ?? 'Gagal membuat QRIS');
      }
    } catch (e) {
      debugPrint('Error initiating payment: $e');
      setState(() {
        _isLoading = false;
        _qrString = null;
        _paymentId = null;
        _sessionId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('QRIS gagal dibuat. Silakan coba lagi.',
              style: AppFonts.ui(color: AppColors.paperBright)),
          backgroundColor: AppColors.inkOxide,
        ));
      }
    }
  }

  /// Polling status pembayaran ke backend setiap 2.5 detik
  void _startPolling() {
    _pollTimer?.cancel();
    if (_paymentId == null) return;

    _pollTimer =
        Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
      if (!mounted || _isSuccess) {
        timer.cancel();
        return;
      }

      try {
        final deviceKey = await ProvisioningService.instance.getDeviceKey();
        final installationId =
            await ProvisioningService.instance.getInstallationId();
        final res = await DioClient.instance.dio.get(
          '/payments/$_paymentId/status',
          queryParameters: {
            'device_key': deviceKey,
            'installation_id': installationId,
          },
        );
        if (res.data['success'] == true && res.data['data'] != null) {
          final status = res.data['data']['status'];
          if (status == 'paid') {
            timer.cancel();
            _onPaymentSuccess();
          }
        }
      } catch (e) {
        debugPrint('Polling payment status error: $e');
      }
    });
  }

  /// Penanganan saat pembayaran terdeteksi sukses
  Future<void> _onPaymentSuccess() async {
    if (_isSuccess) return;
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();

    setState(() {
      _isSuccess = true;
      _isProcessing = false;
    });

    final tenantConfig = ref.read(tenantNotifierProvider).valueOrNull;
    final durationSeconds = tenantConfig?.timers.sessionTimeoutSeconds ?? 300;
    final eventId = tenantConfig?.event?.id ?? 1;

    // Inisialisasi session di Riverpod
    int realSessionId = _sessionId ?? 1;
    DateTime expiresAt = DateTime.now().add(Duration(seconds: durationSeconds));

    ref.read(sessionNotifierProvider.notifier).startSession(
          sessionId: realSessionId,
          eventId: eventId,
          startedAt: DateTime.now(),
          expiresAt: expiresAt,
        );

    // Berikan feedback animasi sukses sebentar sebelum pindah halaman
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    context.go(AppRoutes.frame);
  }

  /// Trigger dari manual simulator modal
  Future<void> _handleSimulatorResult(String result) async {
    Navigator.pop(context);
    setState(() => _isProcessing = true);

    switch (result) {
      case 'success':
        if (_paymentId != null) {
          try {
            final deviceKey = await ProvisioningService.instance.getDeviceKey();
            final installationId =
                await ProvisioningService.instance.getInstallationId();
            await DioClient.instance.dio.post(
              '/payments/$_paymentId/simulate-paid',
              data: {
                'device_key': deviceKey,
                'installation_id': installationId,
              },
            );
          } catch (e) {
            debugPrint('Simulate paid call failed: $e');
            if (mounted) {
              setState(() => _isProcessing = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Simulasi ditolak atau sedang dinonaktifkan.',
                    style: AppFonts.ui(color: AppColors.paperBright)),
                backgroundColor: AppColors.inkOxide,
              ));
            }
            return;
          }
        } else {
          setState(() => _isProcessing = false);
          return;
        }
        await _onPaymentSuccess();
        break;

      case 'failed':
        setState(() => _isProcessing = false);
        ErrorLogger.instance.logPaymentError(
          reason: 'Transaksi pembayaran QRIS ditolak / gagal diproses',
          amount: _totalAmount,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Pembayaran gagal. Silakan coba lagi.',
              style: AppFonts.ui(color: AppColors.paperBright, fontSize: 13.sp),
            ),
            backgroundColor: AppColors.inkOxide,
            behavior: SnackBarBehavior.floating,
          ));
        }
        break;

      case 'pending':
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Menunggu pembayaran dari pelanggan...',
              style: AppFonts.ui(color: AppColors.paperBright, fontSize: 13.sp),
            ),
            backgroundColor: AppColors.ink,
            behavior: SnackBarBehavior.floating,
          ));
        }
        break;
    }
  }

  void _showSimulator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimulatorSheet(onResult: _handleSimulatorResult),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;
    final isCompact = isMobile || isPortrait;
    final tenant = ref.watch(tenantNotifierProvider).valueOrNull;
    final cafeName =
        (tenant?.cafe.name ?? AppConstants.defaultCafeBrandName).toUpperCase();

    if (_isSuccess) {
      return PhotoboothLayout(
        showHeader: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PaymentBackground(isCompact: isCompact),
            Center(
              child: Container(
                constraints:
                    BoxConstraints(maxWidth: isCompact ? 360.w : 440.w),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.paperBright,
                  border: Border.all(
                      color: AppColors.ink, width: AppGeometry.hairline),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 24.w : 36.w,
                    vertical: isCompact ? 28.h : 36.h,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.ink40, width: AppGeometry.hairline),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cap LUNAS / PAID stempel besar
                      Transform.rotate(
                        angle: -0.12,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.inkGreen, width: 2.5),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '★ LUNAS ★',
                                style: AppFonts.display(
                                  fontSize: isCompact ? 28.sp : 34.sp,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.inkGreen,
                                  letterSpacing: 4.0,
                                ),
                              ),
                              Text(
                                'PAYMENT VERIFIED',
                                style: AppFonts.ui(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkGreen,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.easeOutBack),
                      SizedBox(height: 24.h),
                      Text(
                        'Pembayaran Berhasil!',
                        style: AppFonts.display(
                          fontSize: isCompact ? 22.sp : 26.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ).animate().fadeIn(delay: 150.ms),
                      SizedBox(height: 8.h),
                      Text(
                        'Menyiapkan sesi foto Anda...',
                        style: AppFonts.ui(
                          fontSize: isCompact ? 12.sp : 14.sp,
                          color: AppColors.ink70,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fadeIn(delay: 250.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isProcessing) {
      return PhotoboothLayout(
        showHeader: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PaymentBackground(isCompact: isCompact),
            Center(
              child: Container(
                constraints:
                    BoxConstraints(maxWidth: isCompact ? 320.w : 380.w),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.paperBright,
                  border: Border.all(
                      color: AppColors.ink, width: AppGeometry.hairline),
                ),
                child: Container(
                  padding: EdgeInsets.all(AppGeometry.s24.r),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.ink40, width: AppGeometry.hairline),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: AppColors.ink,
                          strokeWidth: 2.5,
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        'Memverifikasi Pembayaran',
                        textAlign: TextAlign.center,
                        style: AppFonts.display(
                          fontSize: isCompact ? 18.sp : 20.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Mohon tunggu sejenak...',
                        textAlign: TextAlign.center,
                        style: AppFonts.ui(
                          fontSize: 12.sp,
                          color: AppColors.ink70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final formattedPrice = _formatPrice(_totalAmount);

    return PhotoboothLayout(
      showHeader: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PaymentBackground(isCompact: isCompact),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 16.w : 32.w,
                vertical: isCompact ? 12.h : 20.h,
              ),
              child: _QrisMainCard(
                cafeName: cafeName,
                price: formattedPrice,
                qrString: _qrString,
                orderId: _orderId,
                isLoading: _isLoading,
                timeoutText: _formatTime(_timeoutLeft),
                isCompact: isCompact,
                onRefresh: _initiatePayment,
                onSimulator: _showSimulator,
                showSimulator: tenant?.cafe.paymentSimulationEnabled ?? false,
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 1 Card Utama QRIS (Nota Kasir Resmi) ─────────────────────────────────────

class _QrisMainCard extends StatelessWidget {
  const _QrisMainCard({
    required this.cafeName,
    required this.price,
    required this.qrString,
    this.orderId,
    required this.isLoading,
    required this.timeoutText,
    required this.isCompact,
    required this.onRefresh,
    required this.onSimulator,
    required this.showSimulator,
  });

  final String cafeName;
  final String price;
  final String? qrString;
  final String? orderId;
  final bool isLoading;
  final String timeoutText;
  final bool isCompact;
  final VoidCallback onRefresh;
  final VoidCallback onSimulator;
  final bool showSimulator;

  @override
  Widget build(BuildContext context) {
    final qrSize = isCompact ? 220.r : 270.r;

    return Container(
      constraints: BoxConstraints(maxWidth: isCompact ? 380.w : 440.w),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.paperBright,
        border: Border.all(
          color: AppColors.ink,
          width: AppGeometry.hairline,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.ink40,
            width: AppGeometry.hairline,
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 20.w : 28.w,
          vertical: isCompact ? 18.h : 24.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Kepala Nota ──────────────────────────────────────────
            Fleuron(color: AppColors.ink40, width: 100.w),
            SizedBox(height: 10.h),
            Text(
              cafeName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.display(
                fontSize: isCompact ? 22.sp : 26.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 12.h),
            Container(height: AppGeometry.hairline, color: AppColors.ink),
            SizedBox(height: 12.h),

            // ── Logo QRIS dari Asset ──────────────────────────────────
            Image.asset(
              'assets/images/qris.webp',
              height: isCompact ? 32.h : 38.h,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                'QRIS',
                style: AppFonts.display(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            SizedBox(height: 14.h),

            // ── Area Kode QRIS ─────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.ink, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SizedBox(
                width: qrSize,
                height: qrSize,
                child: isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: AppColors.ink,
                              strokeWidth: 2.0,
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              'Membuat kode QRIS...',
                              style: AppFonts.ui(
                                fontSize: 10.sp,
                                color: AppColors.ink70,
                              ),
                            ),
                          ],
                        ),
                      )
                    : (qrString != null && qrString!.isNotEmpty)
                        ? QrImageView(
                            data: qrString!,
                            version: QrVersions.auto,
                            size: qrSize,
                            gapless: true,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                          )
                        : Center(
                            child: IconButton(
                              icon: const Icon(Icons.refresh,
                                  color: AppColors.ink, size: 36),
                              onPressed: onRefresh,
                            ),
                          ),
              ),
            ),
            SizedBox(height: 16.h),
            Container(height: AppGeometry.hairline, color: AppColors.ink),
            SizedBox(height: 12.h),

            // ── Total Bayar ───────────────────────────────────────────
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL BAYAR',
                  textAlign: TextAlign.center,
                  style: AppFonts.ui(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink40,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  price,
                  textAlign: TextAlign.center,
                  style: AppFonts.display(
                    fontSize: isCompact ? 26.sp : 32.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // ── Tombol Simulator Testing (Demo/Kasir) ──────────────────
            if (showSimulator) ...[
              GestureDetector(
                onTap: onSimulator,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 9.h),
                  decoration: BoxDecoration(
                    color: AppColors.paperDeep,
                    border: Border.all(color: AppColors.ink15, width: 1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 13.sp, color: AppColors.ink70),
                      SizedBox(width: 6.w),
                      Text(
                        'SIMULASI PEMBAYARAN (TESTING)',
                        style: AppFonts.ui(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink70,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
            ],

            // ── Powered by SnapTech ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 12.w, height: 1, color: AppColors.ink15),
                SizedBox(width: 6.w),
                Text(
                  'POWERED BY SNAPTECH',
                  style: AppFonts.ui(
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink40,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(width: 6.w),
                Container(width: 12.w, height: 1, color: AppColors.ink15),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Simulator Sheet (Darkroom Paper Style) ───────────────────────────────────

class _SimulatorSheet extends StatelessWidget {
  const _SimulatorSheet({required this.onResult});
  final ValueChanged<String> onResult;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: AppColors.paperBright,
        border: Border.all(color: AppColors.ink, width: AppGeometry.hairline),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 3.h,
            decoration: BoxDecoration(
              color: AppColors.ink40,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Simulator Pembayaran (Testing)',
            style: AppFonts.display(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Pilih status untuk mensimulasikan hasil gateway',
            style: AppFonts.ui(
              fontSize: 11.sp,
              color: AppColors.ink70,
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _SimBtn(
                  label: 'Berhasil (Lunas)',
                  color: AppColors.inkGreen,
                  onTap: () => onResult('success'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _SimBtn(
                  label: 'Gagal',
                  color: AppColors.inkOxide,
                  onTap: () => onResult('failed'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _SimBtn(
                  label: 'Pending',
                  color: AppColors.spot,
                  onTap: () => onResult('pending'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimBtn extends StatelessWidget {
  const _SimBtn(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppFonts.ui(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Background Ambient Studio ────────────────────────────────────────────────

class _PaymentBackground extends StatelessWidget {
  const _PaymentBackground({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 4 sudut garis potong
          const _CornerCropMarks(),
          // Titik registrasi cetak
          const _RegistrationMarks(),
          // Cap stempel studio vintage di kiri atas
          Positioned(
            top: isCompact ? 16.h : 36.h,
            left: isCompact ? 16.w : 48.w,
            child: const _StudioStampWatermark(),
          ),
          // Siluet Strip Foto di kanan atas
          Positioned(
            right: isCompact ? -20.w : 36.w,
            top: isCompact ? 50.h : 80.h,
            child: _DecorativePhotoStrip(isCompact: isCompact),
          ),
          // Siluet Frame Polaroid di kiri bawah
          Positioned(
            left: isCompact ? -20.w : 40.w,
            bottom: isCompact ? 24.h : 44.h,
            child: _DecorativePolaroid(isCompact: isCompact),
          ),
        ],
      ),
    );
  }
}

/// 4 sudut garis potong (Crop Marks) khas percetakan dokumen studio.
class _CornerCropMarks extends StatelessWidget {
  const _CornerCropMarks();

  @override
  Widget build(BuildContext context) {
    const margin = 14.0;
    const len = 18.0;

    return const Stack(
      children: [
        Positioned(
          top: margin,
          left: margin,
          child: _CropCorner(isTop: true, isLeft: true, length: len),
        ),
        Positioned(
          top: margin,
          right: margin,
          child: _CropCorner(isTop: true, isLeft: false, length: len),
        ),
        Positioned(
          bottom: margin,
          left: margin,
          child: _CropCorner(isTop: false, isLeft: true, length: len),
        ),
        Positioned(
          bottom: margin,
          right: margin,
          child: _CropCorner(isTop: false, isLeft: false, length: len),
        ),
      ],
    );
  }
}

class _CropCorner extends StatelessWidget {
  const _CropCorner({
    required this.isTop,
    required this.isLeft,
    required this.length,
  });

  final bool isTop;
  final bool isLeft;
  final double length;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: length,
      height: length,
      child: CustomPaint(
        painter: _CropCornerPainter(isTop: isTop, isLeft: isLeft),
      ),
    );
  }
}

class _CropCornerPainter extends CustomPainter {
  _CropCornerPainter({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink15
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tanda titik registrasi cetak (Registration Crosshair).
class _RegistrationMarks extends StatelessWidget {
  const _RegistrationMarks();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 10),
            child: _RegistrationMark(),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _RegistrationMark(),
          ),
        ),
      ],
    );
  }
}

class _RegistrationMark extends StatelessWidget {
  const _RegistrationMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: _RegistrationMarkPainter(),
      ),
    );
  }
}

class _RegistrationMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink15
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width / 2 - 2, paint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawLine(
        Offset(center.dx, 0), Offset(center.dx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cap stempel vintage studio bulat di latar belakang.
class _StudioStampWatermark extends StatelessWidget {
  const _StudioStampWatermark();

  @override
  Widget build(BuildContext context) {
    final size = 95.r;
    return Transform.rotate(
      angle: -0.10,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.ink15,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.ink15,
              width: 1.0,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '★ PHOTO ★',
                  style: AppFonts.ui(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink40,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'STUDIO',
                  style: AppFonts.display(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink40,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'PAYMENT PASS',
                  style: AppFonts.ui(
                    fontSize: 7.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink40,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Siluet strip foto klasik bertumpuk miring di background meja.
class _DecorativePhotoStrip extends StatelessWidget {
  const _DecorativePhotoStrip({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final width = isCompact ? 64.w : 88.w;
    final height = isCompact ? 190.h : 250.h;

    return Transform.rotate(
      angle: 0.12,
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.paperDeep,
          border: Border.all(color: AppColors.ink15, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 3 frame foto miniatur
            for (int i = 0; i < 3; i++) ...[
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    border: Border.all(color: AppColors.ink15, width: 0.8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: isCompact ? 14.r : 18.r,
                      color: AppColors.ink15,
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: 2.h),
            Text(
              'MEMORIES',
              style: AppFonts.ui(
                fontSize: 7.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.ink40,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Siluet polaroid miring di latar belakang.
class _DecorativePolaroid extends StatelessWidget {
  const _DecorativePolaroid({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final width = isCompact ? 70.w : 96.w;
    final height = isCompact ? 86.h : 118.h;

    return Transform.rotate(
      angle: -0.14,
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 14.h),
        decoration: BoxDecoration(
          color: AppColors.paperDeep,
          border: Border.all(color: AppColors.ink15, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(-2, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  border: Border.all(color: AppColors.ink15, width: 0.8),
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome,
                    size: isCompact ? 14.r : 18.r,
                    color: AppColors.ink15,
                  ),
                ),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'PHOTOBOOTH',
              style: AppFonts.ui(
                fontSize: 6.5.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.ink40,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
