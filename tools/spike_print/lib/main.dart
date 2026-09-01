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
  // Kertas 2x6 SUNGGUHAN tidak mungkin di Epson L8050: User-Defined Paper Size
  // di driver mentok pada lebar minimum 89 mm, sedangkan 2 inci = 50,8 mm.
  // Terbukti 2026-09-01. Jangan dicoba lagi.
  //
  // Satu-satunya jalan untuk strip: cetak DUA strip di selembar 4R, lalu potong
  // tengah. Ini juga cara yang lazim dipakai photobooth pada umumnya.
  PageOption('STRIP: 4x6 isi 2 strip 2x6 (potong tengah)', 101.6, 152.4,
      kind: PageKind.stripPair),
  PageOption('STRIP: 10x15cm isi 2 strip (potong tengah)', 100, 150,
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
      build: (_) => _testPage(fmt),
    ));
    return doc.save();
  }

  // ── SATU halaman uji tetap ───────────────────────────────────────────────
  //
  // Isinya SENGAJA tidak pernah berubah: tidak ada tanggal, tidak ada angka
  // setelan. Supaya dua lembar dari percobaan berbeda bisa ditumpuk dan
  // dibandingkan langsung. Provenance ada di log layar, bukan di kertas.
  //
  // Coverage tinta sekitar 1%: hanya garis bingkai dan beberapa patah kata.
  pw.Widget _testPage(PdfPageFormat fmt) {
    return pw.Stack(
      children: [
        // Bingkai tepat di tepi halaman. Sisi yang garisnya hilang = sisi
        // yang dipotong printer.
        pw.Container(
          width: double.infinity,
          height: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
        ),
        // Bingkai acuan 3 mm dari tepi. Kalau bingkai luar hilang tapi yang
        // ini ada, potongannya di bawah 3 mm.
        pw.Container(
          width: double.infinity,
          height: double.infinity,
          padding: const pw.EdgeInsets.all(3 * kMm),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 0.4),
            ),
          ),
        ),
        ..._cornerMarks(),
        // Kata penanda di dekat tiap tepi. Kata yang hilang menunjukkan sisi
        // mana yang terpotong — tanpa perlu mengukur.
        ..._edgeWords(fmt),
        if (_page.kind == PageKind.stripPair) ..._stripGuides(fmt),
        pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('LUMABOOTH',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('TEST PRINT',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 3),
              pw.Text('BORDERLESS CHECK',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            ],
          ),
        ),
      ],
    );
  }

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

  /// Kata penanda dekat tiap tepi, 1,5 mm dari pinggir.
  /// Kata yang tidak tercetak = sisi itu terpotong lebih dari 1,5 mm.
  List<pw.Widget> _edgeWords(PdfPageFormat fmt) {
    const style = pw.TextStyle(fontSize: 6);
    return [
      pw.Positioned(
          top: 1.5 * kMm, left: 0, right: 0,
          child: pw.Center(child: pw.Text('ATAS', style: style))),
      pw.Positioned(
          bottom: 1.5 * kMm, left: 0, right: 0,
          child: pw.Center(child: pw.Text('BAWAH', style: style))),
      pw.Positioned(
          left: 1.5 * kMm, top: fmt.height / 2 - 3,
          child: pw.Text('KIRI', style: style)),
      pw.Positioned(
          right: 1.5 * kMm, top: fmt.height / 2 - 3,
          child: pw.Text('KANAN', style: style)),
    ];
  }

  /// Garis potong di tengah untuk selembar 4R berisi dua strip.
  /// Posisinya dihitung dari tengah KERTAS, bukan tengah halaman PDF, supaya
  /// tetap benar walau bleed-nya asimetris.
  List<pw.Widget> _stripGuides(PdfPageFormat fmt) {
    final centerFromLeft = (_bLeft + _page.wMm / 2) * kMm;
    final out = <pw.Widget>[];
    for (double y = 0; y < fmt.height; y += 6) {
      out.add(pw.Positioned(
          left: centerFromLeft - 0.25, top: y,
          child: pw.Container(width: 0.5, height: 3.5, color: PdfColors.grey600)));
    }
    out.add(pw.Positioned(
        left: 6 * kMm, bottom: 20 * kMm,
        child: pw.Text('STRIP 1', style: const pw.TextStyle(fontSize: 6))));
    out.add(pw.Positioned(
        right: 6 * kMm, bottom: 20 * kMm,
        child: pw.Text('STRIP 2', style: const pw.TextStyle(fontSize: 6))));
    return out;
  }

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
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Pratinjau halaman uji',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(
                '${(f.width / kMm).toStringAsFixed(1)} x '
                '${(f.height / kMm).toStringAsFixed(1)} mm',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Pratinjau me-render PDF yang SAMA PERSIS dengan yang dikirim ke
          // printer, jadi tidak mungkin melenceng dari hasil cetak.
          SizedBox(
            height: 300,
            child: PdfPreview(
              // Key memaksa render ulang setiap ukuran kertas atau bleed berubah.
              key: ValueKey('${_page.label}|$_bTop|$_bBottom|$_bLeft|$_bRight'),
              build: (_) => _buildTestPdf(_format),
              initialPageFormat: _format,
              useActions: false,
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              maxPageWidth: 240,
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
