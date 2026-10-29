import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/management/screens/management_screen.dart';
import '../../helpers/memory_management_repository.dart';

void main() {
  testWidgets(
    'hub searches task descriptions and separates read-only history',
    (tester) async {
      final repository = MemoryManagementRepository();
      repository.catalog.addAll([
        {'name': 'accounts', 'title': 'Ví và tài khoản'},
        {'name': 'recurring_transactions', 'title': 'Giao dịch định kỳ'},
        {'name': 'cashflow_forecasts', 'title': 'Dự báo dòng tiền'},
      ]);
      await tester.pumpWidget(
        MaterialApp(home: ManagementScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thêm ví'), findsOneWidget);
      expect(find.text('Dự báo dòng tiền'), findsNothing);
      await tester.enterText(find.byType(TextField), 'tien nha');
      await tester.pumpAndSettle();
      expect(find.text('Giao dịch định kỳ'), findsOneWidget);
      expect(find.text('Ví và tài khoản'), findsNothing);
      await tester.enterText(find.byType(TextField), 'dự báo');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dự báo dòng tiền'));
      expect(find.text('Dữ liệu đã lưu · Chỉ xem'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'không có mục này');
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy mục phù hợp.'), findsOneWidget);
      await tester.tap(find.text('Xem tất cả mục'));
      await tester.pumpAndSettle();
      expect(find.text('Ví và tài khoản'), findsOneWidget);
    },
  );
}
