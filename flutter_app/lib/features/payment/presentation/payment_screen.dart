import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/provisioning/providers/tenant_provider.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
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
  int _totalAmount = 25000;

  Timer? _timeoutTimer;
  Timer? _pollTimer;
  int _timeoutLeft = 180;

  @override
  void initState() {
    super.initState();
    final tenantConfig = ref.read(tenantNotifierProvider).valueOrNull;
    _totalAmount = tenantConfig?.pricing.sessionPrice ?? 25000;
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

    try {
      final res = await DioClient.instance.dio.post('/payments', data: {
        'amount': _totalAmount,
        'event_id': 1,
      });

      if (res.data['success'] == true && res.data['data'] != null) {
        final data = res.data['data'];
        setState(() {
          _paymentId = data['payment_id'];
          _sessionId = data['session_id'];
          _qrString = data['qr_string'];
          _orderId = data['order_id'] ?? data['external_id'];
          _totalAmount = (data['total_payment'] ?? data['amount'] ?? _totalAmount) as int;
          _isLoading = false;
        });

        // Mulai polling status pembayaran
        _startPolling();
      } else {
        throw Exception(res.data['message'] ?? 'Gagal membuat QRIS');
      }
    } catch (e) {
      debugPrint('Error initiating payment: $e');
      // Fallback mock jika offline/error
      setState(() {
        _isLoading = false;
        _orderId = 'MOCK-${DateTime.now().millisecondsSinceEpoch}';
        _qrString = "00020101021226610016ID.CO.SHOPEE.WWW01189360091800216005230208216005230303UME51440014ID.CO.QRIS.WWW0215ID10243228429300303UME5204792953033605409$_totalAmount.005802ID5913SnapTechBooth6007Jakarta61051234562230519MOCK${_totalAmount}6304A079";
        _paymentId = 1;
        _sessionId = 1;
      });
      _startPolling();
    }
  }

  /// Polling status pembayaran ke backend setiap 2.5 detik
  void _startPolling() {
    _pollTimer?.cancel();
    if (_paymentId == null) return;

    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
      if (!mounted || _isSuccess) {
        timer.cancel();
        return;
      }

      try {
        final res = await DioClient.instance.dio.get('/payments/$_paymentId/status');
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

    // Inisialisasi session di Riverpod
    int realSessionId = _sessionId ?? 1;
    DateTime expiresAt = DateTime.now().add(AppConstants.sessionDuration);

    ref.read(sessionNotifierProvider.notifier).startSession(
          sessionId: realSessionId,
          eventId: 1,
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
            await DioClient.instance.dio.post('/payments/$_paymentId/simulate-paid');
          } catch (e) {
            debugPrint('Simulate paid call failed: $e');
          }
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
            content: Text('Pembayaran gagal. Silakan coba lagi.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.creamWhite)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
        break;

      case 'pending':
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Menunggu pembayaran dari pelanggan...',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.creamWhite)),
            backgroundColor: AppColors.darkBrown,
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

    if (_isSuccess) {
      return PhotoboothLayout(
        header: const CustomerHeader(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: isMobile ? 80.sp : 100.sp,
                  color: AppColors.success,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              SizedBox(height: 24.h),
              Text(
                'Pembayaran Berhasil!',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: isMobile ? 26.sp : 34.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkBrown,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              SizedBox(height: 8.h),
              Text(
                'Menyiapkan sesi foto Anda...',
                style: GoogleFonts.montserrat(
                  fontSize: isMobile ? 13.sp : 15.sp,
                  color: AppColors.brown,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(delay: 350.ms),
            ],
          ),
        ),
      );
    }

    if (_isProcessing) {
      return PhotoboothLayout(
        header: const CustomerHeader(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.darkBrown, strokeWidth: 3),
              SizedBox(height: 16.h),
              Text(
                'Memverifikasi Pembayaran...',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: isMobile ? 18.sp : 22.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBrown,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final formattedPrice = _formatPrice(_totalAmount);

    return PhotoboothLayout(
      header: const CustomerHeader(),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20.w : 60.w,
            vertical: isMobile ? 12.h : 20.h,
          ),
          child: _QrisMainCard(
            price: formattedPrice,
            qrString: _qrString,
            orderId: _orderId,
            isLoading: _isLoading,
            timeoutText: _formatTime(_timeoutLeft),
            isMobile: isMobile,
            onRefresh: _initiatePayment,
            onSimulator: _showSimulator,
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04),
        ),
      ),
    );
  }
}

// ── 1 Card Utama QRIS ────────────────────────────────────────────────────────

class _QrisMainCard extends StatelessWidget {
  const _QrisMainCard({
    required this.price,
    required this.qrString,
    this.orderId,
    required this.isLoading,
    required this.timeoutText,
    required this.isMobile,
    required this.onRefresh,
    required this.onSimulator,
  });

  final String price;
  final String? qrString;
  final String? orderId;
  final bool isLoading;
  final String timeoutText;
  final bool isMobile;
  final VoidCallback onRefresh;
  final VoidCallback onSimulator;

  @override
  Widget build(BuildContext context) {
    final qrSize = isMobile ? 160.r : 210.r;

    return Container(
      constraints: BoxConstraints(maxWidth: isMobile ? 380.w : 460.w),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.w : 40.w,
        vertical: isMobile ? 22.h : 32.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderWarm, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Judul & Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Scan QRIS',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: isMobile ? 22.sp : 26.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkBrown,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.darkBrown.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 14.sp, color: AppColors.darkBrown),
                    SizedBox(width: 4.w),
                    Text(
                      timeoutText,
                      style: GoogleFonts.montserrat(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkBrown,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            height: 1,
            color: AppColors.gold.withValues(alpha: 0.35),
          ),
          SizedBox(height: isMobile ? 14.h : 20.h),

          // QRIS Display Area
          Container(
            width: qrSize + 28.r,
            height: qrSize + 28.r,
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.darkBrown, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBrown.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.darkBrown, strokeWidth: 2.5),
                        SizedBox(height: 12.h),
                        Text(
                          'Memuat QRIS...',
                          style: GoogleFonts.montserrat(
                            fontSize: 11.sp,
                            color: AppColors.brown,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : qrString != null && qrString!.isNotEmpty
                    ? Center(
                        child: QrImageView(
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
                        ),
                      )
                    : Center(
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: AppColors.darkBrown, size: 36),
                          onPressed: onRefresh,
                        ),
                      ),
          ).animate().scale(delay: 100.ms, begin: const Offset(0.96, 0.96)),

          SizedBox(height: isMobile ? 14.h : 18.h),

          // Total Pembayaran
          Text(
            'Total Pembayaran',
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 11.sp : 12.sp,
              color: AppColors.brown,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            price,
            style: GoogleFonts.cormorantGaramond(
              fontSize: isMobile ? 28.sp : 34.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.darkBrown,
            ),
          ),

          SizedBox(height: isMobile ? 8.h : 12.h),

          // Info E-Wallet / Bank
          Text(
            'BCA · Mandiri · BRI · GoPay · OVO · DANA · ShopeePay',
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 9.sp : 10.sp,
              color: AppColors.brown.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          if (orderId != null && orderId!.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              'Order: $orderId',
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 8.5.sp : 9.5.sp,
                color: AppColors.brown.withValues(alpha: 0.55),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          SizedBox(height: isMobile ? 18.h : 24.h),

          // Tombol Simulator Testing
          GestureDetector(
            onTap: onSimulator,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 10.h : 12.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.buttonBrown,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Simulasi Pembayaran (Demo/Kasir)',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: isMobile ? 11.5.sp : 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.creamWhite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Simulator Sheet ───────────────────────────────────────────────────────────

class _SimulatorSheet extends StatelessWidget {
  const _SimulatorSheet({required this.onResult});
  final ValueChanged<String> onResult;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.darkBrown, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.borderWarm,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Simulator Pembayaran (Testing)',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.darkBrown,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Pilih status untuk mensimulasikan hasil gateway',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _SimBtn(
                  label: 'Berhasil (Lunas)',
                  color: AppColors.success,
                  onTap: () => onResult('success'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _SimBtn(
                  label: 'Gagal',
                  color: AppColors.error,
                  onTap: () => onResult('failed'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _SimBtn(
                  label: 'Pending',
                  color: AppColors.warning,
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
  const _SimBtn({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
