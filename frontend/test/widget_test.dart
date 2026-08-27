import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukaseafood/main.dart';

void main() {
  testWidgets('home boots with SukaSeafood brand', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SukaSeafoodApp());
    await tester.pump();

    expect(find.textContaining('SukaSeafood'), findsWidgets);
    expect(
      find.textContaining('Amir', findRichText: true),
      findsWidgets,
    );
  });
}
