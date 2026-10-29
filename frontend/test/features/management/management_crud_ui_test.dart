import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/management/open_finance_module.dart';
import 'package:project_one/shared/widgets/finance_form.dart';
import 'package:project_one/features/management/config/management_metadata.dart';

import '../../helpers/memory_management_repository.dart';

class FailingDetailsRepository extends MemoryManagementRepository {
  bool fail = true;
  @override
  Future<Map<String, dynamic>> get(String resource, String key) async {
    if (fail) throw StateError('Không có kết nối');
    return super.get(resource, key);
  }
}

Future<void> openModule(
  WidgetTester tester,
  MemoryManagementRepository repository,
  String resource, {
  bool create = false,
  Map<String, dynamic>? record,
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
              record: record,
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
    'failed detail load leaves the list available and can be retried',
    (tester) async {
      final repository = FailingDetailsRepository();
      await openModule(tester, repository, 'tags');
      await tester.tap(find.text('Du lịch'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không thể mở chi tiết'), findsOneWidget);
      expect(find.byTooltip('Đóng chi tiết'), findsNothing);
      repository.fail = false;
      await tester.tap(find.text('Du lịch'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Đóng chi tiết'), findsOneWidget);
      expect(repository.saved, isNull);
    },
  );
  testWidgets(
    'leaving a changed form asks before discarding and keeps input when canceled',
    (tester) async {
      final repository = MemoryManagementRepository();
      await openModule(tester, repository, 'tags', create: true);
      expect(find.byKey(const ValueKey('color')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('name')),
        'Chuyến đi mùa hè',
      );
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục chỉnh sửa'));
      await tester.pumpAndSettle();
      expect(find.text('Chuyến đi mùa hè'), findsOneWidget);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ thay đổi'));
      await tester.pumpAndSettle();
      expect(find.text('Mở'), findsOneWidget);
      expect(repository.saved, isNull);
    },
  );

  testWidgets(
    'invalid advanced input is revealed and saved values survive collapse',
    (tester) async {
      final repository = MemoryManagementRepository();
      repository.records.first['color'] = '#wrong';
      await openModule(
        tester,
        repository,
        'tags',
        record: repository.records.first,
      );
      expect(find.byKey(const ValueKey('color')), findsNothing);
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('color')), findsOneWidget);
      expect(find.text('Giá trị không đúng định dạng'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('color')), '#D96B43');
      await tester.ensureVisible(find.text('Tùy chỉnh thêm'));
      await tester.tap(find.text('Tùy chỉnh thêm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('color')), findsNothing);
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(repository.saved?['color'], '#D96B43');
      expect(repository.saved?['name'], 'Du lịch');
    },
  );
  for (final name in generatedFinanceResources) {
    testWidgets('$name only permits viewing generated records', (tester) async {
      final repository = MemoryManagementRepository();
      repository.catalog.add({
        'name': name,
        'title': 'Dữ liệu hệ thống',
        'schema': {
          'properties': {
            'name': {'type': 'string'},
          },
        },
      });
      await openModule(tester, repository, name);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      await tester.tap(find.text('Du lịch'));
      await tester.pumpAndSettle();
      expect(find.byType(FinanceSaveBar), findsNothing);
      expect(find.text('Dữ liệu của hệ thống · Chỉ xem'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Chỉnh sửa'), findsNothing);
      expect(repository.saved, isNull);
      expect(repository.deleted, isFalse);
    });
  }
  testWidgets(
    'details do not edit data and deletion still requires confirmation',
    (tester) async {
      final repository = MemoryManagementRepository();
      await openModule(tester, repository, 'tags');
      await tester.tap(find.text('Du lịch'));
      await tester.pumpAndSettle();
      expect(find.text('Tên'), findsOneWidget);
      expect(repository.saved, isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa dữ liệu này?'), findsOneWidget);
      expect(repository.deleted, isFalse);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repository.deleted, isFalse);
      await tester.tap(find.text('Du lịch'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Chỉnh sửa'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('name')),
        'Chuyến đi hè',
      );
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(repository.saved?['name'], 'Chuyến đi hè');
    },
  );
  testWidgets('generated records cannot be opened in create mode', (
    tester,
  ) async {
    final repository = MemoryManagementRepository();
    await openModule(tester, repository, 'cashflow_forecasts', create: true);
    expect(
      find.text('Dữ liệu do hệ thống tạo, chỉ có thể xem.'),
      findsOneWidget,
    );
    expect(find.byType(FinanceSaveBar), findsNothing);
  });
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
    await openModule(
      tester,
      repository,
      'categories',
      record: repository.records.first,
    );
    expect(find.byType(PopupMenuButton<String>), findsNothing);
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
