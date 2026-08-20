import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';

/// Payment Screen — Vintage Receipt & QRIS Payment Card (Step 1).
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isProcessing = false;
  Timer? _timeoutTimer;
  int _timeoutLeft = 300;
  static const String _price = 'Rp 48.000';

  @override
  void initState() {
    super.initState();
    _startTimeout();
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
          content: Text('Pembayaran gagal. Silakan coba lagi.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.creamWhite)),
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
          content: Text('Menunggu konfirmasi...', style: AppTextStyles.bodySmall.copyWith(color: AppColors.creamWhite)),
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
    final isPortrait = context.isPortrait;

    final qrisCard = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14.w : 20.w,
        vertical: isMobile ? 12.h : 16.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderWarm, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Judul Pembayaran & Badge QRIS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.buttonBrown,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'QRIS RESMI',
                  style: GoogleFonts.montserrat(
                    fontSize: isMobile ? 8.5.sp : 10.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'Scan untuk Membayar',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: isMobile ? 18.sp : 22.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkBrown,
                ),
              ),
            ],
          ).animate().fadeIn(),

          SizedBox(height: isMobile ? 10.h : 14.h),

          // Frame QRIS Vintage
          Container(
            padding: EdgeInsets.all(isMobile ? 8.r : 12.r),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.darkBrown, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBrown.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  size: isMobile ? 120.sp : 160.sp,
                  color: Colors.black87,
                ),
              ],
            ),
          ).animate().scale(delay: 200.ms, begin: const Offset(0.95, 0.95)),

          SizedBox(height: isMobile ? 8.h : 12.h),

          // Panduan E-Wallet
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              'BCA • GoPay • OVO • DANA • ShopeePay • LinkAja',
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 9.sp : 10.5.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.darkBrown,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    final receiptCard = Container(
      padding: EdgeInsets.all(isMobile ? 14.r : 20.r),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Nota
          Center(
            child: Text(
              'RINCIAN SESI',
              style: GoogleFonts.cormorantGaramond(
                fontSize: isMobile ? 14.sp : 16.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: AppColors.vintageRust,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Center(
            child: Text(
              'Fakultas Kopi Photobooth',
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 9.5.sp : 11.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.brown,
              ),
            ),
          ),
          SizedBox(height: isMobile ? 6.h : 10.h),
          const Divider(color: AppColors.borderWarm),
          SizedBox(height: isMobile ? 6.h : 8.h),

          // Item Nota
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1x Sesi Foto Photobooth', style: GoogleFonts.montserrat(fontSize: isMobile ? 10.5.sp : 12.sp, color: AppColors.darkBrown)),
              Text('Termasuk', style: GoogleFonts.montserrat(fontSize: isMobile ? 9.5.sp : 11.sp, fontWeight: FontWeight.w600, color: AppColors.brown)),
            ],
          ),
          SizedBox(height: 3.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1x Cetak Photo Strip Asli', style: GoogleFonts.montserrat(fontSize: isMobile ? 10.5.sp : 12.sp, color: AppColors.darkBrown)),
              Text('Termasuk', style: GoogleFonts.montserrat(fontSize: isMobile ? 9.5.sp : 11.sp, fontWeight: FontWeight.w600, color: AppColors.brown)),
            ],
          ),
          SizedBox(height: 3.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('File Foto HD & GIF Digital', style: GoogleFonts.montserrat(fontSize: isMobile ? 10.5.sp : 12.sp, color: AppColors.darkBrown)),
              Text('Gratis', style: GoogleFonts.montserrat(fontSize: isMobile ? 9.5.sp : 11.sp, fontWeight: FontWeight.w700, color: AppColors.success)),
            ],
          ),

          SizedBox(height: isMobile ? 6.h : 10.h),
          const Divider(color: AppColors.borderWarm),
          SizedBox(height: isMobile ? 6.h : 8.h),

          // Total Harga Besar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Total Bayar:', style: GoogleFonts.montserrat(fontSize: isMobile ? 10.5.sp : 12.sp, fontWeight: FontWeight.w600, color: AppColors.brown)),
              Text(
                _price,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: isMobile ? 22.sp : 28.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkBrown,
                ),
              ),
            ],
          ),

          SizedBox(height: isMobile ? 10.h : 14.h),

          // Indikator Menunggu Pembayaran
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: isMobile ? 6.h : 8.h),
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 12.r,
                  height: 12.r,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.brown),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Menunggu konfirmasi scan...',
                  style: GoogleFonts.montserrat(
                    fontSize: isMobile ? 9.5.sp : 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brown,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: isMobile ? 10.h : 14.h),

          // Tombol Simulator
          ResponsiveButton(
            label: 'Simulasi Pembayaran (Demo)',
            icon: Icons.payment_rounded,
            onPressed: _showSimulator,
            width: double.infinity,
            height: isMobile ? 42.h : 48.h,
          ),
        ],
      ),
    ).animate().slideX(begin: 0.05, delay: 300.ms);

    return PhotoboothLayout(
      currentStep: 1,
      header: const CustomerHeader(currentStep: 1),
      child: _isProcessing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.darkBrown, strokeWidth: 3),
                  SizedBox(height: 16.h),
                  Text('Memverifikasi Pembayaran...', style: GoogleFonts.cormorantGaramond(fontSize: 20.sp, fontWeight: FontWeight.w700)),
                ],
              ),
            )
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12.w : 28.w,
                vertical: isMobile ? 6.h : 8.h,
              ),
              child: isMobile || isPortrait
                  ? SingleChildScrollView(
                      child: Column(
                        children: [
                          qrisCard,
                          SizedBox(height: 12.h),
                          receiptCard,
                          SizedBox(height: 12.h),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(flex: 3, child: qrisCard),
                        SizedBox(width: 24.w),
                        Expanded(flex: 2, child: receiptCard),
                      ],
                    ),
            ),
    );
  }
}

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
            decoration: BoxDecoration(color: AppColors.borderWarm, borderRadius: BorderRadius.circular(2)),
          ),
          SizedBox(height: 16.h),
          Text('Simulator Pembayaran Kiosk', style: GoogleFonts.cormorantGaramond(fontSize: 22.sp, fontWeight: FontWeight.w800)),
          SizedBox(height: 6.h),
          Text('Pilih status respons pembayaran untuk pengujian flow', style: AppTextStyles.caption),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _SimBtn(
                  label: 'BERHASIL',
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  onTap: () => onResult('success'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _SimBtn(
                  label: 'GAGAL',
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                  onTap: () => onResult('failed'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _SimBtn(
                  label: 'PENDING',
                  icon: Icons.hourglass_empty_rounded,
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
  const _SimBtn({required this.label, required this.icon, required this.color, required this.onTap});
  final String label;
  final IconData icon;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 6.h),
            Text(label, style: GoogleFonts.montserrat(fontSize: 11.5.sp, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
