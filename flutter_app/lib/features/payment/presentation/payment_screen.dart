import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/error_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_button.dart';

/// Payment Screen — header transparan centered 2x.
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
      if (!mounted) { t.cancel(); return; }
      setState(() => _timeoutLeft--);
      if (_timeoutLeft <= 0) { t.cancel(); context.go(AppRoutes.welcome); }
    });
  }

  String get _timeoutText {
    final m = (_timeoutLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_timeoutLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _handlePayment(String result) async {
    Navigator.pop(context);
    setState(() => _isProcessing = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    switch (result) {
      case 'success':
        int realSessionId = 1;
        try {
          final res = await DioClient.instance.dio.post('/sessions', data: {'event_id': 1});
          if (res.data['success'] == true && res.data['data'] != null) {
            realSessionId = res.data['data']['session_id'] ?? 1;
          }
        } catch (e) {
          debugPrint('Session create fallback: $e');
        }

        if (!mounted) return;
        ref.read(sessionNotifierProvider.notifier).startSession(
          sessionId: realSessionId,
          eventId: 1,
          startedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );
        context.go(AppRoutes.frame);
      case 'failed':
        setState(() => _isProcessing = false);
        ErrorLogger.instance.logPaymentError(
          reason: 'Transaksi pembayaran QRIS ditolak / gagal diproses',
          amount: 48000,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pembayaran gagal.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.creamWhite)),
          backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating,
        ));
      case 'pending':
        setState(() => _isProcessing = false);
        ErrorLogger.instance.logPaymentError(
          reason: 'Menunggu konfirmasi gateway (pending timeout)',
          amount: 48000,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Menunggu konfirmasi...', style: AppTextStyles.bodySmall.copyWith(color: AppColors.creamWhite)),
          backgroundColor: AppColors.darkBrown, behavior: SnackBarBehavior.floating,
        ));
    }
  }

  void _showSimulator() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _SimulatorSheet(onResult: _handlePayment),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PhotoboothLayout(
      header: CustomerHeader(trailing: TimerChip(text: _timeoutText)),
      child: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: AppColors.darkBrown))
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
              child: Row(
                children: [
                  // ── QR Code focal point ──────────────────────────────
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Pembayaran', style: AppTextStyles.headlineLarge).animate().fadeIn(),
                        SizedBox(height: 4.h),
                        Text('Scan QRIS untuk melanjutkan', style: AppTextStyles.caption).animate().fadeIn(delay: 100.ms),
                        SizedBox(height: 20.h),
                        Container(
                          width: 220.r, height: 220.r,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.darkBrown, width: 2),
                            boxShadow: [BoxShadow(
                              color: AppColors.darkBrown.withValues(alpha: 0.12),
                              blurRadius: 16, offset: const Offset(3, 4))],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [Icon(Icons.qr_code_2_rounded, size: 160.sp, color: Colors.black87)],
                          ),
                        ).animate().scale(delay: 200.ms, begin: const Offset(0.95, 0.95)),
                        SizedBox(height: 8.h),
                        Text('Scan menggunakan aplikasi dompet digital',
                            style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
                      ],
                    ),
                  ),

                  SizedBox(width: 32.w),

                  // ── Price + CTA ──────────────────────────────────────
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Pembayaran',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.brown)),
                        SizedBox(height: 4.h),
                        Text(_price, style: AppTextStyles.priceText).animate().fadeIn(delay: 300.ms),
                        SizedBox(height: 8.h),
                        Divider(color: AppColors.borderWarm),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            SizedBox(width: 14.r, height: 14.r,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brown)),
                            SizedBox(width: 8.w),
                            Text('Menunggu pembayaran...',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.brown)),
                          ],
                        ).animate(onPlay: (c) => c.repeat(reverse: true))
                            .fadeIn(duration: 1.seconds).then().fadeOut(duration: 1.seconds),
                        SizedBox(height: 32.h),
                        ResponsiveButton(
                          label: 'Simulasi Pembayaran', icon: Icons.payment_rounded,
                          onPressed: _showSimulator, width: double.infinity, height: 52.h,
                        ),
                      ],
                    ),
                  ).animate().slideX(begin: 0.05, delay: 400.ms),
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
        color: AppColors.creamWhite, borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.darkBrown, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40.w, height: 4.h,
            decoration: BoxDecoration(color: AppColors.borderWarm, borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 16.h),
          Text('Simulator Pembayaran', style: AppTextStyles.titleLarge),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(child: _SimBtn(label: 'BERHASIL', icon: Icons.check_circle_outline,
                  color: AppColors.success, onTap: () => onResult('success'))),
              SizedBox(width: 12.w),
              Expanded(child: _SimBtn(label: 'GAGAL', icon: Icons.cancel_outlined,
                  color: AppColors.error, onTap: () => onResult('failed'))),
              SizedBox(width: 12.w),
              Expanded(child: _SimBtn(label: 'PENDING', icon: Icons.hourglass_empty_rounded,
                  color: AppColors.warning, onTap: () => onResult('pending'))),
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
          color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 6.h),
            Text(label, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
