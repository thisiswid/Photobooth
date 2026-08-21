import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fakultas_kopi_photobooth/main.dart';

void main() {
  testWidgets('App launches and builds widget tree', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SnapTechBoothApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
