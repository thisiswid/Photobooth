import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/session/providers/session_provider.dart';

/// Persistent session timer bar shown at top of post-payment screens.
/// Warm cream design — turns to error color when < 1 minute.
class SessionTimerBar extends ConsumerStatefulWidget {
  const SessionTimerBar({super.key});

  @override
  ConsumerState<SessionTimerBar> createState() => _SessionTimerBarState();
}

class _SessionTimerBarState extends ConsumerState<SessionTimerBar> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final sessionState = ref.read(sessionNotifierProvider);
      final remaining = sessionState.remainingTime;

      if (mounted) setState(() => _remaining = remaining);

      if (remaining == Duration.zero && sessionState.hasActiveSession) {
        _ticker?.cancel();
        ref.read(sessionNotifierProvider.notifier).resetSession();
        if (mounted) context.go(AppRoutes.welcome);
      }
    });
  }

  @override
  void didUpdateWidget(SessionTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _remaining = ref.read(sessionNotifierProvider).remainingTime;
  }

  bool get _isWarning => _remaining.inSeconds < 60;

  String get _formattedTime {
    final minutes = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining.inSeconds /
        AppConstants.sessionDuration.inSeconds;

    final barColor = _isWarning ? AppColors.error : AppColors.darkBrown;
    final bgColor = _isWarning
        ? AppColors.error.withValues(alpha: 0.08)
        : AppColors.creamWhite;

    return Container(
      height: 40.h,
      color: bgColor,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded,
              size: 14.sp, color: barColor.withValues(alpha: 0.7)),
          SizedBox(width: 6.w),
          Text(
            _formattedTime,
            style: (_isWarning
                    ? AppTextStyles.timerTextWarning
                    : AppTextStyles.timerText)
                .copyWith(fontSize: 13.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: AppColors.borderWarm,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 3.h,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            'SISA WAKTU',
            style: AppTextStyles.labelSmall.copyWith(
              color: barColor.withValues(alpha: 0.7),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
