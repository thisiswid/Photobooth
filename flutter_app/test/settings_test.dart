import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fakultas_kopi_photobooth/features/settings/presentation/device_settings_screen.dart';

void main() {
  testWidgets('DeviceSettingsScreen builds without crash', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ScreenUtilInit(
          designSize: Size(1920, 1080),
          child: MaterialApp(
            home: DeviceSettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DeviceSettingsScreen), findsOneWidget);
  });
}
