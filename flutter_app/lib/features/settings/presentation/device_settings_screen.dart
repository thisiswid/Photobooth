import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/provisioning/providers/tenant_provider.dart';
import 'widgets/printer_settings_tab.dart';

/// Halaman Hidden Device Settings khusus Operator (Akses via Hidden Gesture Logo 5x di Welcome Screen)
class DeviceSettingsScreen extends ConsumerStatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  ConsumerState<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends ConsumerState<DeviceSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBrown,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.gold),
          onPressed: () => context.go(AppRoutes.welcome),
        ),
        title: Text(
          'HIDDEN DEVICE SETTINGS',
          style: GoogleFonts.cormorantGaramond(
            color: AppColors.creamWhite,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.creamWhite),
            onPressed: () => context.go(AppRoutes.welcome),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          indicatorWeight: 3,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.creamWhite.withValues(alpha: 0.6),
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13.sp),
          tabs: const [
            Tab(icon: Icon(Icons.print_rounded), text: 'Printer'),
            Tab(icon: Icon(Icons.camera_alt_rounded), text: 'Camera'),
            Tab(icon: Icon(Icons.settings_suggest_rounded), text: 'System'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PrinterSettingsTab(),
          _CameraSettingsTab(),
          _SystemSettingsTab(),
        ],
      ),
    );
  }
}

class _CameraSettingsTab extends StatefulWidget {
  const _CameraSettingsTab();

  @override
  State<_CameraSettingsTab> createState() => _CameraSettingsTabState();
}

class _CameraSettingsTabState extends State<_CameraSettingsTab> {
  bool _isLoading = true;
  List<dynamic> _cameras = [];

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    setState(() => _isLoading = true);
    final cameras = await CameraService.getAvailableCamerasList();
    if (mounted) {
      setState(() {
        _cameras = cameras;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        Text(
          'KAMERA KIOSK',
          style: GoogleFonts.montserrat(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp),
        ),
        SizedBox(height: 10.h),
        ..._cameras.map((cam) => Card(
              color: Colors.black.withValues(alpha: 0.3),
              child: ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.gold),
                title: Text(cam.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text('Arah Lens: ${cam.lensDirection.name}', style: const TextStyle(color: Colors.white54)),
              ),
            )),
      ],
    );
  }
}

class _SystemSettingsTab extends ConsumerWidget {
  const _SystemSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantConfig = ref.watch(tenantNotifierProvider).valueOrNull;
    final cafeName = tenantConfig?.cafe.name ?? AppConstants.defaultCafeBrandName;
    final cafeCode = tenantConfig?.cafe.code ?? '-';
    final baseUrl = DioClient.instance.baseUrl;

    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        Text(
          'INFORMASI SISTEM TENANT',
          style: GoogleFonts.montserrat(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp),
        ),
        SizedBox(height: 10.h),
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tenant Cafe: $cafeName ($cafeCode)', style: const TextStyle(color: Colors.white)),
              SizedBox(height: 6.h),
              Text('API Base URL: $baseUrl', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
              SizedBox(height: 6.h),
              Text('Versi Aplikasi: SnapTechBooth v${AppConstants.appVersion}', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
            ],
          ),
        ),
      ],
    );
  }
}
