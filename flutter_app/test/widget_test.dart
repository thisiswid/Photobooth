import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fakultas_kopi_photobooth/main.dart';

void main() {
  testWidgets('App launches and shows Welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FakultasKopiApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('FAKULTAS KOPI'), findsAtLeast(1));
  });
}
