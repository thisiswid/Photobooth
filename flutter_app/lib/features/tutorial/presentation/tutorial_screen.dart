import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_geometry.dart';
import '../../../core/theme/app_motion.dart';
import '../../../shared/widgets/photobooth_layout.dart';
import '../../../shared/widgets/print_furniture.dart';
import '../../../shared/widgets/responsive_button.dart';
import '../../../shared/widgets/responsive_layout_builder.dart';
import '../../provisioning/providers/tenant_provider.dart';

/// Layar Tiket — dulu "Panduan Sesi Photobooth".
///
/// Yang berubah bukan cuma tampilannya, tapi kerangkanya. Lima kotak langkah
/// yang berdiri sendiri adalah bahan bacaan, dan di kiosk tidak ada yang
/// membaca bahan bacaan di antara "mau foto" dan "bayar". Sebuah tiket
/// menyampaikan hal yang sama sambil menjawab pertanyaan yang benar-benar ada
/// di kepala tamu: berapa, dapat apa.
///
/// Tiket juga menyelesaikan keluhan bahwa layar ini terasa kosong. Kerapatan
/// datang dari anatomi dokumennya — garis ganda, perforasi, titik penuntun,
/// nomor seri — bukan dari hiasan yang ditempel. Semua elemen di sini
/// menyatakan sesuatu: di mana disobek, mana tepinya, pasangan mana yang
/// sebaris.
///
/// Nama kafe dicetak di kepala tiket, jadi kepala halaman dimatikan. Menaruh
/// brand dua kali di satu layar membuat keduanya terbaca lebih lemah.
class TutorialScreen extends ConsumerWidget {
  const TutorialScreen({super.key});

  static const _steps = [
    ('1', 'Bayar QRIS', 'scan untuk mulai'),
    ('2', 'Pilih bingkai', 'pilih desain favoritmu'),
    ('3', 'Ambil foto', 'pose saat hitungan mundur'),
    ('4', 'Pilih filter', 'sentuhan warna'),
    ('5', 'Cetak & unduh', 'ambil cetakan, simpan lewat QR'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobile;
    final isPortrait = context.isPortrait;
    final tenant = ref.watch(tenantNotifierProvider).valueOrNull;

    final cafeName =
        (tenant?.cafe.name ?? AppConstants.defaultCafeBrandName).toUpperCase();
    final price = tenant?.pricing.sessionPrice ?? 1000;
    final priceText = 'Rp ${NumberFormat('#,###', 'id_ID').format(price)}';
    final serial = 'No. ${DateFormat('yyyyMMdd').format(DateTime.now())}';

    return PhotoboothLayout(
      showHeader: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _TutorialBackground(isCompact: isMobile || isPortrait),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppGeometry.s24.r),
              child: _Ticket(
                cafeName: cafeName,
                priceText: priceText,
                serial: serial,
                steps: _steps,
                stacked: isMobile || isPortrait,
                onPay: () => context.go(AppRoutes.payment),
              ).animate().fadeIn(duration: AppMotion.reveal),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tiket ────────────────────────────────────────────────────────────────────

class _Ticket extends StatelessWidget {
  const _Ticket({
    required this.cafeName,
    required this.priceText,
    required this.serial,
    required this.steps,
    required this.stacked,
    required this.onPay,
  });

  final String cafeName;
  final String priceText;
  final String serial;
  final List<(String, String, String)> steps;
  final bool stacked;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final body = _TicketBody(
      cafeName: cafeName,
      serial: serial,
      steps: steps,
      stacked: stacked,
    );
    final stub = _TicketStub(
      priceText: priceText,
      onPay: onPay,
      stacked: stacked,
    );

    return Container(
      constraints: BoxConstraints(maxWidth: stacked ? 460.w : 940.w),
      // Garis ganda — tepi tiket cetak. Ini BUKAN "bingkai emas ganda" yang
      // dibuang dari setiap halaman: itu hiasan yang ditempel ke cangkang,
      // ini tepi dokumennya sendiri, dan hanya ada di sini.
      decoration: BoxDecoration(
        color: AppColors.paperBright,
        border: Border.all(
          color: AppColors.ink,
          width: AppGeometry.hairline,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.ink40,
            width: AppGeometry.hairline,
          ),
        ),
        child: stacked
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  body,
                  const Perforation(
                    axis: Axis.horizontal,
                    color: AppColors.ink40,
                    notchColor: AppColors.paper,
                  ),
                  stub,
                ],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: body),
                    const Perforation(
                      color: AppColors.ink40,
                      notchColor: AppColors.paper,
                    ),
                    Expanded(flex: 2, child: stub),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TicketBody extends StatelessWidget {
  const _TicketBody({
    required this.cafeName,
    required this.serial,
    required this.steps,
    required this.stacked,
  });

  final String cafeName;
  final String serial;
  final List<(String, String, String)> steps;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: (stacked ? AppGeometry.s24 : AppGeometry.s32).w,
        vertical: (stacked ? AppGeometry.s24 : AppGeometry.s32).h,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            bottom: AppGeometry.s16.h,
            child: const _TicketStampWatermark(),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Kepala tiket ────────────────────────────────────────────
              Center(
                child: Fleuron(color: AppColors.ink40, width: 110.w),
              ),
              SizedBox(height: AppGeometry.s16.h),
              Center(
                child: Text(
                  cafeName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.display(
                    fontSize: (stacked ? 26 : 34).sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: 1.5,
                    height: 1.1,
                  ),
                ),
              ),
              SizedBox(height: AppGeometry.s4.h),
              Center(
                child: Text(
                  'TIKET SESI PHOTOBOOTH',
                  style: AppFonts.ui(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink40,
                    letterSpacing: 3.4,
                  ),
                ),
              ),

              SizedBox(height: AppGeometry.s24.h),
              Container(height: AppGeometry.hairline, color: AppColors.ink),
              SizedBox(height: AppGeometry.s16.h),

              // ── Langkah ─────────────────────────────────────────────────
              for (final (no, title, desc) in steps) ...[
                _StepLine(no: no, title: title, desc: desc, stacked: stacked),
                if (no != steps.last.$1) SizedBox(height: AppGeometry.s12.h),
              ],

              SizedBox(height: AppGeometry.s16.h),
              Container(height: AppGeometry.hairline, color: AppColors.ink15),
              SizedBox(height: AppGeometry.s12.h),

              // ── Kaki tiket ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BERLAKU SATU SESI',
                    style: AppFonts.ui(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink40,
                      letterSpacing: 2.0,
                    ),
                  ),
                  Text(
                    serial,
                    style: AppFonts.ui(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink40,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Satu baris langkah: nomor, judul, titik penuntun, keterangan.
///
/// Pola daftar-menu cetak — mata membaca judulnya dulu, lalu titik-titik
/// menuntunnya ke keterangan tanpa perlu garis kotak apa pun.
class _StepLine extends StatelessWidget {
  const _StepLine({
    required this.no,
    required this.title,
    required this.desc,
    required this.stacked,
  });

  final String no;
  final String title;
  final String desc;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final number = SizedBox(
      width: 24.w,
      child: Text(
        no,
        style: AppFonts.ui(
          fontSize: (stacked ? 15 : 17).sp,
          fontWeight: FontWeight.w700,
          color: AppColors.spot,
        ),
      ),
    );

    final titleText = Text(
      title,
      style: AppFonts.display(
        fontSize: (stacked ? 15 : 17).sp,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.2,
      ),
    );

    final descText = Text(
      desc,
      style: AppFonts.display(
        fontSize: (stacked ? 13 : 15).sp,
        color: AppColors.ink70,
        height: 1.2,
      ),
    );

    // Di layar sempit, titik penuntun tidak punya ruang untuk bekerja —
    // keterangan turun ke baris berikutnya.
    if (stacked) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          number,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleText, descText],
            ),
          ),
        ],
      );
    }

    // CrossAxisAlignment.baseline gagal di sini: DotLeader adalah CustomPaint
    // dan tidak melaporkan baseline apa pun. Perataan tengah plus sedikit
    // dorongan ke bawah menaruh titik-titiknya setinggi baseline teks tanpa
    // risiko itu.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        number,
        titleText,
        SizedBox(width: AppGeometry.s8.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 5.h),
            child: const DotLeader(color: AppColors.ink15),
          ),
        ),
        SizedBox(width: AppGeometry.s8.w),
        descText,
      ],
    );
  }
}

