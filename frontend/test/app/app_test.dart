import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/app/kakeibo_app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KakeiboZenApp());
    expect(find.byType(KakeiboZenApp), findsOneWidget);
  });
}
