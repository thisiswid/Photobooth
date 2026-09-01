import 'dart:io';
import 'dart:typed_data';

// Spike Cycle C0 — LumaBooth Windows Migration
//
// Tujuan: membuktikan Epson L8050 bisa dicetak dari Flutter Windows TANPA
// dialog, dengan hasil borderless yang benar untuk 4R maupun strip 2x6.
//
// Tiga kendali yang disediakan:
//   1. UKURAN KERTAS  — "4R" dijual dengan beberapa penyebutan yang beda tipis
//   2. BLEED PER SISI — menambal borderless yang cuma jalan di satu sumbu
//   3. HEMAT TINTA    — halaman uji garis tipis, ~2% coverage
//
// Cara pakai: lihat README.md di folder ini.

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const double kMm = PdfPageFormat.mm;

enum PageKind {
  /// Satu bidang cetak penuh.
  single,

  /// Selembar 4x6 berisi DUA strip 2x6 bersebelahan, dengan garis potong.
  /// Ini cara photobooth mencetak strip tanpa perlu kertas khusus.
  stripPair,
}

class PageOption {
  const PageOption(this.label, this.wMm, this.hMm, {this.kind = PageKind.single});
  final String label;
  final double wMm;
  final double hMm;
  final PageKind kind;
}

/// Font bawaan PDF (Helvetica) tidak mendukung karakter non-ASCII seperti
/// em dash. Teks apa pun yang digambar ke PDF harus dibersihkan dulu.
String ascii(String v) => v
    .replaceAll('\u2014', '-')
    .replaceAll('\u2013', '-')
    .replaceAll('\u00b7', '.')
    .replaceAll(RegExp(r'[^\x20-\x7E]'), '');

const kPageOptions = <PageOption>[
  PageOption('4x6 inci — 101,6 x 152,4 mm', 101.6, 152.4),
  PageOption('10x15 cm — 100 x 150 mm', 100, 150),
  PageOption('4R — 102 x 152 mm', 102, 152),
  PageOption('Strip 2x6 inci — 50,8 x 152,4 mm', 50.8, 152.4),
  PageOption('4x6 isi 2 strip 2x6 (ada garis potong)', 101.6, 152.4,
      kind: PageKind.stripPair),
];

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Spike C0 — Silent Print',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const SpikeHome(),
      );
}

class SpikeHome extends StatefulWidget {
  const SpikeHome({super.key});
  @override
  State<SpikeHome> createState() => _SpikeHomeState();
}

class _SpikeHomeState extends State<SpikeHome> {
  final List<String> _log = [];
  List<Printer> _printers = [];
  Printer? _selected;
  bool _busy = false;
  bool _inkSaver = true;
  PageOption _page = kPageOptions.first;

  // Bleed per sisi dalam mm. Halaman PDF dibuat LEBIH BESAR dari kertas
  // sebanyak nilai ini, sehingga isinya melimpah keluar dan dipotong printer.
  // Inilah obat untuk borderless yang hanya menutup satu sumbu.
  double _bTop = 0, _bBottom = 0, _bLeft = 0, _bRight = 0;

  /// Ukuran halaman PDF setelah bleed ditambahkan ke ukuran kertas.
  PdfPageFormat get _format => PdfPageFormat(
        (_page.wMm + _bLeft + _bRight) * kMm,
        (_page.hMm + _bTop + _bBottom) * kMm,
        marginAll: 0,
      );

  bool get _hasBleed => _bTop != 0 || _bBottom != 0 || _bLeft != 0 || _bRight != 0;

  void _say(String msg) {
    final t = DateTime.now().toString().substring(11, 19);
    setState(() => _log.insert(0, '[$t] $msg'));
    debugPrint(msg);
  }

