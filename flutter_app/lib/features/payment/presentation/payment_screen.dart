import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

/// Payment Screen — 1 card QRIS di tengah, layout minimal, tanpa step/receipt berlebihan.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isProcessing = false;
  Timer? _timeoutTimer;
  int _timeoutLeft = 180;

  @override
  void initState() {
    super.initState();
    final tenantConfig = ref.read(tenantNotifierProvider).valueOrNull;
    _timeoutLeft = tenantConfig?.timers.paymentTimeoutSeconds ?? 180;
    _startTimeout();
  }

  String _formatPrice(int price) {
    final formatted = NumberFormat('#,###', 'id_ID').format(price);
    return 'Rp $formatted';
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timeoutLeft--);
      if (_timeoutLeft <= 0) {
        t.cancel();
        context.go(AppRoutes.welcome);
      }
    });
  }

  Future<void> _handlePayment(String result) async {
    Navigator.pop(context);
    setState(() => _isProcessing = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    switch (result) {
      case 'success':
        int realSessionId = 1;
        DateTime expiresAt = DateTime.now().add(AppConstants.sessionDuration);
        try {
          final res = await DioClient.instance.dio.post('/sessions', data: {'event_id': 1});
          if (res.data['success'] == true && res.data['data'] != null) {
            realSessionId = res.data['data']['session_id'] ?? 1;
            if (res.data['data']['expires_at'] != null) {
              expiresAt = DateTime.parse(res.data['data']['expires_at']).toLocal();
            } else if (res.data['data']['session_timeout_seconds'] != null) {
              final seconds = res.data['data']['session_timeout_seconds'] as int;
              expiresAt = DateTime.now().add(Duration(seconds: seconds));
            }
          }
        } catch (e) {
          debugPrint('Session create fallback: $e');
        }

        if (!mounted) return;
        ref.read(sessionNotifierProvider.notifier).startSession(
          sessionId: realSessionId,
          eventId: 1,
          startedAt: DateTime.now(),
          expiresAt: expiresAt,
        );
        context.go(AppRoutes.frame);
      case 'failed':
        setState(() => _isProcessing = false);
        ErrorLogger.instance.logPaymentError(
          reason: 'Transaksi pembayaran QRIS ditolak / gagal diproses',
          amount: 48000,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pembayaran gagal. Silakan coba lagi.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.creamWhite)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      case 'pending':
        setState(() => _isProcessing = false);
        ErrorLogger.instance.logPaymentError(
          reason: 'Menunggu konfirmasi gateway (pending timeout)',
          amount: 48000,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Menunggu konfirmasi...',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.creamWhite)),
          backgroundColor: AppColors.darkBrown,
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  void _showSimulator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimulatorSheet(onResult: _handlePayment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

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

    final tenantConfig = ref.watch(tenantNotifierProvider).valueOrNull;
    final dynamicPrice = _formatPrice(tenantConfig?.pricing.sessionPrice ?? 25000);

    return PhotoboothLayout(
      header: const CustomerHeader(),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20.w : 60.w,
            vertical: isMobile ? 12.h : 20.h,
          ),
          child: _QrisMainCard(
            price: dynamicPrice,
            isMobile: isMobile,
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
    required this.isMobile,
    required this.onSimulator,
  });

  final String price;
  final bool isMobile;
  final VoidCallback onSimulator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.w : 40.w,
        vertical: isMobile ? 24.h : 36.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderWarm, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Judul
          Text(
            'Scan untuk Membayar',
            style: GoogleFonts.cormorantGaramond(
              fontSize: isMobile ? 22.sp : 28.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.darkBrown,
            ),
          ),

          SizedBox(height: 4.h),
          Container(
            width: 36.w,
            height: 1.2,
            color: AppColors.gold.withValues(alpha: 0.55),
          ),
          SizedBox(height: isMobile ? 16.h : 22.h),

          // QRIS placeholder (ganti dengan Image.asset saat QRIS real tersedia)
          Container(
            padding: EdgeInsets.all(isMobile ? 10.r : 14.r),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.darkBrown, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBrown.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.qr_code_2_rounded,
              size: isMobile ? 130.sp : 180.sp,
              color: Colors.black87,
            ),
          ).animate().scale(delay: 150.ms, begin: const Offset(0.95, 0.95)),

          SizedBox(height: isMobile ? 16.h : 22.h),

          // Total pembayaran
          Text(
            'Total',
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 10.sp : 12.sp,
              color: AppColors.brown,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            price,
            style: GoogleFonts.cormorantGaramond(
              fontSize: isMobile ? 28.sp : 36.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.darkBrown,
            ),
          ),

          SizedBox(height: isMobile ? 12.h : 16.h),

          // E-wallet hint
          Text(
            'BCA · GoPay · OVO · DANA · ShopeePay',
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 9.sp : 10.sp,
              color: AppColors.brown.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: isMobile ? 20.h : 28.h),

          // Tombol simulator
          GestureDetector(
            onTap: onSimulator,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 11.h : 13.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.buttonBrown,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Simulasi Pembayaran (Demo)',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: isMobile ? 12.sp : 13.sp,
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
                borderRadius: BorderRadius.circular(2)),
          ),
          SizedBox(height: 16.h),
          Text(
            'Simulator Pembayaran',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 22.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6.h),
          Text('Pilih status untuk pengujian flow',
              style: AppTextStyles.caption),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _SimBtn(
                  label: 'Berhasil',
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
              fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
