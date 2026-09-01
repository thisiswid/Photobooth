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

/// 4R = 4 x 6 inci. marginAll 0 = borderless.
final PdfPageFormat k4R = PdfPageFormat(
  4 * PdfPageFormat.inch,
  6 * PdfPageFormat.inch,
  marginAll: 0,
);

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
    _say('🖨️  Mengirim halaman uji ke "${_selected!.name}" ($label)...');
    _say('    PERHATIKAN LAYAR: tidak boleh ada dialog muncul.');
    try {
      final ok = await Printing.directPrintPdf(
        printer: _selected!,
        name: 'Spike C0 Test 4R',
        format: k4R,
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

  /// Halaman uji borderless: blok warna menyentuh keempat tepi + penanda sudut.
  Future<Uint8List> _buildTestPdf(PdfPageFormat fmt) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: fmt,
        margin: pw.EdgeInsets.zero,
        build: (ctx) {
          return pw.Stack(
            children: [
              // Latar penuh — harus menyentuh tepi kertas kalau borderless aktif
              pw.Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const pw.BoxDecoration(color: PdfColors.indigo800),
              ),
              // Bingkai tepi berwarna, lebar 6pt, tepat di pinggir halaman
              pw.Container(
                width: double.infinity,
                height: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.amber, width: 6),
                ),
              ),
              // Penanda sudut — kalau salah satu terpotong/ada garis putih,
              // borderless belum benar
              _corner(0, 0), _corner(0, null), _corner(null, 0), _corner(null, null),
              pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('SPIKE C0',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 34,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('Uji Silent Print 4R Borderless',
                        style: const pw.TextStyle(
                            color: PdfColors.amber, fontSize: 14)),
                    pw.SizedBox(height: 26),
                    pw.Text('Bingkai kuning harus menyentuh',
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 11)),
                    pw.Text('keempat tepi kertas.',
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 11)),
                    pw.SizedBox(height: 26),
                    pw.Text(
                      '${fmt.width.toStringAsFixed(1)} x '
                      '${fmt.height.toStringAsFixed(1)} pt',
                      style: const pw.TextStyle(
                          color: PdfColors.grey300, fontSize: 10),
                    ),
                    pw.Text(DateTime.now().toString().substring(0, 19),
                        style: const pw.TextStyle(
                            color: PdfColors.grey300, fontSize: 10)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  pw.Widget _corner(double? left, double? top) => pw.Positioned(
        left: left,
        top: top,
        right: left == null ? 0 : null,
        bottom: top == null ? 0 : null,
        child: pw.Container(
          width: 30,
          height: 30,
          decoration: const pw.BoxDecoration(color: PdfColors.red),
        ),
      );

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
            const SizedBox(height: 14),
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
