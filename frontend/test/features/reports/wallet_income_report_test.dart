import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/features/reports/screens/reports_screen.dart';
import '../../helpers/envelope_memory_repository.dart';

void main() {
  testWidgets('report refresh includes wallet income with no category', (
    tester,
  ) async {
    final repo = EnvelopeMemoryRepository();
    await tester.pumpWidget(
      MaterialApp(home: ReportsScreen(insights: FinanceInsights(repo))),
    );
    await tester.pumpAndSettle();
    expect(find.text('10.000.000 ₫'), findsNothing);
    repo.tables['transactions']!.add({
      'id': 1,
      'amount': '10000000',
      'transaction_type': 'income',
      'category_id': null,
      'transaction_date': DateTime.now().toUtc().toIso8601String(),
    });
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(find.text('10.000.000 ₫'), findsNWidgets(2));
    expect(find.text('Thu nhập'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
