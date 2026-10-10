import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/shared/widgets/finance_data_view.dart';

void main() {
  testWidgets(
    'rebuilds keep loaded data and refresh uses the attached controller',
    (tester) async {
      var calls = 0;
      Future<int> load() async => ++calls;
      final first = FinanceDataController();
      final second = FinanceDataController();
      Widget page(FinanceDataController controller) => MaterialApp(
        home: FinanceDataView<int>(
          load: load,
          controller: controller,
          builder: (_, data, _) => ListView(children: [Text('value: $data')]),
        ),
      );
      await tester.pumpWidget(page(first));
      await tester.pumpAndSettle();
      expect(find.text('value: 1'), findsOneWidget);
      await tester.pumpWidget(page(second));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await first.refresh();
      expect(calls, 1);
      await second.refresh();
      await tester.pumpAndSettle();
      expect(find.text('value: 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await second.refresh();
      expect(calls, 2);
    },
  );

  testWidgets('unmounting while loading does not update disposed widgets', (
    tester,
  ) async {
    final request = Completer<int>();
    await tester.pumpWidget(
      MaterialApp(
        home: FinanceDataView<int>(
          load: () => request.future,
          builder: (_, data, _) => Text('$data'),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    request.complete(1);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