/// Sobekan tiket — harga dan satu-satunya aksi di layar ini.
class _TicketStub extends StatelessWidget {
  const _TicketStub({
    required this.priceText,
    required this.onPay,
    required this.stacked,
  });

  final String priceText;
  final VoidCallback onPay;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.paperDeep,
      padding: EdgeInsets.symmetric(
        horizontal: AppGeometry.s24.w,
        vertical: (stacked ? AppGeometry.s24 : AppGeometry.s32).h,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SESI FOTO',
            textAlign: TextAlign.center,
            style: AppFonts.ui(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.ink40,
              letterSpacing: 2.6,
            ),
          ),
          SizedBox(height: AppGeometry.s4.h),
          Text(
            priceText,
            textAlign: TextAlign.center,
            style: AppFonts.display(
              fontSize: (stacked ? 30 : 36).sp,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.05,
            ),
          ),

          SizedBox(height: AppGeometry.s24.h),

          ResponsiveButton(
            label: 'Bayar',
            onPressed: onPay,
          ),
        ],
      ),
    );
  }
}

// ── Elemen Desain & Background Dekoratif ──────────────────────────────────────

/// Watermark stempel resmi studio di latar belakang badan tiket.
class _TicketStampWatermark extends StatelessWidget {
  const _TicketStampWatermark();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: -0.15,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.spot.withValues(alpha: 0.18),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '★ PHOTO PASS ★',
                style: AppFonts.ui(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.spot.withValues(alpha: 0.22),
                  letterSpacing: 2.0,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'OFFICIAL ENTRY',
                style: AppFonts.ui(
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spot.withValues(alpha: 0.18),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Latar belakang dekoratif bernuansa meja studio/photobooth.
/// Berisi tanda crop cetak, registrasi bidik kamera, watermark stempel,
/// dan siluet strip foto serta polaroid.
class _TutorialBackground extends StatelessWidget {
  const _TutorialBackground({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Tanda sudut crop marks ──────────────────────────────
          const _CornerCropMarks(),

          // ── Tanda target registrasi cetak ───────────────────────
          const _RegistrationMarks(),

          // ── Cap stempel studio vintage di background ─────────────
          Positioned(
            top: isCompact ? 16.h : 36.h,
            right: isCompact ? 16.w : 48.w,
            child: const _StudioStampWatermark(),
          ),

          // ── Siluet Strip Foto (kiri) ─────────────────────────────
          Positioned(
            left: isCompact ? -18.w : 32.w,
            top: isCompact ? 60.h : 90.h,
            child: _DecorativePhotoStrip(isCompact: isCompact),
          ),

          // ── Siluet Frame Polaroid (kanan bawah) ───────────────────
          Positioned(
            right: isCompact ? -20.w : 40.w,
            bottom: isCompact ? 30.h : 50.h,
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
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
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
      angle: 0.12,
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
                  'AUTHENTIC',
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
      angle: -0.12,
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
      angle: 0.14,
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
