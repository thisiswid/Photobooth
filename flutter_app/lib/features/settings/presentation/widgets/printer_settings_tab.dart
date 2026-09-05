import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart' show Printer;

import '../../../../core/services/printer_service.dart';
import '../../../../core/services/printing/windows_printer_backend.dart';
import '../../../../core/services/ipp/ipp_client.dart';
import '../../../../core/services/ipp/network_scan.dart';
import '../../../../core/theme/app_colors.dart';

/// Tab Printer Settings khusus Operator Kiosk — Murni mengontrol koneksi Direct USB + Wi-Fi Fallback
class PrinterSettingsTab extends StatefulWidget {
  const PrinterSettingsTab({super.key});

  @override
  State<PrinterSettingsTab> createState() => _PrinterSettingsTabState();
}

class _PrinterSettingsTabState extends State<PrinterSettingsTab> {
  final _ipController = TextEditingController();
  final _horizController = TextEditingController();
  final _vertController = TextEditingController();

  PrinterConnectionMode _connectionMode = PrinterConnectionMode.usbWifiAuto;
  Map<String, dynamic> _statusData = {};
  bool _isLoadingStatus = true;

  bool _borderless = true;
  String _quality = 'Standard';
  String _marginUnit = 'mm';

  // ── Windows: daftar printer spooler & status sesungguhnya ──
  List<Printer> _winPrinters = const [];
  String? _winSelectedName;
  Map<String, dynamic> _winStatus = const {};
  bool _winLoading = false;
  bool _autoPrint = true;
  bool _printingEnabled = true;
  bool _autoReconnect = true;
  int _retryCount = 3;

  bool _isTestingPrint = false;
  String? _testMessage;

  // ── USB Diagnostic (Tahap 1 — deteksi jalur silent print) ──
  bool _isProbing = false;
  Map<String, dynamic>? _probeResult;

  // ── IPP Diagnostic (jalur silent print utama) ──
  final _ippPortController = TextEditingController();
  bool _ippEnabled = false;
  bool _isIppProbing = false;
  IppPrinterInfo? _ippInfo;

  // ── Network Diagnostic ──
  List<LocalAddress> _localAddrs = const [];
  Map<int, bool>? _portCheck;
  bool _isCheckingPorts = false;
  bool _isScanning = false;
  String _scanProgress = '';
  List<FoundPrinter> _foundPrinters = const [];
  Map<String, dynamic>? _netDiag;
  bool _bindWifi = true;
  bool _autoDiscover = true;
  bool _strictSilent = false;
  bool _coverDialog = true;
  bool _canOverlay = false;
  bool _isDiagnosing = false;
  String? _diagReport;
  Map<String, dynamic>? _helperStatus;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
    if (Platform.isWindows) _loadWindowsPrinters();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _horizController.dispose();
    _vertController.dispose();
    _ippPortController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSettings() async {
    setState(() => _isLoadingStatus = true);

    final mode = await PrinterService.getConnectionMode();
    final ip = await PrinterService.getIpAddress();
    final borderless = await PrinterService.getBorderless();
    final quality = await PrinterService.getQuality();
    final marginHoriz = await PrinterService.getMarginHorizontal();
    final marginVert = await PrinterService.getMarginVertical();
    final marginUnit = await PrinterService.getMarginUnit();
    final autoPrint = await PrinterService.getAutoPrint();
    final autoReconnect = await PrinterService.getAutoReconnect();
    final retries = await PrinterService.getRetryCount();
    final ippEnabled = await PrinterService.getIppEnabled();
    final ippPort = await PrinterService.getIppPort();
    final localAddrs = await PrinterService.getLocalAddresses();
    final bindWifi = await PrinterService.getBindWifi();
    final netDiag = await PrinterService.getNetworkDiagnostics();
    final autoDiscover = await PrinterService.getIppAutoDiscover();
    final strictSilent = await PrinterService.getStrictSilent();
    final helperStatus = await PrinterService.getAutoPrintHelperStatus();
    final coverDialog = await PrinterService.getCoverDialog();
    final printingEnabled = await PrinterService.getPrintingEnabled();
    final canOverlay = await PrinterService.canDrawOverlays();

    final status = await PrinterService.getPrinterStatus();

    if (mounted) {
      setState(() {
        _connectionMode = mode;
        _ipController.text = ip;
        _borderless = borderless;
        _quality = quality;
        _marginUnit = marginUnit;
        _horizController.text = marginHoriz.toString();
        _vertController.text = marginVert.toString();
        _autoPrint = autoPrint;
        _printingEnabled = printingEnabled;
        _autoReconnect = autoReconnect;
        _retryCount = retries;
        _ippEnabled = ippEnabled;
        _ippPortController.text = ippPort.toString();
        _localAddrs = localAddrs;
        _bindWifi = bindWifi;
        _netDiag = netDiag;
        _autoDiscover = autoDiscover;
        _strictSilent = strictSilent;
        _helperStatus = helperStatus;
        _coverDialog = coverDialog;
        _canOverlay = canOverlay;
        _statusData = status;
        _isLoadingStatus = false;
      });
    }
  }

  Future<void> _refreshStatus() async {
    final status = await PrinterService.getPrinterStatus();
    if (mounted) {
      setState(() {
        _statusData = status;
      });
    }
  }

  Future<void> _handleTestPrint() async {
    final ip = _ipController.text.trim();
    if (ip.isNotEmpty) {
      await PrinterService.setIpAddress(ip);
    }
    await PrinterService.setConnectionMode(_connectionMode);

    setState(() {
      _isTestingPrint = true;
      _testMessage = null;
    });

    final result = await PrinterService.printTestPage();

    if (mounted) {
      setState(() {
        _isTestingPrint = false;
        _testMessage = result.message;
      });
      _refreshStatus();
      final helper = await PrinterService.getAutoPrintHelperStatus();
      if (mounted) setState(() => _helperStatus = helper);
    }
  }

