import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fakultas_kopi_photobooth/shared/widgets/hidden_exit_gesture.dart';

void main() {
  testWidgets('triggers only after five taps inside the time window',
      (tester) async {
    var triggered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HiddenExitGesture(
          onTriggered: () => triggered++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byType(HiddenExitGesture));
    }
    expect(triggered, 0);

    await tester.tap(find.byType(HiddenExitGesture));
    expect(triggered, 1);
  });

  testWidgets('resets tap count after three seconds', (tester) async {
    var triggered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HiddenExitGesture(
          onTriggered: () => triggered++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byType(HiddenExitGesture));
    }
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byType(HiddenExitGesture));

    expect(triggered, 0);
  });

  testWidgets('does nothing while disabled', (tester) async {
    var triggered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HiddenExitGesture(
          enabled: false,
          onTriggered: () => triggered++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(HiddenExitGesture));
    }

    expect(triggered, 0);
  });
}