  // ── C0-1 ────────────────────────────────────────────────────────────────
  Future<void> _listPrinters() async {
    setState(() => _busy = true);
    try {
      final list = await Printing.listPrinters();
      setState(() {
        _printers = list;
        _selected = list.where((p) => p.isDefault).firstOrNull ??
            (list.isNotEmpty ? list.first : null);
      });
      _say('Ditemukan ${list.length} printer:');
      for (final p in list) {
        _say('  • ${p.name}${p.isDefault ? "  [DEFAULT]" : ""}');
      }
      final epson = list.where((p) =>
          p.name.toLowerCase().contains('l8050') ||
          p.name.toLowerCase().contains('epson'));
      if (epson.isEmpty) {
        _say('⚠️  Epson TIDAK ditemukan. Pastikan driver resmi sudah terpasang.');
      } else {
        setState(() => _selected = epson.first);
        _say('✅ Epson terdeteksi: ${epson.first.name} — dipilih otomatis.');
      }
    } catch (e) {
      _say('❌ Gagal listPrinters: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  // ── C0-2..C0-4 ──────────────────────────────────────────────────────────
  Future<void> _printTest({required bool usePrinterSettings}) async {
    if (_selected == null) {
      _say('⚠️  Tekan DETEKSI PRINTER dulu.');
      return;
    }
    setState(() => _busy = true);
    final f = _format;
    _say('🖨️  Kirim ke "${_selected!.name}" '
        '(${usePrinterSettings ? "setelan driver" : "format aplikasi"})');
    _say('   Kertas   : ${_page.label}');
    _say('   Bleed    : atas ${_bTop}mm · bawah ${_bBottom}mm · '
        'kiri ${_bLeft}mm · kanan ${_bRight}mm');
    _say('   Halaman  : ${(f.width / kMm).toStringAsFixed(1)} x '
        '${(f.height / kMm).toStringAsFixed(1)} mm');
    _say('   Mode     : ${_inkSaver ? "HEMAT TINTA (~2%)" : "WARNA PENUH (~95%, BOROS)"}');
    _say('   PERHATIKAN LAYAR: tidak boleh ada dialog muncul.');
    _say('   CEK print queue: kalau paper size di sana bukan ukuran di atas,');
    _say('   berarti driver mengabaikan format aplikasi -> atur di Preferences.');
    try {
      final ok = await Printing.directPrintPdf(
        printer: _selected!,
        name: ascii('Spike C0 ${_page.label}'),
        format: f,
        usePrinterSettings: usePrinterSettings,
        onLayout: (fmt) => _buildTestPdf(f),
      );
      _say(ok
          ? '✅ Job diterima printer. Cek hasilnya.'
          : '❌ directPrintPdf mengembalikan false — job ditolak/dibatalkan.');
    } catch (e) {
      _say('❌ Gagal cetak: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  /// Membuka dialog Printing Preferences Windows untuk printer terpilih.
  /// Ukuran kertas & borderless HARUS diatur di sini — bukan dari aplikasi.
  Future<void> _openPrinterPreferences() async {
    final name = _selected!.name;
    _say('Membuka Printing Preferences untuk "$name"...');
    try {
      await Process.run('rundll32', ['printui.dll,PrintUIEntry', '/e', '/n', name]);
    } catch (e) {
      _say('Gagal membuka otomatis: $e');
      _say('Buka manual: Settings > Printers & scanners > $name > Printing preferences');
    }
  }

  Future<Uint8List> _buildTestPdf(PdfPageFormat fmt) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: fmt,
      margin: pw.EdgeInsets.zero,
      build: (_) => _inkSaver ? _inkSaverPage(fmt) : _fullColorPage(fmt),
    ));
    return doc.save();
  }

  // ── Halaman hemat tinta ─────────────────────────────────────────────────
  pw.Widget _inkSaverPage(PdfPageFormat fmt) {
    return pw.Stack(
      children: [
        // Garis tepat di tepi halaman PDF.
        pw.Container(
          width: double.infinity,
          height: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
        ),
        // Acuan 3 mm dari tepi — pembanding kalau garis tepi hilang.
        pw.Container(
          width: double.infinity,
          height: double.infinity,
          padding: const pw.EdgeInsets.all(3 * kMm),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500, width: 0.4),
            ),
          ),
        ),
        ..._cornerMarks(),
        ..._mmLadder(),
        ..._ruler(fmt),
        if (_page.kind == PageKind.stripPair) ..._stripGuides(fmt),
        pw.Center(child: _centerInfo(fmt)),
      ],
    );
  }

