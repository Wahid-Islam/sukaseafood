import 'package:flutter_test/flutter_test.dart';
import 'package:sukaseafood/main.dart';

void main() {
  testWidgets('home boots with SukaSeafood brand', (WidgetTester tester) async {
    await tester.pumpWidget(const SukaSeafoodApp());
    await tester.pump();
    expect(find.textContaining('SukaSeafood'), findsWidgets);
  });
}
