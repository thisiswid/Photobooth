import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/responsive_button.dart';

/// Final Result Screen — header transparan centered 2x.
/// "Hasil Foto" di bawah header.
/// Preview foto LEBIH LEBAR dari QR.
class FinalResultScreen extends ConsumerStatefulWidget {
  const FinalResultScreen({super.key});

  @override
  ConsumerState<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends ConsumerState<FinalResultScreen> {
  static const int _autoResetSeconds = 30;
  Timer? _autoResetTimer;
  int _autoResetCountdown = _autoResetSeconds;

  @override
  void initState() {
    super.initState();
    _startAutoResetCountdown();
  }

  @override
  void dispose() {
    _autoResetTimer?.cancel();
    super.dispose();
  }

  void _startAutoResetCountdown() {
    _autoResetTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _autoResetCountdown--);
      if (_autoResetCountdown <= 0) { t.cancel(); _finishSession(); }
    });
  }

  void _finishSession() {
    _autoResetTimer?.cancel();
    ref.read(sessionNotifierProvider.notifier).resetSession();
    if (mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionNotifierProvider).session;
    final qrUrl = session?.qrToken != null
        ? '${AppConstants.resultBaseUrl}/${session!.qrToken}'
        : AppConstants.resultBaseUrl;
    final finalUrl = session?.finalUrl;

    return PhotoboothLayout(
      header: const CustomerHeader(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Hasil Foto" di bawah header
          Padding(
            padding: EdgeInsets.fromLTRB(32.w, 8.h, 32.w, 0),
            child: Text('Hasil Foto', style: AppTextStyles.headlineLarge)
                .animate().fadeIn(),
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text('Cetak atau download via QR di bawah',
                style: AppTextStyles.caption).animate().fadeIn(delay: 100.ms),
          ),
          SizedBox(height: 12.h),

          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Row(
                children: [
                  // ── Preview foto — LEBIH LEBAR (flex: 4) ──────────────
                  Expanded(
                    flex: 4,
                    child: _PrintedPhotoCard(finalUrl: finalUrl)
                        .animate().slideX(begin: -0.05, duration: 500.ms).fadeIn(duration: 500.ms),
                  ),

                  SizedBox(width: 24.w),

                  // ── QR + Selesai — lebih sempit (flex: 2) ─────────────
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _QrCard(qrUrl: qrUrl),
                        SizedBox(height: 20.h),
                        ResponsiveButton(
                          label: 'SELESAI', icon: Icons.check_rounded,
                          onPressed: _finishSession, width: double.infinity, height: 52.h,
                        ).animate().fadeIn(delay: 500.ms),
                        SizedBox(height: 8.h),
                        Text('Kembali otomatis dalam $_autoResetCountdown detik',
                            style: AppTextStyles.caption, textAlign: TextAlign.center)
                            .animate().fadeIn(delay: 600.ms),
                      ],
                    ).animate().slideX(begin: 0.05, delay: 200.ms),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}

class _PrintedPhotoCard extends StatelessWidget {
  const _PrintedPhotoCard({required this.finalUrl});
  final String? finalUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: AppColors.borderWarm),
        boxShadow: [BoxShadow(
          color: AppColors.darkBrown.withValues(alpha: 0.15),
          blurRadius: 20, offset: const Offset(4, 6))],
      ),
      padding: EdgeInsets.fromLTRB(12.r, 12.r, 12.r, 28.r),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.r),
        child: finalUrl != null
            ? Image.network(finalUrl!, fit: BoxFit.cover, width: double.infinity,
                errorBuilder: (_, __, ___) => _placeholder())
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.paper, width: double.infinity,
    child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo, size: 80, color: AppColors.lightBrown),
        const SizedBox(height: 8),
        Text('Foto akan tampil di sini',
          style: TextStyle(color: AppColors.lightBrown, fontSize: 14)),
      ],
    )),
  );
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.qrUrl});
  final String qrUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.creamWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.darkBrown, width: 1.5),
        boxShadow: [BoxShadow(
          color: AppColors.darkBrown.withValues(alpha: 0.08),
          blurRadius: 12, offset: const Offset(2, 3))],
      ),
      child: Column(
        children: [
          Text('Scan untuk Download', style: AppTextStyles.titleSmall)
              .animate().fadeIn(delay: 300.ms),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(color: AppColors.white,
                borderRadius: BorderRadius.circular(8.r)),
            child: QrImageView(
              data: qrUrl, version: QrVersions.auto,
              size: 140.r, backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
          ).animate().scale(begin: const Offset(0.9, 0.9),
              duration: 400.ms, delay: 300.ms),
          SizedBox(height: 8.h),
          Text('GIF  •  Final  •  Foto', style: AppTextStyles.caption,
              textAlign: TextAlign.center).animate().fadeIn(delay: 450.ms),
        ],
      ),
    );
  }
}
