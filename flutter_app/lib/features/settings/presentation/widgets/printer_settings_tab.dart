import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/printer_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Tab Printer Settings khusus Operator Kiosk — Murni mengontrol koneksi Direct USB + Wi-Fi Fallback
class PrinterSettingsTab extends StatefulWidget {
  const PrinterSettingsTab({super.key});

  @override
  State<PrinterSettingsTab> createState() => _PrinterSettingsTabState();
}

class _PrinterSettingsTabState extends State<PrinterSettingsTab> {
  final _ipController = TextEditingController();

  PrinterConnectionMode _connectionMode = PrinterConnectionMode.usbWifiAuto;
  Map<String, dynamic> _statusData = {};
  bool _isLoadingStatus = true;

  bool _borderless = true;
  bool _autoPrint = true;
  bool _autoReconnect = true;
  int _retryCount = 3;

  bool _isTestingPrint = false;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSettings() async {
    setState(() => _isLoadingStatus = true);

    final mode = await PrinterService.getConnectionMode();
    final ip = await PrinterService.getIpAddress();
    final borderless = await PrinterService.getBorderless();
    final autoPrint = await PrinterService.getAutoPrint();
    final autoReconnect = await PrinterService.getAutoReconnect();
    final retries = await PrinterService.getRetryCount();

    final status = await PrinterService.getPrinterStatus();

    if (mounted) {
      setState(() {
        _connectionMode = mode;
        _ipController.text = ip;
        _borderless = borderless;
        _autoPrint = autoPrint;
        _autoReconnect = autoReconnect;
        _retryCount = retries;
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
                  Container(
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
                child: Text('High Quality (300 DPI)', style: GoogleFonts.montserrat(color: AppColors.creamWhite, fontSize: 12.sp)),
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

        // ── SECTION 3: RELIABILITY & RETRY ─────────────────────────────────
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
            activeColor: AppColors.gold,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
