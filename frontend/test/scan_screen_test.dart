import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukaseafood/core/theme/app_theme.dart';
import 'package:sukaseafood/features/scan/scan_screen.dart';

void main() {
  testWidgets('scan screen shows the identify chrome from the render', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const ScanScreen()),
    );
    await tester.pump();

    expect(find.text('Identify seafood'), findsOneWidget);
    expect(find.textContaining('Snap'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Take a photo now'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Choose from your photos'), findsOneWidget);
    expect(find.text('Scanner coverage'), findsOneWidget);
    expect(find.text('Quick tip'), findsOneWidget);
    expect(find.text('Point at the fish on the counter'), findsOneWidget);
    expect(find.textContaining('identifies 19 species'), findsOneWidget);
  });

  testWidgets('coverage dialog lists the 19 trained species', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const ScanScreen()),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Scanner coverage'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Alaskan Pollock'), findsOneWidget);
    expect(find.textContaining('Tilapia'), findsWidgets);
    expect(find.textContaining('identifies these 19 species'), findsOneWidget);
  });
}
