import 'dart:async';
import 'dart:io' as dart_io;
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../../shared/widgets/customer_header.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/photo_strip_widget.dart';
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
  static const int _autoResetSeconds = 60;
  Timer? _autoResetTimer;
  int _autoResetCountdown = _autoResetSeconds;

  @override
  void initState() {
    super.initState();
    _startAutoResetCountdown();
    _triggerBackendGeneration();
  }

  Future<void> _triggerBackendGeneration() async {
    final sessionState = ref.read(sessionNotifierProvider);
    final session = sessionState.session;
    if (session == null) return;

    try {
      final dio_pkg.FormData formData = dio_pkg.FormData();

      if (session.filterId != null) {
        formData.fields.add(MapEntry('filter_id', session.filterId.toString()));
      }
      if (session.selectedFilter != null) {
        formData.fields.add(MapEntry('selected_filter', session.selectedFilter!));
      }
      if (session.frameId != null) {
        formData.fields.add(MapEntry('frame_id', session.frameId.toString()));
      }
      formData.fields.add(MapEntry('event_id', session.eventId.toString()));

      for (int i = 0; i < session.photos.length; i++) {
        final path = session.photos[i].fileUrl;
        final file = dart_io.File(path);
        if (await file.exists()) {
          formData.files.add(MapEntry(
            'photos[]',
            await dio_pkg.MultipartFile.fromFile(
              path,
              filename: 'pose_${i + 1}.jpg',
            ),
          ));
        } else {
          formData.fields.add(MapEntry('photos[]', path));
        }
      }

      final response = await DioClient.instance.dio.post(
        '/sessions/${session.sessionId}/generate-result',
        data: formData,
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final data = response.data['data'];
        ref.read(sessionNotifierProvider.notifier).setResult(
          finalUrl: data['final_url'] ?? '',
          gifUrl:   data['gif_url'] ?? '',
          qrToken:  data['qr_token'] ?? '',
        );
      }
    } catch (e) {
      debugPrint('Backend result generation note: $e');
    }
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
    final sessionState = ref.watch(sessionNotifierProvider);
    final session = sessionState.session;
    final photos = session?.photos ?? [];
    final frame = sessionState.selectedFrame;

    final qrUrl = session?.qrToken != null
        ? '${AppConstants.resultBaseUrl}/${session!.qrToken}'
        : AppConstants.resultBaseUrl;

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
            child: Text('Cetak atau download via QR di samping',
                style: AppTextStyles.caption).animate().fadeIn(delay: 100.ms),
          ),
          SizedBox(height: 12.h),

          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Row(
                children: [
                  // ── Preview Photo Strip dengan Frame (flex: 3) ─────────
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: PhotoStripWidget(
                        photos: photos,
                        frame: frame,
                        colorFilter: sessionState.selectedFilter?.colorFilter,
                      ),
                    ).animate().scale(begin: const Offset(0.95, 0.95), duration: 500.ms).fadeIn(duration: 500.ms),
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
