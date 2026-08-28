import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukaseafood/core/auth/auth_controller.dart';
import 'package:sukaseafood/data/models/user_profile.dart';
import 'package:sukaseafood/main.dart';

void main() {
  testWidgets('home boots with SukaSeafood brand', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AuthController auth = AuthController.forTesting(
      profile: const UserProfile(
        uid: 'test',
        name: 'Amir',
        email: 'amir@example.com',
      ),
    );

    await tester.pumpWidget(SukaSeafoodApp(authController: auth));
    await tester.pump();

    expect(find.textContaining('SukaSeafood'), findsWidgets);
    expect(
      find.textContaining('Amir', findRichText: true),
      findsWidgets,
    );
  });
}
