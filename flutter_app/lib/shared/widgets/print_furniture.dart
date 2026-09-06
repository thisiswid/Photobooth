import 'package:flutter/material.dart';
import '../../core/theme/app_geometry.dart';

/// Perabot cetak — elemen yang dipunyai dokumen cetak sungguhan.
///
/// Ini BUKAN pengecualian dari anggaran ornamen. Anggaran itu melarang hiasan
/// yang DITEMPEL (botanical di empat sudut setiap halaman, noise kertas,
/// bingkai emas). Garis ganda, perforasi, dan titik penuntun adalah anatomi
/// dokumennya sendiri: mereka menyatakan di mana dokumen disobek, mana yang
/// tepinya, dan pasangan mana yang sebaris. Menghapusnya tidak membuat
/// desainnya lebih bersih — hanya membuat kertasnya kosong.

/// Garis putus-putus tempat dokumen disobek, lengkap dengan takik di kedua
/// ujungnya seperti tiket cetak.
class Perforation extends StatelessWidget {
  const Perforation({
    super.key,
    required this.color,
    required this.notchColor,
    this.axis = Axis.vertical,
  });

  final Color color;

  /// Warna takik — harus sama dengan latar DI LUAR tiket, supaya takiknya
  /// terbaca sebagai lubang, bukan titik.
  final Color notchColor;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    // SizedBox.expand, BUKAN SizedBox(height: double.infinity): perforasi
    // vertikal dipakai di dalam IntrinsicHeight, dan tinggi tak hingga di
    // sana membuat perhitungan tinggi intrinsik gagal. SizedBox.expand
    // melaporkan tinggi intrinsik nol lalu mengisi apa pun yang diberikan
    // induknya — persis yang dibutuhkan: setinggi tiket, bukan menentukannya.
    final paint = CustomPaint(
      painter: _PerforationPainter(
        color: color,
        notchColor: notchColor,
        axis: axis,
      ),
      child: const SizedBox.expand(),
    );

    return axis == Axis.vertical
        ? SizedBox(width: 16, child: paint)
        : SizedBox(height: 16, child: paint);
  }
}

class _PerforationPainter extends CustomPainter {
  _PerforationPainter({
    required this.color,
    required this.notchColor,
    required this.axis,
  });

  final Color color;
  final Color notchColor;
  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppGeometry.hairline
      ..strokeCap = StrokeCap.round;

    final notch = Paint()
      ..color = notchColor
      ..style = PaintingStyle.fill;

    const dashLen = 4.0;
    const gapLen = 4.0;
    const notchR = 7.0;

    if (axis == Axis.vertical) {
      final x = size.width / 2;
      var y = notchR * 2;
      while (y < size.height - notchR * 2) {
        canvas.drawLine(Offset(x, y), Offset(x, y + dashLen), dash);
        y += dashLen + gapLen;
      }
      // Takik setengah lingkaran di kedua ujung.
      canvas.drawCircle(Offset(x, 0), notchR, notch);
      canvas.drawCircle(Offset(x, size.height), notchR, notch);
    } else {
      final y = size.height / 2;
      var x = notchR * 2;
      while (x < size.width - notchR * 2) {
        canvas.drawLine(Offset(x, y), Offset(x + dashLen, y), dash);
        x += dashLen + gapLen;
      }
      canvas.drawCircle(Offset(0, y), notchR, notch);
      canvas.drawCircle(Offset(size.width, y), notchR, notch);
    }
  }

  @override
  bool shouldRepaint(covariant _PerforationPainter old) =>
      old.color != color || old.notchColor != notchColor || old.axis != axis;
}

/// Titik penuntun antara label dan nilainya — cara formulir dan daftar menu
/// cetak menyatakan "dua hal ini sebaris".
class DotLeader extends StatelessWidget {
  const DotLeader({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: CustomPaint(painter: _DotLeaderPainter(color)),
    );
  }
}

class _DotLeaderPainter extends CustomPainter {
  _DotLeaderPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const step = 5.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawCircle(Offset(x, size.height / 2), 0.9, p);
    }
  }

  @override
  bool shouldRepaint(covariant _DotLeaderPainter old) => old.color != color;
}

/// Fleuron — tanda pencetak kecil berbentuk belah ketupat dengan garis
/// mengapit. Dipakai SEKALI per dokumen, sebagai penanda kepala.
class Fleuron extends StatelessWidget {
  const Fleuron({super.key, required this.color, this.width = 120});
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 10,
      child: CustomPaint(painter: _FleuronPainter(color)),
    );
  }
}

class _FleuronPainter extends CustomPainter {
  _FleuronPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppGeometry.hairline;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 4.0;

    // Belah ketupat di tengah.
    final diamond = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();
    canvas.drawPath(diamond, fill);

    // Garis mengapit, menipis ke arah tengah.
    canvas.drawLine(Offset(0, cy), Offset(cx - r * 2.2, cy), stroke);
    canvas.drawLine(Offset(cx + r * 2.2, cy), Offset(size.width, cy), stroke);

    // Titik kecil di ujung dalam.
    canvas.drawCircle(Offset(cx - r * 1.6, cy), 1.1, fill);
    canvas.drawCircle(Offset(cx + r * 1.6, cy), 1.1, fill);
  }

  @override
  bool shouldRepaint(covariant _FleuronPainter old) => old.color != color;
}
