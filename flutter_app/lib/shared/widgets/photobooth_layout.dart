import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/theme/booth_material.dart';
import '../../features/session/providers/session_provider.dart';
import 'customer_header.dart';
import 'responsive_layout_builder.dart';

/// Cangkang bersama untuk seluruh layar tamu.
///
/// Versi sebelumnya menumpuk EMPAT lapis ornamen di setiap halaman: noise
/// tekstur kertas (CustomPaint yang menggambar ribuan lingkaran tiap
/// repaint), bingkai emas ganda, botanical empat sudut, dan gradient. Semua
/// dinyalakan bersamaan, di semua layar, tanpa satu pun punya tugas.
///
/// Sekarang cangkangnya hanya tiga hal: material, kepala halaman, dan satu
/// garis registrasi yang memisahkan kepala dari isi. Anggarannya satu
/// ornamen per layar, dan garis itu jatahnya.
class PhotoboothLayout extends ConsumerWidget {
  const PhotoboothLayout({
    super.key,
    required this.child,
    this.material = BoothMaterial.paper,
    this.header,
    this.showHeader = true,
  });

  final Widget child;

  /// Kertas (bawaan) untuk layar tempat tamu memilih; kamar gelap untuk layar
  /// tempat gambar jadi subjeknya.
  final BoothMaterial material;

  /// Kepala halaman khusus. Kosongkan untuk memakai [CustomerHeader], yang
  /// otomatis mengikuti [material].
  final Widget? header;

  /// Set false pada layar yang isinya SUDAH membawa nama tenant — misalnya
  /// Tiket, yang mencetak nama kafe di kepala tiketnya sendiri. Menampilkan
  /// brand dua kali di satu layar membuat keduanya terbaca lebih lemah.
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionNotifierProvider);
    final hasTimer = session.hasActiveSession || session.remainingSeconds > 0;

    return Scaffold(
      backgroundColor: material.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Kepala: brand di tengah, timer di kanan ──────────────────
            //
            // Timer duduk sebidang dengan kepala, bukan melayang di atas isi
            // halaman. Brand tetap di tengah optis karena timer diposisikan,
            // bukan ikut mengalir.
            if (showHeader) ...[
              Container(
                height: (context.isMobile ? 52 : 62).h,
                padding: EdgeInsets.symmetric(horizontal: AppGeometry.s16.w),
                child: context.isMobile
                    ? Row(
                        children: [
                          Expanded(
                            child: header ?? CustomerHeader(material: material, isLeftAligned: true),
                          ),
                          if (hasTimer) ...[
                            SizedBox(width: AppGeometry.s8.w),
                            TimerChip(
                              text: session.formattedRemainingTime,
                              isWarning: session.isTimerWarning,
                              material: material,
                            ),
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          // Penyeimbang kiri agar judul berada tepat di tengah optis
                          if (hasTimer)
                            SizedBox(width: 140.w)
                          else
                            const SizedBox.shrink(),

                          Expanded(
                            child: Center(
                              child: header ?? CustomerHeader(material: material),
                            ),
                          ),

                          if (hasTimer)
                            SizedBox(
                              width: 140.w,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TimerChip(
                                  text: session.formattedRemainingTime,
                                  isWarning: session.isTimerWarning,
                                  material: material,
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
              ),

              // ── Garis registrasi ───────────────────────────────────────
              Container(
                height: AppGeometry.hairline,
                color: material.rule,
              ),
            ] else if (hasTimer)
              // Tanpa kepala, timer tetap butuh tempat yang tetap.
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.all(AppGeometry.s16.r),
                  child: TimerChip(
                    text: session.formattedRemainingTime,
                    isWarning: session.isTimerWarning,
                    material: material,
                  ),
                ),
              ),

            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