  Future<void> _handleFullDiagnosis() async {
    final ip = _ipController.text.trim();
    if (ip.isNotEmpty) {
      await PrinterService.setIpAddress(ip);
    }

    setState(() {
      _isDiagnosing = true;
      _diagReport = null;
    });

    final report = await PrinterService.buildDiagnosticReport();

    if (mounted) {
      setState(() {
        _isDiagnosing = false;
        _diagReport = report;
      });
    }
  }

  Future<void> _handlePortCheck() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    await PrinterService.setIpAddress(ip);

    setState(() {
      _isCheckingPorts = true;
      _portCheck = null;
    });

    final res = await PrinterService.checkPrinterPorts(ip: ip);

    if (mounted) {
      setState(() {
        _isCheckingPorts = false;
        _portCheck = res;
      });
    }
  }

  Future<void> _handleNetworkScan() async {
    setState(() {
      _isScanning = true;
      _foundPrinters = const [];
      _scanProgress = 'Memulai...';
    });

    final addrs = await PrinterService.getLocalAddresses();
    final diag = await PrinterService.getNetworkDiagnostics();
    if (mounted) {
      setState(() {
        _localAddrs = addrs;
        _netDiag = diag;
      });
    }

    final found = await PrinterService.scanForPrinters(
      onProgress: (subnet, done, total) {
        if (mounted) {
          setState(() => _scanProgress = '$subnet.0/24 — $done/$total host');
        }
      },
    );

    if (mounted) {
      setState(() {
        _isScanning = false;
        _foundPrinters = found;
        _scanProgress = found.isEmpty
            ? 'Selesai — tidak ada printer ditemukan.'
            : 'Selesai — ${found.length} kandidat ditemukan.';
      });
    }
  }

  Future<void> _useFoundPrinter(FoundPrinter printer) async {
    _ipController.text = printer.ip;
    await PrinterService.setIpAddress(printer.ip);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('IP printer diset ke ${printer.ip}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    await _handleIppProbe();
  }

  Future<void> _handleIppProbe() async {
    final ip = _ipController.text.trim();
    if (ip.isNotEmpty) {
      await PrinterService.setIpAddress(ip);
    }
    final port = int.tryParse(_ippPortController.text.trim());
    if (port != null && port > 0) {
      await PrinterService.setIppPort(port);
    }

    setState(() {
      _isIppProbing = true;
      _ippInfo = null;
    });

    final info = await PrinterService.probeIppPrinter();

    if (mounted) {
      setState(() {
        _isIppProbing = false;
        _ippInfo = info;
      });
    }
  }

  Future<void> _handleUsbProbe() async {
    setState(() {
      _isProbing = true;
      _probeResult = null;
    });

    final res = await PrinterService.probeUsbInterfaces();

    if (mounted) {
      setState(() {
        _isProbing = false;
        _probeResult = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStatus) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    final usbDetected = _statusData['usbDetected'] == true;
    final usbPermission = _statusData['usbPermission'] == true;
    final wifiReachable = _statusData['wifiReachable'] == true;
    final activeConn = _statusData['activeConnection'] as String? ?? 'None';

    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        // ── SAKLAR UTAMA CETAK ─────────────────────────────────────────────
        //
        // Ditaruh paling atas karena ini yang paling sering dicari saat
        // menguji: mematikannya membuat seluruh alur sesi bisa diulang
        // berkali-kali tanpa menghabiskan kertas dan tinta.
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: _printingEnabled
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF9E2A2B).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: _printingEnabled
                  ? AppColors.gold.withValues(alpha: 0.3)
                  : const Color(0xFFE57373),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSwitchRow(
                label: 'Mode Cetak Aktif',
                value: _printingEnabled,
                onChanged: (val) async {
                  setState(() => _printingEnabled = val);
                  await PrinterService.setPrintingEnabled(val);
                },
              ),
              SizedBox(height: 6.h),
              Text(
                _printingEnabled
                    ? 'Foto akan dicetak seperti biasa.'
                    : 'MODE PENGUJIAN — tidak ada yang dicetak. Alur sesi tetap '
                        'berjalan sampai selesai dan dilaporkan berhasil, tetapi '
                        'tidak ada perintah yang dikirim ke printer. JANGAN '
                        'ditinggal mati saat kiosk dipakai pelanggan.',
                style: TextStyle(
                  color: _printingEnabled ? Colors.white70 : const Color(0xFFFFCDD2),
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // ── SECTION 1: PRINTER CONNECTION ──────────────────────────────────
        _buildSectionHeader('PRINTER CONNECTION'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Model
              _buildSettingRow(
                label: 'Model Printer',
                child: Text(
                  'Epson L8050 Photo Printer',
                  style: GoogleFonts.montserrat(
                    color: AppColors.creamWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                  ),
                ),
              ),
              const Divider(color: Colors.white12),

              // Connection Mode Dropdown
              _buildSettingRow(
                label: 'Connection Mode',
                child: DropdownButton<PrinterConnectionMode>(
                  value: _connectionMode,
                  dropdownColor: AppColors.darkBrown,
                  style: GoogleFonts.montserrat(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  underline: const SizedBox.shrink(),
                  onChanged: (mode) async {
                    if (mode != null) {
                      setState(() => _connectionMode = mode);
                      await PrinterService.setConnectionMode(mode);
                      _refreshStatus();
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: PrinterConnectionMode.usbWifiAuto,
                      child: Text('USB + Wi-Fi Auto (Rekomendasi)'),
                    ),
                    DropdownMenuItem(
                      value: PrinterConnectionMode.usbOnly,
                      child: Text('USB Only'),
                    ),
                    DropdownMenuItem(
                      value: PrinterConnectionMode.wifiOnly,
                      child: Text('Wi-Fi Only'),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),

              // USB Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.usb_rounded, color: usbDetected ? Colors.greenAccent : Colors.white38, size: 18.r),
                      SizedBox(width: 8.w),
                      Text('USB Connection', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: (usbDetected && usbPermission ? Colors.green : Colors.red).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(color: usbDetected && usbPermission ? Colors.green : Colors.red),
                        ),
                        child: Text(
                          usbDetected
                              ? (usbPermission ? '● Connected' : '⚠️ Permission Required')
                              : '● Disconnected',
                          style: TextStyle(
                            color: usbDetected && usbPermission ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (usbDetected && !usbPermission) ...[
                        SizedBox(width: 6.w),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.darkBrown,
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () async {
                            await PrinterService.requestUsbPermission();
                            _refreshStatus();
                          },
                          child: Text('Minta Izin', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              // Wi-Fi Status & IP Input
              Row(
                children: [
                  Icon(Icons.wifi_rounded, color: wifiReachable ? Colors.greenAccent : Colors.white38, size: 18.r),
                  SizedBox(width: 8.w),
                  Text('Wi-Fi IP Address', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
                  const Spacer(),
                  SizedBox(
                    width: 140.w,
                    height: 36.h,
                    child: TextField(
                      controller: _ipController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontSize: 12.sp),
                      decoration: InputDecoration(
                        hintText: '192.168.1.11',
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 11.sp),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.r)),
                      ),
                      onChanged: (val) async {
                        await PrinterService.setIpAddress(val.trim());
                      },
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: (wifiReachable ? Colors.green : Colors.red).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: wifiReachable ? Colors.green : Colors.red),
                    ),
                    child: Text(
                      wifiReachable ? '● Reachable' : '● Offline',
                      style: TextStyle(
                        color: wifiReachable ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),

              // Active Connection Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active Connection Status', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
                  Chip(
                    backgroundColor: activeConn != 'None' ? AppColors.gold : Colors.grey,
                    label: Text(
                      activeConn,
                      style: TextStyle(color: AppColors.darkBrown, fontWeight: FontWeight.bold, fontSize: 11.sp),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12.h),
              // Test Print Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.darkBrown,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  onPressed: _isTestingPrint ? null : _handleTestPrint,
                  icon: _isTestingPrint
                      ? SizedBox(width: 16.r, height: 16.r, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBrown))
                      : const Icon(Icons.print_rounded),
                  label: Text(
                    _isTestingPrint ? 'Mencetak Test Page...' : 'Test Print Direct',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12.5.sp),
                  ),
                ),
              ),

              if (_testMessage != null) ...[
                SizedBox(height: 8.h),
                Text(
                  _testMessage!,
                  style: TextStyle(color: Colors.amberAccent, fontSize: 11.sp),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // ── Panel diagnostik di bawah ini KHUSUS ANDROID ────────────────────
        //
        // Semuanya lahir dari keterbatasan Android: IPP dicoba karena tidak ada
        // silent print, AUTO-PRINT HELPER menekan tombol dialog lewat
        // Accessibility, USB DIAGNOSTIC memeriksa izin USB Host API, dan
        // NETWORK DIAGNOSTIC memburu printer lewat IP.
        //
        // Di Windows tidak satu pun relevan: driver Epson menangani semuanya,
        // dan printer USB sama sahnya dengan printer jaringan. Menampilkannya
        // hanya akan membingungkan operator dengan tombol yang tidak berguna.
        if (Platform.isAndroid) ...[
          _buildNetworkDiagnosticSection(),
          SizedBox(height: 16.h),
          _buildIppDiagnosticSection(),
          SizedBox(height: 16.h),
          _buildAutoPrintHelperSection(),
          SizedBox(height: 16.h),
          _buildUsbDiagnosticSection(),
          SizedBox(height: 16.h),
        ],

        if (Platform.isWindows) ...[
          _buildWindowsPrinterSection(),
          SizedBox(height: 16.h),
        ],

        // ── SECTION 2: PRINT CONFIGURATION ─────────────────────────────────
        _buildSectionHeader('PRINT SETTINGS'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              _buildSettingRow(
                label: 'Paper Size',
                child: Text('4×6 inch (10×15 cm)', style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontSize: 12.sp)),
              ),
              const Divider(color: Colors.white12),
              _buildSettingRow(
                label: 'Copies',
                child: Text('1 Lembar per Sesi', style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontSize: 12.sp)),
              ),
              const Divider(color: Colors.white12),
              _buildSettingRow(
                label: 'Print Quality',
                child: DropdownButton<String>(
                  value: _quality,
                  dropdownColor: AppColors.darkBrown,
                  style: GoogleFonts.montserrat(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  underline: const SizedBox.shrink(),
                  onChanged: (val) async {
                    if (val != null) {
                      setState(() => _quality = val);
                      await PrinterService.setQuality(val);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'Low', child: Text('Low (200 DPI)')),
                    DropdownMenuItem(value: 'Standard', child: Text('Standard (300 DPI)')),
                    DropdownMenuItem(value: 'High', child: Text('High (600 DPI)')),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              _buildSettingRow(
                label: 'Orientation',
                child: Text('Auto (Portrait)', style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontSize: 12.sp)),
              ),
              const Divider(color: Colors.white12),
              _buildSwitchRow(
                label: 'Borderless Printing',
                value: _borderless,
                onChanged: (val) async {
                  setState(() => _borderless = val);
                  await PrinterService.setBorderless(val);
                },
              ),
              const Divider(color: Colors.white12),
              _buildSwitchRow(
                label: 'Auto Print After Session',
                value: _autoPrint,
                onChanged: (val) async {
                  setState(() => _autoPrint = val);
                  await PrinterService.setAutoPrint(val);
                },
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // ── SECTION 3: PRINT MARGIN (CUSTOM MARGIN) ────────────────────────
        _buildSectionHeader('PRINT MARGIN (CUSTOM MARGIN)'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSettingRow(
                label: 'Unit Satuan Margin',
                child: DropdownButton<String>(
                  value: _marginUnit,
                  dropdownColor: AppColors.darkBrown,
                  style: GoogleFonts.montserrat(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  underline: const SizedBox.shrink(),
                  onChanged: (u) async {
                    if (u != null) {
                      setState(() => _marginUnit = u);
                      await PrinterService.setMarginUnit(u);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'mm', child: Text('mm (Millimeter)')),
                    DropdownMenuItem(value: 'cm', child: Text('cm (Centimeter)')),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Horizontal Margin', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
                        Text('Kompensasi bleed kiri & kanan. Naikkan bila tepi frame terpotong', style: TextStyle(color: Colors.white38, fontSize: 9.sp)),
                      ],
                    ),
                    SizedBox(
                      width: 100.w,
                      height: 38.h,
                      child: TextField(
                        controller: _horizController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
                        style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontSize: 12.sp, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          suffixText: _marginUnit,
                          suffixStyle: GoogleFonts.montserrat(color: AppColors.gold, fontSize: 11.sp),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.r)),
                        ),
                        onChanged: (val) async {
                          final parsed = double.tryParse(val.trim());
                          // Nilai NEGATIF diperbolehkan: di Windows angka ini
                          // menggeser gambar, bukan menyisakan tepi kosong.
                          if (parsed != null && parsed >= -20 && parsed <= 20) {
                            await PrinterService.setMarginHorizontal(parsed);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vertical Margin', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
                        Text('Kompensasi bleed atas & bawah. Naikkan bila tepi frame terpotong', style: TextStyle(color: Colors.white38, fontSize: 9.sp)),
                      ],
                    ),
                    SizedBox(
                      width: 100.w,
                      height: 38.h,
                      child: TextField(
                        controller: _vertController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
                        style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontSize: 12.sp, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          suffixText: _marginUnit,
                          suffixStyle: GoogleFonts.montserrat(color: AppColors.gold, fontSize: 11.sp),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.r)),
                        ),
                        onChanged: (val) async {
                          final parsed = double.tryParse(val.trim());
                          if (parsed != null && parsed >= -20 && parsed <= 20) {
                            await PrinterService.setMarginVertical(parsed);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // ── SECTION 4: RELIABILITY & RETRY ─────────────────────────────────
        _buildSectionHeader('RELIABILITY & RETRY POLICY'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              _buildSwitchRow(
                label: 'Auto Reconnect USB/Wi-Fi',
                value: _autoReconnect,
                onChanged: (val) async {
                  setState(() => _autoReconnect = val);
                  await PrinterService.setAutoReconnect(val);
                },
              ),
              const Divider(color: Colors.white12),
              _buildSettingRow(
                label: 'Max Retry Count',
                child: DropdownButton<int>(
                  value: _retryCount,
                  dropdownColor: AppColors.darkBrown,
                  style: GoogleFonts.montserrat(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  underline: const SizedBox.shrink(),
                  onChanged: (val) async {
                    if (val != null) {
                      setState(() => _retryCount = val);
                      await PrinterService.setRetryCount(val);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 Kali')),
                    DropdownMenuItem(value: 2, child: Text('2 Kali')),
                    DropdownMenuItem(value: 3, child: Text('3 Kali (Default)')),
                    DropdownMenuItem(value: 5, child: Text('5 Kali')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── NETWORK DIAGNOSTIC SECTION ────────────────────────────────────────────
  //
  // "Printer tidak terjangkau" punya banyak sebab yang tidak bisa dibedakan
  // dari pesan error saja: IP salah, tablet & printer beda subnet, printer
  // belum join Wi-Fi, atau IPP-nya tertutup. Panel ini memisahkannya.

  Widget _buildNetworkDiagnosticSection() {
    final targetIp = _ipController.text.trim();
    final targetPrefix = targetIp.split('.').length == 4
        ? targetIp.split('.').take(3).join('.')
        : null;
    final sameSubnet = targetPrefix != null &&
        _localAddrs.any((a) => a.subnetPrefix == targetPrefix);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('NETWORK DIAGNOSTIC'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Diagnosa satu tekan ──
              //
              // Menjalankan seluruh pemeriksaan sekaligus dan merangkumnya jadi
              // satu teks siap salin, supaya operator tidak perlu menafsirkan
              // chip satu per satu.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    foregroundColor: Colors.black87,
                    padding: EdgeInsets.symmetric(vertical: 13.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  onPressed: _isDiagnosing ? null : _handleFullDiagnosis,
                  icon: _isDiagnosing
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black87,
                          ),
                        )
                      : const Icon(Icons.medical_services_rounded),
                  label: Text(
                    _isDiagnosing ? 'Mendiagnosa...' : 'DIAGNOSA OTOMATIS (satu tekan)',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12.5.sp),
                  ),
                ),
              ),

              if (_diagReport != null) ...[
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'HASIL DIAGNOSA',
                      style: GoogleFonts.montserrat(
                        color: AppColors.gold,
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _diagReport!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Hasil diagnosa disalin'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.copy_rounded, size: 13.r, color: AppColors.gold),
                      label: Text('Salin', style: TextStyle(color: AppColors.gold, fontSize: 10.sp)),
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxHeight: 260.h),
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.5)),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _diagReport!,
                      style: TextStyle(
                        color: Colors.lightBlueAccent,
                        fontFamily: 'monospace',
                        fontSize: 8.5.sp,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],

              SizedBox(height: 14.h),
              const Divider(color: Colors.white12),
              SizedBox(height: 10.h),

              // ── Routing Android ──
              //
              // Penyebab "tidak terjangkau" yang paling sering dan paling tidak
              // kelihatan: Wi-Fi tersambung tapi Android menandainya "tanpa
              // internet" lalu mengalihkan trafik aplikasi ke jaringan lain.
              // Socket ke IP printer gagal meski printer jelas sejaring.
              if (_netDiag != null) ...[
                Text(
                  'ROUTING ANDROID',
                  style: GoogleFonts.montserrat(
                    color: AppColors.gold,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 5.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    _buildProbeChip('Wi-Fi tersambung', _netDiag!['wifiPresent'] == true),
                    _buildProbeChip('Wi-Fi jadi jalur aktif', _netDiag!['wifiIsActive'] == true),
                    _buildProbeChip('Wi-Fi punya internet', _netDiag!['wifiValidated'] == true),
                  ],
                ),
                if ((_netDiag!['warning'] as String? ?? '').isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: Colors.amberAccent),
                    ),
                    child: Text(
                      _netDiag!['warning'] as String,
                      style: TextStyle(color: Colors.amberAccent, fontSize: 10.sp, height: 1.45),
                    ),
                  ),
                ],
                SizedBox(height: 6.h),
                _buildSwitchRow(
                  label: 'Ikat Proses ke Wi-Fi saat cetak',
                  value: _bindWifi,
                  onChanged: (val) async {
                    setState(() => _bindWifi = val);
                    await PrinterService.setBindWifi(val);
                  },
                ),
                if ((_netDiag!['rawSummary'] as String? ?? '').isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: 160.h),
                    padding: EdgeInsets.all(9.r),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _netDiag!['rawSummary'] as String,
                        style: TextStyle(
                          color: Colors.lightBlueAccent.withValues(alpha: 0.85),
                          fontFamily: 'monospace',
                          fontSize: 8.5.sp,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                const Divider(color: Colors.white12),
                SizedBox(height: 8.h),
              ],

              // ── Alamat tablet ──
              Text(
                'ALAMAT TABLET INI',
                style: GoogleFonts.montserrat(
                  color: AppColors.gold,
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 5.h),
              if (_localAddrs.isEmpty)
                Text(
                  'Tablet tidak punya alamat IPv4 aktif — Wi-Fi kemungkinan mati.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 10.sp),
                )
              else
                ..._localAddrs.map(
                  (a) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    child: Row(
                      children: [
                        Icon(
                          a.isWifiDirect ? Icons.wifi_tethering_rounded : Icons.wifi_rounded,
                          size: 13.r,
                          color: AppColors.gold,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          '${a.interfaceName}  ${a.ip}',
                          style: TextStyle(
                            color: AppColors.creamWhite,
                            fontSize: 10.sp,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (a.isWifiDirect) ...[
                          SizedBox(width: 6.w),
                          Text(
                            '(Wi-Fi Direct)',
                            style: TextStyle(color: Colors.amberAccent, fontSize: 9.sp),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              SizedBox(height: 8.h),

              // ── Peringatan subnet ──
              if (targetPrefix != null && _localAddrs.isNotEmpty && !sameSubnet)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    'BEDA SUBNET. Tablet ada di '
                    '${_localAddrs.map((a) => "${a.subnetPrefix}.x").join(", ")}, '
                    'sedangkan IP printer diisi $targetIp. Selama beda subnet, '
                    'printer tidak akan pernah terjangkau.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 10.sp, height: 1.4),
                  ),
                ),

              SizedBox(height: 10.h),

              // ── Tombol cek port ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  onPressed: _isCheckingPorts ? null : _handlePortCheck,
                  icon: _isCheckingPorts
                      ? SizedBox(
                          width: 14.r,
                          height: 14.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.gold,
                          ),
                        )
                      : Icon(Icons.lan_rounded, size: 16.r),
                  label: Text(
                    _isCheckingPorts ? 'Mengecek port...' : 'Cek Port di $targetIp',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11.5.sp),
                  ),
                ),
              ),

              if (_portCheck != null) ...[
                SizedBox(height: 8.h),
                ..._portCheck!.entries.map((e) {
                  final label = NetworkScan.knownPorts[e.key] ?? '';
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 1.h),
                    child: Row(
                      children: [
                        Icon(
                          e.value ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 12.r,
                          color: e.value ? Colors.greenAccent : Colors.white24,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          '${e.key}',
                          style: TextStyle(
                            color: e.value ? Colors.greenAccent : Colors.white38,
                            fontSize: 10.sp,
                            fontFamily: 'monospace',
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: e.value ? Colors.white70 : Colors.white24,
                              fontSize: 9.5.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (_portCheck!.values.every((v) => !v))
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Text(
                      'Tidak ada port terbuka — tidak ada perangkat apa pun di $targetIp. '
                      'IP-nya salah, atau printer belum tersambung ke Wi-Fi.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 9.5.sp, height: 1.4),
                    ),
                  ),
              ],

              SizedBox(height: 12.h),

              // ── Tombol pindai ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.darkBrown,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  onPressed: _isScanning ? null : _handleNetworkScan,
                  icon: _isScanning
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.darkBrown,
                          ),
                        )
                      : const Icon(Icons.radar_rounded),
                  label: Text(
                    _isScanning ? 'Memindai jaringan...' : 'Pindai Jaringan — Cari Printer',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12.5.sp),
                  ),
                ),
              ),

              if (_scanProgress.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text(
                  _scanProgress,
                  style: TextStyle(color: Colors.white54, fontSize: 9.5.sp),
                ),
              ],

              if (_foundPrinters.isNotEmpty) ...[
                SizedBox(height: 10.h),
                ..._foundPrinters.map(
                  (fp) => Container(
                    margin: EdgeInsets.only(bottom: 6.h),
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: fp.ippAnswered ? Colors.green : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fp.ip,
                                style: GoogleFonts.montserrat(
                                  color: AppColors.creamWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5.sp,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                '${fp.makeAndModel ?? "model tidak terbaca"} · port ${fp.openPorts.join(", ")}'
                                '${fp.ippAnswered ? " · IPP OK" : " · IPP tidak menjawab"}',
                                style: TextStyle(
                                  color: fp.ippAnswered ? Colors.greenAccent : Colors.white38,
                                  fontSize: 9.5.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.darkBrown,
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _useFoundPrinter(fp),
                          child: Text(
                            'Pakai',
                            style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── IPP DIRECT PRINT SECTION ──────────────────────────────────────────────
  //
  // Jalur cetak SILENT: kirim job IPP langsung ke printer lewat jaringan,
  // melewati Android PrintManager sepenuhnya. Tidak ada dialog print preview
  // dan tidak butuh Accessibility Service menekan tombol Print.

  Widget _buildIppDiagnosticSection() {
    final info = _ippInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SILENT PRINT — IPP DIRECT'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(9.r),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Epson L8050 TIDAK mendukung IPP — sudah dibuktikan lewat probe USB '
                  'dan Web Config printer. Biarkan sakelar ini MATI. Menyalakannya '
                  'hanya menambah jeda beberapa detik di setiap cetak.\n\n'
                  'Nyalakan hanya bila printer diganti dengan model ber-AirPrint '
                  '(mis. L8160, ET-8500) — seluruh jalur silent-nya sudah siap pakai.',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 9.5.sp, height: 1.45),
                ),
              ),
              SizedBox(height: 10.h),

              _buildSwitchRow(
                label: 'Aktifkan IPP Direct (Silent)',
                value: _ippEnabled,
                onChanged: (val) async {
                  setState(() => _ippEnabled = val);
                  await PrinterService.setIppEnabled(val);
                },
              ),
              const Divider(color: Colors.white12),

              _buildSwitchRow(
                label: 'Cari Printer Otomatis bila IP Gagal',
                value: _autoDiscover,
                onChanged: (val) async {
                  setState(() => _autoDiscover = val);
                  await PrinterService.setIppAutoDiscover(val);
                },
              ),
              const Divider(color: Colors.white12),

              _buildSwitchRow(
                label: 'Mode Silent Ketat (dialog cetak DILARANG muncul)',
                value: _strictSilent,
                onChanged: (val) async {
                  setState(() => _strictSilent = val);
                  await PrinterService.setStrictSilent(val);
                },
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Text(
                  _strictSilent
                      ? 'Dialog cetak Android tidak akan pernah dibuka. Bila IPP gagal, '
                          'kiosk menampilkan pesan gagal — bukan halaman print bawaan.'
                      : 'Bila IPP gagal, sistem jatuh ke dialog cetak Android yang ditekan '
                          'otomatis oleh Auto-Print Helper. Dialog akan terlihat sekilas.',
                  style: TextStyle(
                    color: _strictSilent ? Colors.greenAccent : Colors.white38,
                    fontSize: 9.sp,
                    height: 1.4,
                  ),
                ),
              ),
              const Divider(color: Colors.white12),

              _buildSettingRow(
                label: 'IPP Port',
                child: SizedBox(
                  width: 90.w,
                  height: 36.h,
                  child: TextField(
                    controller: _ippPortController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontSize: 12.sp),
                    decoration: InputDecoration(
                      hintText: '631',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 11.sp),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.r)),
                    ),
                    onChanged: (val) async {
                      final port = int.tryParse(val.trim());
                      if (port != null && port > 0) {
                        await PrinterService.setIppPort(port);
                      }
                    },
                  ),
                ),
              ),

              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.darkBrown,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  onPressed: _isIppProbing ? null : _handleIppProbe,
                  icon: _isIppProbing
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.darkBrown,
                          ),
                        )
                      : const Icon(Icons.wifi_find_rounded),
                  label: Text(
                    _isIppProbing ? 'Menghubungi printer...' : 'Cek Kemampuan IPP Printer',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12.5.sp),
                  ),
                ),
              ),

              if (info != null) ...[
                SizedBox(height: 14.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: (info.isPrintable ? Colors.green : Colors.red).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: info.isPrintable ? Colors.green : Colors.red),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.isPrintable
                            ? 'SILENT PRINT SIAP DIPAKAI'
                            : 'SILENT PRINT BELUM BISA',
                        style: GoogleFonts.montserrat(
                          color: info.isPrintable ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.sp,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        info.isPrintable
                            ? '${info.makeAndModel ?? "Printer"} menjawab di ${info.workingPath}. '
                                'Format dipakai: ${info.chosenFormat}.'
                            : (info.error ??
                                'Printer menjawab tapi belum siap menerima job '
                                    '(state: ${info.stateLabel ?? "-"}).'),
                        style: TextStyle(
                          color: AppColors.creamWhite,
                          fontSize: 10.sp,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    _buildProbeChip('Terjangkau', info.reachable),
                    _buildProbeChip('Menjawab IPP', info.workingPath != null),
                    _buildProbeChip('Menerima job', info.acceptingJobs),
                    _buildProbeChip('Format cocok', info.chosenFormat != null),
                  ],
                ),

                if (info.documentFormats.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Text(
                    'Format didukung printer:',
                    style: TextStyle(color: Colors.white54, fontSize: 9.5.sp),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    info.documentFormats.join(', '),
                    style: TextStyle(color: AppColors.creamWhite, fontSize: 9.5.sp, height: 1.4),
                  ),
                ],

                if (info.stateReasons.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    'Status printer: ${info.stateLabel} — ${info.stateReasons.join(", ")}',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 9.5.sp, height: 1.4),
                  ),
                ],

                if (info.rawDump.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'IPP ATTRIBUTE DUMP',
                        style: GoogleFonts.montserrat(
                          color: AppColors.gold,
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: info.rawDump));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Atribut IPP disalin ke clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.copy_rounded, size: 13.r, color: AppColors.gold),
                        label: Text('Salin', style: TextStyle(color: AppColors.gold, fontSize: 10.sp)),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: 220.h),
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        info.rawDump,
                        style: TextStyle(
                          color: Colors.greenAccent.withValues(alpha: 0.85),
                          fontFamily: 'monospace',
                          fontSize: 9.sp,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── AUTO-PRINT HELPER (JALUR FALLBACK USB) ────────────────────────────────
  //
  // Saat IPP tidak tersedia — misalnya printer hanya tersambung USB — cetak
  // jatuh ke Android Print Service, yang MEMBUKA dialog. Accessibility Service
  // inilah yang menekan tombolnya supaya operator tidak perlu menyentuh apa pun.
  //
  // Statusnya wajib terlihat: Android bisa mematikan Accessibility Service
  // setelah update atau reboot, dan bila itu terjadi cetak USB berhenti total
  // tanpa pesan apa pun di layar kiosk.

  Widget _buildAutoPrintHelperSection() {
    final s = _helperStatus;
    final enabled = s?['enabledInSettings'] == true;
    final running = s?['serviceRunning'] == true;
    final lastResult = s?['lastResult'] as String? ?? '-';
    final spooler = s?['lastSpoolerPackage'] as String? ?? '';
    final healthy = enabled && running;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('FALLBACK USB — AUTO-PRINT HELPER'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: healthy
                  ? AppColors.gold.withValues(alpha: 0.3)
                  : Colors.redAccent.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dipakai saat IPP tidak tersedia (mis. printer hanya via USB). '
                'Dialog cetak Android tetap muncul sekilas, tapi tombolnya ditekan '
                'otomatis — operator tidak perlu menyentuh layar.',
                style: TextStyle(color: Colors.white38, fontSize: 9.5.sp, height: 1.4),
              ),
              SizedBox(height: 10.h),

              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: [
                  _buildProbeChip('Aktif di Accessibility', enabled),
                  _buildProbeChip('Service berjalan', running),
                ],
              ),

              if (!healthy) ...[
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    'Helper MATI. Bila IPP juga gagal, kiosk tidak akan mencetak sama '
                    'sekali dan dialog cetak akan menggantung menunggu sentuhan orang. '
                    'Nyalakan di: Accessibility → SnapTechBooth Auto Print.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 10.sp, height: 1.4),
                  ),
                ),
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 11.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onPressed: () async {
                      await PrinterService.openAccessibilitySettings();
                    },
                    icon: Icon(Icons.settings_accessibility_rounded, size: 16.r),
                    label: Text(
                      'Buka Pengaturan Accessibility',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12.sp),
                    ),
                  ),
                ),
              ],

              SizedBox(height: 12.h),
              const Divider(color: Colors.white12),
              SizedBox(height: 8.h),

              // ── Penutup dialog ──
              //
              // Android tidak mengizinkan cetak tanpa membuka print spooler.
              // Yang bisa dilakukan adalah menutupinya dengan layar kiosk
              // sendiri, sehingga pelanggan tidak pernah melihat dialog itu.
              Text(
                'SEMBUNYIKAN DIALOG DARI PELANGGAN',
                style: GoogleFonts.montserrat(
                  color: AppColors.gold,
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 5.h),
              Text(
                'Menutupi dialog cetak dengan layar "Mencetak foto Anda..." milik kiosk. '
                'Dialognya tetap terbuka di baliknya dan tetap ditekan otomatis — '
                'pelanggan tidak melihat apa pun selain layar kiosk.',
                style: TextStyle(color: Colors.white38, fontSize: 9.5.sp, height: 1.4),
              ),
              SizedBox(height: 6.h),

              _buildSwitchRow(
                label: 'Tutupi Dialog Cetak',
                value: _coverDialog,
                onChanged: (val) async {
                  setState(() => _coverDialog = val);
                  await PrinterService.setCoverDialog(val);
                },
              ),

              SizedBox(height: 4.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: [
                  _buildProbeChip('Izin overlay diberikan', _canOverlay),
                ],
              ),

              if (_coverDialog && !_canOverlay) ...[
                SizedBox(height: 8.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: Colors.amberAccent),
                  ),
                  child: Text(
                    'Izin "Display over other apps" belum diberikan, jadi penutup '
                    'dilewati dan dialog cetak akan terlihat pelanggan. Cetaknya '
                    'tetap jalan.',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 10.sp, height: 1.4),
                  ),
                ),
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black87,
                      padding: EdgeInsets.symmetric(vertical: 11.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onPressed: () async {
                      await PrinterService.requestOverlayPermission();
                    },
                    icon: Icon(Icons.layers_rounded, size: 16.r),
                    label: Text(
                      'Beri Izin Tampil di Atas Aplikasi Lain',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11.5.sp),
                    ),
                  ),
                ),
              ],

              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: EdgeInsets.symmetric(vertical: 9.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  onPressed: () async {
                    await PrinterService.hidePrintCover();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Penutup dilepas paksa'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: Icon(Icons.layers_clear_rounded, size: 15.r),
                  label: Text(
                    'Darurat: Lepas Penutup yang Tersangkut',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11.sp),
                  ),
                ),
              ),

              SizedBox(height: 12.h),
              const Divider(color: Colors.white12),

              SizedBox(height: 10.h),
              Text(
                'Percobaan terakhir:',
                style: TextStyle(color: Colors.white54, fontSize: 9.5.sp),
              ),
              SizedBox(height: 3.h),
              Text(
                lastResult,
                style: TextStyle(
                  color: lastResult.startsWith('✅') ? Colors.greenAccent : AppColors.creamWhite,
                  fontSize: 10.sp,
                  height: 1.4,
                ),
              ),
              if (spooler.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(
                  'Package dialog cetak: $spooler',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9.sp,
                    fontFamily: 'monospace',
                  ),
                ),
              ],

              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  onPressed: () async {
                    final helper = await PrinterService.getAutoPrintHelperStatus();
                    if (mounted) setState(() => _helperStatus = helper);
                  },
                  icon: Icon(Icons.refresh_rounded, size: 16.r),
                  label: Text(
                    'Segarkan Status Helper',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11.5.sp),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── USB DIAGNOSTIC SECTION ────────────────────────────────────────────────
  //
  // Tahap 1: baca USB interface descriptor Epson L8050 untuk menentukan apakah
  // silent print (tanpa PrintActivity / tanpa Accessibility auto-tap) bisa
  // dipakai. Interface class 7 / subclass 1 / protocol 4 = IPP-over-USB.

  Color _pathColor(String path) {
    switch (path) {
      case 'IPP_USB':
        return Colors.greenAccent;
      case 'ESCPR_RAW':
        return Colors.amberAccent;
      default:
        return Colors.redAccent;
    }
  }

  String _pathLabel(String path) {
    switch (path) {
      case 'IPP_USB':
        return 'IPP-OVER-USB TERSEDIA';
      case 'ESCPR_RAW':
        return 'RAW PRINTER (ESC/P-R)';
      case 'NO_PRINTER_INTERFACE':
        return 'TANPA INTERFACE PRINTER';
      case 'NO_EPSON_DEVICE':
        return 'EPSON TIDAK TERDETEKSI';
      default:
        return 'ERROR';
    }
  }

  Widget _buildUsbDiagnosticSection() {
    final res = _probeResult;
    final path = res?['recommendedPath'] as String? ?? '';
    final rawSummary = res?['rawSummary'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('USB DIAGNOSTIC (SILENT PRINT PROBE)'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Membaca USB interface descriptor printer untuk menentukan apakah '
                'cetak otomatis tanpa dialog preview bisa dipakai. Tidak butuh izin USB '
                'dan tidak mengirim data apa pun ke printer.',
                style: TextStyle(color: Colors.white38, fontSize: 9.5.sp, height: 1.4),
              ),
              SizedBox(height: 12.h),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.darkBrown,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  onPressed: _isProbing ? null : _handleUsbProbe,
                  icon: _isProbing
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.darkBrown,
                          ),
                        )
                      : const Icon(Icons.travel_explore_rounded),
                  label: Text(
                    _isProbing ? 'Memindai USB...' : 'Jalankan Probe USB',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12.5.sp),
                  ),
                ),
              ),

              if (res != null) ...[
                SizedBox(height: 14.h),

                // ── Verdict badge ──
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: _pathColor(path).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: _pathColor(path)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pathLabel(path),
                        style: GoogleFonts.montserrat(
                          color: _pathColor(path),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.sp,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        res['verdict'] as String? ?? '',
                        style: TextStyle(
                          color: AppColors.creamWhite,
                          fontSize: 10.sp,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10.h),

                // ── Ringkasan flag ──
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    _buildProbeChip(
                      'Perangkat USB: ${res['totalUsbDevices'] ?? 0}',
                      (res['totalUsbDevices'] as int? ?? 0) > 0,
                    ),
                    _buildProbeChip('Epson terdeteksi', res['epsonPresent'] == true),
                    _buildProbeChip('IPP-over-USB (7/1/4)', res['ippUsbSupported'] == true),
                    _buildProbeChip('Raw printer (7/1/1-2)', res['rawPrinterSupported'] == true),
                  ],
                ),

                if (rawSummary.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DESCRIPTOR DUMP',
                        style: GoogleFonts.montserrat(
                          color: AppColors.gold,
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: rawSummary));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Descriptor disalin ke clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.copy_rounded, size: 13.r, color: AppColors.gold),
                        label: Text(
                          'Salin',
                          style: TextStyle(color: AppColors.gold, fontSize: 10.sp),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: 220.h),
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        rawSummary,
                        style: TextStyle(
                          color: Colors.greenAccent.withValues(alpha: 0.85),
                          fontFamily: 'monospace',
                          fontSize: 9.sp,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProbeChip(String label, bool active) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: (active ? Colors.green : Colors.red).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: active ? Colors.green : Colors.red),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 11.r,
            color: active ? Colors.greenAccent : Colors.redAccent,
          ),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.greenAccent : Colors.redAccent,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── WINDOWS: PILIH PRINTER & STATUS SESUNGGUHNYA ─────────────────────────

  Future<void> _loadWindowsPrinters() async {
    setState(() => _winLoading = true);
    final printers = await WindowsPrinterBackend.listPrinters();
    final saved = await WindowsPrinterBackend.getSelectedPrinterName();
    final resolved = await WindowsPrinterBackend.resolvePrinter();
    final status = await WindowsPrinterBackend.getStatus();
    if (!mounted) return;
    setState(() {
      _winPrinters = printers;
      _winSelectedName = saved ?? resolved?.name;
      _winStatus = status;
      _winLoading = false;
    });
  }

  /// Warna status: hijau bila masih layak menerima job, merah bila butuh
  /// tangan manusia sekarang juga.
  Color get _winStatusColor {
    if (_winStatus.isEmpty) return Colors.white38;
    return _winStatus['canPrint'] == true
        ? const Color(0xFF4CAF50)
        : const Color(0xFFE53935);
  }

  Widget _buildWindowsPrinterSection() {
    final code = _winStatus['status'] as String? ?? 'unknown';
    final message = _winStatus['message'] as String? ?? 'Belum diperiksa.';
    final detailAvailable = _winStatus['detailStatusAvailable'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('PRINTER WINDOWS'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status sesungguhnya ──
              Row(
                children: [
                  Container(
                    width: 10.r,
                    height: 10.r,
                    decoration: BoxDecoration(
                      color: _winStatusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(
                            color: _winStatusColor,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(message,
                            style: TextStyle(
                                color: Colors.white70, fontSize: 10.sp)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _winLoading ? null : _loadWindowsPrinters,
                    icon: Icon(Icons.refresh,
                        color: AppColors.gold, size: 18.r),
                    tooltip: 'Periksa ulang',
                  ),
                ],
              ),
              if (!detailAvailable && _winStatus.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    'Status rinci tidak terbaca dari WMI — yang dilaporkan '
                    'hanya keberadaan printer di spooler.',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 9.sp),
                  ),
                ),
              const Divider(color: Colors.white12),

              // ── Pilih printer ──
              Text('Printer yang dipakai',
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
              SizedBox(height: 6.h),
              if (_winPrinters.isEmpty)
                Text(
                  _winLoading
                      ? 'Memuat daftar printer...'
                      : 'Tidak ada printer terdaftar di Windows. '
                          'Pastikan driver Epson L8050 sudah terpasang.',
                  style: TextStyle(color: Colors.white38, fontSize: 10.sp),
                )
              else
                DropdownButton<String>(
                  value: _winSelectedName,
                  isExpanded: true,
                  dropdownColor: AppColors.darkBrown,
                  style: TextStyle(
                      color: AppColors.creamWhite, fontSize: 12.sp),
                  items: _winPrinters
                      .map((p) => DropdownMenuItem(
                            value: p.name,
                            child: Text(
                              p.isDefault ? '${p.name}  (default)' : p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (name) async {
                    if (name == null) return;
                    await WindowsPrinterBackend.setSelectedPrinterName(name);
                    await _loadWindowsPrinters();
                  },
                ),

              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Ukuran kertas & borderless diatur di DRIVER, bukan di sini.\n'
                  'Printer Properties > Advanced > Printing Defaults — bukan '
                  '"Printing Preferences" dari klik kanan printer, karena yang '
                  'itu tidak terbaca aplikasi.',
                  style: TextStyle(color: Colors.white70, fontSize: 9.5.sp),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        color: AppColors.gold,
        fontSize: 11.sp,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingRow({required String label, required Widget child}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchRow({required String label, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
          Switch(
            value: value,
            activeThumbColor: AppColors.gold,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