  pw.Widget _centerInfo(PdfPageFormat fmt) => pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text('SPIKE C0',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(ascii(_page.label), style: const pw.TextStyle(fontSize: 6)),
          if (_hasBleed)
            pw.Text(
              'bleed T${_bTop} B${_bBottom} L${_bLeft} R${_bRight} mm',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
            ),
          pw.SizedBox(height: 10),
          pw.Text('Garis hitam harus menyentuh keempat tepi.',
              style: const pw.TextStyle(fontSize: 6)),
          pw.Text('Tangga mm menunjukkan berapa yang terpotong.',
              style: const pw.TextStyle(fontSize: 6)),
          pw.SizedBox(height: 10),
          pw.Text(
            '${(fmt.width / kMm).toStringAsFixed(1)} x '
            '${(fmt.height / kMm).toStringAsFixed(1)} mm  '
            '${DateTime.now().toString().substring(0, 16)}',
            style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700),
          ),
        ],
      );

  /// Penanda sudut L, panjang 10 mm.
  List<pw.Widget> _cornerMarks() {
    const len = 10 * kMm;
    const w = 1.0;
    pw.Widget bar(double? l, double? r, double? t, double? b, double ww, double hh) =>
        pw.Positioned(
            left: l, right: r, top: t, bottom: b,
            child: pw.Container(width: ww, height: hh, color: PdfColors.black));
    return [
      bar(0, null, 0, null, len, w), bar(0, null, 0, null, w, len),
      bar(null, 0, 0, null, len, w), bar(null, 0, 0, null, w, len),
      bar(0, null, null, 0, len, w), bar(0, null, null, 0, w, len),
      bar(null, 0, null, 0, len, w), bar(null, 0, null, 0, w, len),
    ];
  }

  /// Tangga 1-10 mm dari tepi atas dan kiri. Angka terkecil yang MASIH
  /// terlihat = besarnya potongan di sisi itu.
  List<pw.Widget> _mmLadder() {
    const steps = <int>[1, 2, 3, 4, 5, 6, 8, 10];
    final out = <pw.Widget>[];
    for (final d in steps) {
      final off = d * kMm;
      out.add(pw.Positioned(
          left: 14 * kMm, top: off,
          child: pw.Container(width: 7 * kMm, height: 0.5, color: PdfColors.black)));
      out.add(pw.Positioned(
          left: 21.5 * kMm, top: off - 1.6,
          child: pw.Text('$d', style: const pw.TextStyle(fontSize: 4.5))));
      out.add(pw.Positioned(
          left: off, top: 30 * kMm,
          child: pw.Container(width: 0.5, height: 7 * kMm, color: PdfColors.black)));
      out.add(pw.Positioned(
          left: off - 1.2, top: 37.5 * kMm,
          child: pw.Text('$d', style: const pw.TextStyle(fontSize: 4.5))));
    }
    return out;
  }

  /// Penggaris melintang di bagian bawah halaman.
  ///
  /// Gunanya membuktikan apakah driver MENSKALAKAN cetakan. Ukur hasil cetak
  /// dengan penggaris sungguhan: kalau tanda "5cm" jatuh tepat di 5 cm, berarti
  /// cetakan 1:1. Kalau meleset, driver menskalakan halaman kita — biasanya
  /// karena ukuran kertas di driver berbeda dari ukuran halaman PDF.
  List<pw.Widget> _ruler(PdfPageFormat fmt) {
    final out = <pw.Widget>[];
    final baseY = fmt.height - 14 * kMm;
    final maxMm = (fmt.width / kMm).floor();
    for (int d = 0; d <= maxMm; d += 5) {
      final isCm = d % 10 == 0;
      out.add(pw.Positioned(
        left: d * kMm,
        top: baseY,
        child: pw.Container(
            width: 0.4,
            height: (isCm ? 4.0 : 2.0) * kMm,
            color: PdfColors.black),
      ));
      if (isCm && d > 0 && d < maxMm - 4) {
        out.add(pw.Positioned(
          left: d * kMm + 1,
          top: baseY + 4.2 * kMm,
          child: pw.Text('\${d ~/ 10}',
              style: const pw.TextStyle(fontSize: 5)),
        ));
      }
    }
    out.add(pw.Positioned(
      left: 2 * kMm,
      top: baseY - 4 * kMm,
      child: pw.Text('PENGGARIS cm - ukur hasil cetak, harus 1:1',
          style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey700)),
    ));
    // garis dasar penggaris
    out.add(pw.Positioned(
      left: 0,
      top: baseY,
      child: pw.Container(
          width: fmt.width, height: 0.4, color: PdfColors.black),
    ));
    return out;
  }

  /// Garis potong di tengah untuk selembar 4x6 berisi dua strip 2x6.
  /// Posisinya dihitung dari tengah KERTAS, bukan tengah halaman, supaya
  /// tetap benar walau ada bleed asimetris.
  List<pw.Widget> _stripGuides(PdfPageFormat fmt) {
    final centerFromLeft = (_bLeft + _page.wMm / 2) * kMm;
    final out = <pw.Widget>[];
    // garis potong putus-putus
    for (double y = 0; y < fmt.height; y += 6) {
      out.add(pw.Positioned(
          left: centerFromLeft - 0.25, top: y,
          child: pw.Container(width: 0.5, height: 3.5, color: PdfColors.grey600)));
    }
    out.add(pw.Positioned(
        left: centerFromLeft + 2, top: 6 * kMm,
        child: pw.Text('POTONG',
            style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600))));
    // label tiap strip
    out.add(pw.Positioned(
        left: 6 * kMm, bottom: 6 * kMm,
        child: pw.Text('STRIP 1 — 2x6"', style: const pw.TextStyle(fontSize: 6))));
    out.add(pw.Positioned(
        right: 6 * kMm, bottom: 6 * kMm,
        child: pw.Text('STRIP 2 — 2x6"', style: const pw.TextStyle(fontSize: 6))));
    return out;
  }

  // ── Halaman warna penuh (boros, seperlunya saja) ────────────────────────
  pw.Widget _fullColorPage(PdfPageFormat fmt) => pw.Stack(children: [
        pw.Container(
            width: double.infinity, height: double.infinity,
            decoration: const pw.BoxDecoration(color: PdfColors.indigo800)),
        pw.Container(
            width: double.infinity, height: double.infinity,
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.amber, width: 6))),
        if (_page.kind == PageKind.stripPair) ..._stripGuides(fmt),
        pw.Center(
            child: pw.Text('SPIKE C0 — UJI WARNA PENUH',
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold))),
      ]);

  // ── UI ──────────────────────────────────────────────────────────────────
  Widget _stepper(String label, double value, ValueChanged<double> onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 46, child: Text(label, style: const TextStyle(fontSize: 12))),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: _busy ? null : () => onChanged(value - 0.5),
        icon: const Icon(Icons.remove, size: 16),
      ),
      SizedBox(
        width: 38,
        child: Text('${value.toStringAsFixed(1)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13)),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: _busy ? null : () => onChanged(value + 0.5),
        icon: const Icon(Icons.add, size: 16),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final f = _format;
    return Scaffold(
      appBar: AppBar(title: const Text('Spike C0 — Silent Print Epson L8050')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _busy ? null : _listPrinters,
              icon: const Icon(Icons.search),
              label: const Text('1. DETEKSI PRINTER'),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : () => _printTest(usePrinterSettings: false),
              icon: const Icon(Icons.print),
              label: const Text('2. CETAK UJI (format aplikasi)'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _printTest(usePrinterSettings: true),
              icon: const Icon(Icons.settings),
              label: const Text('3. CETAK UJI (setelan driver)'),
            ),
            TextButton.icon(
              onPressed: _selected == null ? null : _openPrinterPreferences,
              icon: const Icon(Icons.tune),
              label: const Text('BUKA PRINTING PREFERENCES'),
            ),
          ]),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber),
            ),
            child: const Text(
              'PENTING: ukuran kertas yang dipakai printer datang dari DRIVER, '
              'bukan dari parameter format di aplikasi. Kalau print queue masih '
              'menunjukkan A4, atur dulu Paper Size di Printing Preferences.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Text('Kertas: '),
            const SizedBox(width: 6),
            Expanded(
              child: DropdownButton<PageOption>(
                value: _page,
                isExpanded: true,
                items: kPageOptions
                    .map((o) => DropdownMenuItem(value: o, child: Text(o.label)))
                    .toList(),
                onChanged: _busy ? null : (o) => setState(() => _page = o!),
              ),
            ),
          ]),
          const Divider(height: 12),
          Row(children: [
            const Text('Bleed (mm) — halaman dibuat lebih besar dari kertas:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _bTop = _bBottom = _bLeft = _bRight = 0;
                      }),
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _bTop += 1; _bBottom += 1; _bLeft += 1; _bRight += 1;
                      }),
              child: const Text('Semua +1'),
            ),
          ]),
          Wrap(spacing: 6, runSpacing: 2, children: [
            _stepper('Atas', _bTop, (v) => setState(() => _bTop = v)),
            _stepper('Bawah', _bBottom, (v) => setState(() => _bBottom = v)),
            _stepper('Kiri', _bLeft, (v) => setState(() => _bLeft = v)),
            _stepper('Kanan', _bRight, (v) => setState(() => _bRight = v)),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Kertas ${_page.wMm} x ${_page.hMm} mm  →  halaman PDF '
              '${(f.width / kMm).toStringAsFixed(1)} x '
              '${(f.height / kMm).toStringAsFixed(1)} mm',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ),
          SwitchListTile(
            value: _inkSaver,
            onChanged: _busy ? null : (v) => setState(() => _inkSaver = v),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(_inkSaver
                ? 'Hemat tinta — garis tipis (~2% coverage)'
                : 'Warna penuh — blok solid (~95%, BOROS)'),
          ),
          if (_printers.isNotEmpty)
            DropdownButton<Printer>(
              value: _selected,
              isExpanded: true,
              items: _printers
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (p) => setState(() => _selected = p),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFF101418),
              padding: const EdgeInsets.all(10),
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: SelectableText(
                    _log[i],
                    style: const TextStyle(
                        fontFamily: 'Consolas', fontSize: 12, color: Color(0xFFB8E986)),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
