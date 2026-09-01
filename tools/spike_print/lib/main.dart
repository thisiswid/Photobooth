import 'dart:typed_data';

// Spike Cycle C0 — LumaBooth Windows Migration
//
// Tujuan tunggal: membuktikan Epson L8050 bisa dicetak dari Flutter Windows
// TANPA dialog apa pun muncul, dengan hasil 4R borderless yang benar.
//
// Halaman uji sengaja dirancang supaya borderless bisa dinilai dengan mata:
// ada blok warna yang menyentuh keempat tepi kertas dan penanda sudut. Kalau
// muncul garis putih di pinggir, berarti borderless BELUM aktif.
//
// Cara pakai: lihat README.md di folder ini.

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() => runApp(const SpikeApp());

/// Kandidat ukuran halaman untuk 4R.
///
/// Kertas "4R" dijual dengan beberapa penyebutan yang ukurannya BEDA TIPIS:
/// 4x6 inci = 101,6 x 152,4 mm · 10x15 cm = 100 x 150 mm · 4R = 102 x 152 mm.
/// Selisih ini yang sering bikin borderless jalan di satu sumbu saja —
/// driver menskalakan pas di lebar, lalu menyisakan pita di atas-bawah.
///
/// Varian BLEED sengaja dibuat lebih besar dari kertas supaya isinya melimpah
/// keluar; kalau driver memotongnya, justru itu yang kita mau untuk borderless.
class PageOption {
  const PageOption(this.label, this.wMm, this.hMm);
  final String label;
  final double wMm;
  final double hMm;
  PdfPageFormat get format => PdfPageFormat(
        wMm * PdfPageFormat.mm,
        hMm * PdfPageFormat.mm,
        marginAll: 0,
      );
}

