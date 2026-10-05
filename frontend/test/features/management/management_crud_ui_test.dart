import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/management/open_finance_module.dart';
import 'package:project_one/shared/widgets/finance_form.dart';

import '../../helpers/memory_management_repository.dart';

Future<void> openModule(
  WidgetTester tester,
  MemoryManagementRepository repository,
  String resource, {
  bool create = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.kakeiboTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => openFinanceModule(
              context,
              resource,
              create: create,
              repository: repository,
            ),
            child: const Text('Mở'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'budget validates every section and saves selected month as first day',
    (tester) async {
      final repository = MemoryManagementRepository();
      await openModule(tester, repository, 'budgets', create: true);
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm ngân sách'));
      await tester.pumpAndSettle();
      expect(repository.saved, isNull);
      expect(find.text('Vui lòng nhập Hạn mức *'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('limit_amount')),
        '1500000,50',
      );
      final month = find.widgetWithText(TextFormField, 'Tháng ngân sách *');
      await tester.ensureVisible(month);
      await tester.tap(month);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tháng 2'));
      await tester.tap(find.text('Chọn tháng'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm ngân sách'));
      await tester.pumpAndSettle();
      expect(repository.saved?['month_year'], endsWith('-02-01'));
      expect(repository.saved?['limit_amount'], '1500000.50');
      expect(repository.saved?['category_id'], isNull);
      expect(repository.saved?['pillar'], isNull);
    },
  );

  testWidgets('row menu edits existing record and confirms before deletion', (
    tester,
  ) async {
    final repository = MemoryManagementRepository();
    await openModule(tester, repository, 'tags');
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉnh sửa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('name')), 'Du lịch hè');
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(repository.saved?['name'], 'Du lịch hè');
    expect(repository.savedKey, '1');
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isFalse);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isFalse);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isTrue);
    expect(find.text('Bắt đầu từ mục đầu tiên'), findsOneWidget);
  });

  testWidgets('system category has viewing controls only', (tester) async {
    final repository = MemoryManagementRepository();
    await openModule(tester, repository, 'categories');
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.text('Du lịch'));
    await tester.pumpAndSettle();
    expect(find.byType(FinanceSaveBar), findsNothing);
    expect(
      tester.widget<TextFormField>(find.byKey(const ValueKey('name'))).enabled,
      isFalse,
    );
  });

  testWidgets('save stays accessible on a small screen with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final repository = MemoryManagementRepository();
    await openModule(tester, repository, 'tags', create: true);
    await tester.enterText(find.byKey(const ValueKey('name')), 'Mua sắm');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.widgetWithText(FilledButton, 'Thêm thẻ')).bottom,
      lessThanOrEqualTo(380),
    );
    await tester.tap(find.text('Thêm thẻ'));
    await tester.pumpAndSettle();
    expect(repository.saved?['name'], 'Mua sắm');
    expect(repository.saved?['color'], '#64748B');
  });
}