const kPageOptions = <PageOption>[
  PageOption('4x6 inci — 101,6 x 152,4 mm', 101.6, 152.4),
  PageOption('10x15 cm — 100 x 150 mm', 100, 150),
  PageOption('4R — 102 x 152 mm', 102, 152),
  PageOption('BLEED +2mm — 104 x 154 mm', 104, 154),
  PageOption('BLEED +4mm — 106 x 156 mm', 106, 156),
];

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spike C0 — Silent Print',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const SpikeHome(),
    );
  }
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
  /// Halaman uji hemat tinta (garis tipis) vs uji warna penuh (blok solid).
  bool _inkSaver = true;
  PageOption _page = kPageOptions.first;

  void _say(String msg) {
    final t = DateTime.now().toString().substring(11, 19);
    setState(() => _log.insert(0, '[$t] $msg'));
    debugPrint(msg);
  }

  // ── C0-1: daftar printer ────────────────────────────────────────────────
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
        _say('  • ${p.name}'
            '${p.isDefault ? "  [DEFAULT]" : ""}'
            '  url=${p.url}');
      }
      final epson = list.where(
          (p) => p.name.toLowerCase().contains('l8050') ||
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

  // ── C0-2..C0-4: cetak halaman uji tanpa dialog ──────────────────────────
  Future<void> _printTest({required bool usePrinterSettings}) async {
    if (_selected == null) {
      _say('⚠️  Pilih printer dulu (tekan DETEKSI PRINTER).');
      return;
    }
    setState(() => _busy = true);
    final label = usePrinterSettings ? 'pakai setelan driver' : 'pakai format aplikasi';
    _say(_inkSaver
        ? '   Mode: HEMAT TINTA (garis tipis, ~2% coverage)'
        : '   Mode: WARNA PENUH (blok solid, ~95% coverage — boros tinta)');
    _say('🖨️  Mengirim halaman uji ke "${_selected!.name}" ($label)...');
    _say('    PERHATIKAN LAYAR: tidak boleh ada dialog muncul.');
    try {
      final ok = await Printing.directPrintPdf(
        printer: _selected!,
        name: 'Spike C0 Test 4R',
        format: _page.format,
        usePrinterSettings: usePrinterSettings,
        onLayout: (fmt) => _buildTestPdf(fmt),
      );
      _say(ok
          ? '✅ Job diterima printer. Cek fisik kertasnya sekarang.'
          : '❌ directPrintPdf mengembalikan false — job ditolak/dibatalkan.');
    } catch (e) {
      _say('❌ Gagal cetak: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  /// Halaman uji borderless.
  ///
  /// Mode HEMAT TINTA (default): kertas dibiarkan putih. Yang dicetak hanya
  /// garis-garis tipis di tepi plus tangga penanda milimeter, sehingga kamu
  /// tidak cuma tahu "borderless gagal", tapi tahu **berapa milimeter** yang
  /// terpotong. Coverage tinta sekitar 2%.
  ///
  /// Mode WARNA PENUH: blok solid sampai tepi. Boros tinta, dipakai hanya bila
  /// perlu memeriksa warna dan cakupan penuh menjelang go-live.
  Future<Uint8List> _buildTestPdf(PdfPageFormat fmt) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: fmt,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => _inkSaver ? _inkSaverPage(fmt) : _fullColorPage(fmt),
      ),
    );
    return doc.save();
  }

  // ── Halaman hemat tinta ──────────────────────────────────────────────────
  pw.Widget _inkSaverPage(PdfPageFormat fmt) {
    const mm = PdfPageFormat.mm;
    return pw.Stack(
      children: [
        // Garis tepat di tepi halaman. Kalau borderless benar, keempatnya
        // ikut tercetak. Kalau ada yang hilang, sisi itulah yang terpotong.
        pw.Container(
          width: double.infinity,
          height: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
        ),
        // Garis acuan 3 mm dari tepi — pembanding kalau garis tepi hilang.
        pw.Container(
          width: double.infinity,
          height: double.infinity,
          padding: const pw.EdgeInsets.all(3 * mm),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500, width: 0.4),
            ),
          ),
        ),
        // Penanda sudut berbentuk L (garis, bukan blok terisi).
        ..._cornerMarks(fmt),
        // Tangga milimeter di tepi atas & kiri — untuk MENGUKUR potongan.
        ..._mmLadder(),
        pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('SPIKE C0',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('Uji 4R Borderless — mode hemat tinta',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 14),
              pw.Text('Garis hitam harus menyentuh keempat tepi kertas.',
                  style: const pw.TextStyle(fontSize: 7)),
              pw.Text('Tangga mm menunjukkan berapa yang terpotong.',
                  style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 14),
              pw.Text(
                '${(fmt.width / mm).toStringAsFixed(0)} x '
                '${(fmt.height / mm).toStringAsFixed(0)} mm  ·  '
                '${DateTime.now().toString().substring(0, 16)}',
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Penanda sudut L di keempat pojok, panjang 10 mm, tebal 1 pt.
  List<pw.Widget> _cornerMarks(PdfPageFormat fmt) {
    const mm = PdfPageFormat.mm;
    const len = 10 * mm;
    const w = 1.0;
    return [
      // kiri-atas
      pw.Positioned(left: 0, top: 0, child: pw.Container(width: len, height: w, color: PdfColors.black)),
      pw.Positioned(left: 0, top: 0, child: pw.Container(width: w, height: len, color: PdfColors.black)),
      // kanan-atas
      pw.Positioned(right: 0, top: 0, child: pw.Container(width: len, height: w, color: PdfColors.black)),
      pw.Positioned(right: 0, top: 0, child: pw.Container(width: w, height: len, color: PdfColors.black)),
      // kiri-bawah
      pw.Positioned(left: 0, bottom: 0, child: pw.Container(width: len, height: w, color: PdfColors.black)),
      pw.Positioned(left: 0, bottom: 0, child: pw.Container(width: w, height: len, color: PdfColors.black)),
      // kanan-bawah
      pw.Positioned(right: 0, bottom: 0, child: pw.Container(width: len, height: w, color: PdfColors.black)),
      pw.Positioned(right: 0, bottom: 0, child: pw.Container(width: w, height: len, color: PdfColors.black)),
    ];
  }

  /// Tangga penanda 1-10 mm dari tepi atas dan tepi kiri.
  /// Angka terkecil yang MASIH terlihat = besarnya potongan di sisi itu.
  List<pw.Widget> _mmLadder() {
    const mm = PdfPageFormat.mm;
    const steps = <int>[1, 2, 3, 4, 5, 6, 8, 10];
    final out = <pw.Widget>[];
    for (final d in steps) {
      final off = d * mm;
      // tepi ATAS: garis mendatar pendek, makin jauh dari tepi makin ke bawah
      out.add(pw.Positioned(
          left: 14 * mm,
          top: off,
          child: pw.Container(width: 7 * mm, height: 0.5, color: PdfColors.black)));
      out.add(pw.Positioned(
          left: 21.5 * mm,
          top: off - 1.6,
          child: pw.Text('$d', style: const pw.TextStyle(fontSize: 4.5))));
      // tepi KIRI: garis tegak pendek
      out.add(pw.Positioned(
          left: off,
          top: 30 * mm,
          child: pw.Container(width: 0.5, height: 7 * mm, color: PdfColors.black)));
      out.add(pw.Positioned(
          left: off - 1.2,
          top: 37.5 * mm,
          child: pw.Text('$d', style: const pw.TextStyle(fontSize: 4.5))));
    }
    return out;
  }

  // ── Halaman warna penuh (boros tinta, dipakai seperlunya) ───────────────
  pw.Widget _fullColorPage(PdfPageFormat fmt) {
    return pw.Stack(
      children: [
        pw.Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const pw.BoxDecoration(color: PdfColors.indigo800),
        ),
        pw.Container(
          width: double.infinity,
          height: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.amber, width: 6),
          ),
        ),
        pw.Center(
          child: pw.Text('SPIKE C0 — UJI WARNA PENUH',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spike C0 — Silent Print Epson L8050'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
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
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Ukuran halaman: '),
                const SizedBox(width: 8),
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
              ],
            ),
            SwitchListTile(
              value: _inkSaver,
              onChanged: _busy ? null : (v) => setState(() => _inkSaver = v),
              dense: true,
              title: Text(_inkSaver
                  ? 'Hemat tinta — garis tipis (~2% coverage)'
                  : 'Warna penuh — blok solid (~95% coverage, BOROS)'),
              subtitle: const Text(
                  'Hemat tinta sudah cukup untuk menilai borderless, dan bisa mengukur berapa mm yang terpotong.'),
            ),
            const SizedBox(height: 8),
            if (_printers.isNotEmpty)
              DropdownButton<Printer>(
                value: _selected,
                isExpanded: true,
                items: _printers
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (p) => setState(() => _selected = p),
              ),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFF101418),
                padding: const EdgeInsets.all(12),
                child: ListView.builder(
                  itemCount: _log.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SelectableText(
                      _log[i],
                      style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 12,
                          color: Color(0xFFB8E986)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
