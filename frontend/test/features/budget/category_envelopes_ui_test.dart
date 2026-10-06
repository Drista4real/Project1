import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/budget/screens/category_envelopes_screen.dart';
import '../../helpers/envelope_memory_repository.dart';
import '../../helpers/envelope_fixture.dart';
import '../../helpers/ui_preview.dart';

const _capture = bool.fromEnvironment('CAPTURE_UI');
final _boundary = GlobalKey();

Future<void> open(
  WidgetTester tester,
  EnvelopeMemoryRepository repo, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.kakeiboTheme,
        home: CategoryEnvelopesScreen(
          repository: repo,
          month: DateTime(2026, 10),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (_capture) {
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/envelope_zen_header.jpg'),
        _boundary.currentContext!,
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> capture(WidgetTester tester, String name) =>
    captureUi(tester, _boundary, name);

void main() {
  setUpAll(loadEnvelopeFonts);

  testWidgets(
    'groups actual categories, filters search and switches monthly limits',
    (tester) async {
      await open(tester, fixture(), size: const Size(390, 1850));
      expect(find.text('Nhu cầu thiết yếu'), findsOneWidget);
      expect(find.text('Mong muốn & sở thích'), findsOneWidget);
      expect(find.text('Nuôi dưỡng tâm hồn'), findsOneWidget);
      expect(find.text('Dự phòng & bất ngờ'), findsOneWidget);
      expect(find.text('2 mục'), findsNWidgets(4));
      await capture(tester, 'category-envelopes-full');
      await tester.enterText(
        find.byKey(const ValueKey('category-search')),
        'Cà phê',
      );
      await tester.pumpAndSettle();
      expect(find.text('Cà phê & gặp gỡ bạn bè'), findsOneWidget);
      expect(find.text('Ăn uống gia đình'), findsNothing);
      await tester.tap(find.byTooltip('Xóa tìm kiếm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tháng sau'));
      await tester.pumpAndSettle();
      expect(find.text('Phong bao tháng 11/2026'), findsOneWidget);
      expect(find.text('Chưa đặt hạn mức tháng'), findsNWidgets(8));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'creates category with selected pillar and formatted monthly limit',
    (tester) async {
      final repo = fixture();
      await open(tester, repo);
      await capture(tester, 'category-envelopes-mobile');
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm danh mục mới'));
      await tester.pumpAndSettle();
      await capture(tester, 'category-envelope-create');
      await tester.tap(find.text('Lưu danh mục'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập tên danh mục.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('envelope-name')),
        'Trà chiều',
      );
      await tester.tap(find.byKey(const ValueKey('select-wants')));
      await tester.enterText(
        find.byKey(const ValueKey('envelope-limit')),
        '1000000',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('envelope-limit')))
            .controller!
            .text,
        '1.000.000',
      );
      await tester.tap(find.text('Lưu danh mục'));
      await tester.pumpAndSettle();
      final category = repo.tables['categories']!.last;
      expect(category['name'], 'Trà chiều');
      expect(category['pillar'], 'wants');
      expect(repo.tables['budgets']!.last['category_id'], category['id']);
      expect(repo.tables['budgets']!.last['limit_amount'], '1000000');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('system category permits budget editing, cancel does not write', (
    tester,
  ) async {
    final repo = fixture();
    await open(tester, repo, size: const Size(390, 1100));
    await tester.tap(find.byTooltip('Chỉnh sửa Ăn uống gia đình'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('envelope-name')))
          .enabled,
      isFalse,
    );
    await tester.enterText(
      find.byKey(const ValueKey('envelope-limit')),
      '5000000',
    );
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(repo.tables['budgets']!.first['limit_amount'], '4500000');
    await tester.tap(find.byTooltip('Chỉnh sửa Ăn uống gia đình'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('envelope-limit')),
      '5000000',
    );
    await tester.tap(find.text('Lưu hạn mức'));
    await tester.pumpAndSettle();
    expect(repo.tables['budgets']!.first['limit_amount'], '5000000');
    expect(repo.tables['categories']!.first['name'], 'Ăn uống gia đình');
  });

  testWidgets('rebalance validates 100 percent and persists real budgets', (
    tester,
  ) async {
    final repo = fixture();
    await open(tester, repo);
    await tester.tap(find.text('Tái cân bằng %'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rebalance-total')),
      '20000000',
    );
    await tester.enterText(find.byKey(const ValueKey('percent-needs')), '60');
    await tester.tap(find.text('Lưu phân bổ'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng phân bổ phải bằng 100%.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('percent-wants')), '15');
    await tester.tap(find.text('Lưu phân bổ'));
    await tester.pumpAndSettle();
    expect(
      repo.tables['budgets']!
          .where((r) => r['pillar'] == 'needs')
          .single['limit_amount'],
      '12000000.00',
    );
    expect(
      repo.tables['budgets']!
          .where((r) => r['pillar'] == null && r['category_id'] == null)
          .single['limit_amount'],
      '20000000',
    );
  });

  testWidgets('form actions remain visible at 320px with keyboard', (
    tester,
  ) async {
    await open(tester, fixture(), size: const Size(320, 640));
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm danh mục mới'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('envelope-name')), 'Gym');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.widgetWithText(FilledButton, 'Lưu danh mục')).bottom,
      lessThanOrEqualTo(380),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disabling envelope requires confirmation and preserves category',
    (tester) async {
      final repo = fixture();
      await open(tester, repo, size: const Size(390, 1100));
      await tester.tap(find.byTooltip('Thao tác với Ăn uống gia đình'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa danh mục'), findsNothing);
      await tester.tap(find.text('Tắt phong bao tháng này'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repo.tables['budgets']!.any((b) => b['category_id'] == 1), isTrue);
      await tester.tap(find.byTooltip('Thao tác với Ăn uống gia đình'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tắt phong bao tháng này'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Tắt phong bao'));
      await tester.pumpAndSettle();
      expect(
        repo.tables['budgets']!.any((b) => b['category_id'] == 1),
        isFalse,
      );
      expect(repo.tables['categories']!.any((c) => c['id'] == 1), isTrue);
    },
  );
  for (final width in [320.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('layout and editor fit a ${width.toInt()}px viewport', (
      tester,
    ) async {
      await open(tester, fixture(), size: Size(width, 900));
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm danh mục mới'));
      await tester.pumpAndSettle();
      expect(find.text('Tạo danh mục mới'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed creation stays in form and retry creates one category', (
    tester,
  ) async {
    final repo = fixture()..failBudgetSave = true;
    await open(tester, repo);
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm danh mục mới'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('envelope-name')), 'Gym');
    await tester.enterText(
      find.byKey(const ValueKey('envelope-limit')),
      '100000',
    );
    await tester.tap(find.text('Lưu danh mục'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không thể lưu.'), findsOneWidget);
    expect(repo.tables['categories']!.length, 8);
    repo.failBudgetSave = false;
    await tester.tap(find.text('Lưu danh mục'));
    await tester.pumpAndSettle();
    expect(
      repo.tables['categories']!.where((c) => c['name'] == 'Gym'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'deletes only owned category after envelope is disabled and confirmation',
    (tester) async {
      final repo = fixture();
      repo.tables['budgets']!.removeWhere((b) => b['category_id'] == 2);
      await open(tester, repo, size: const Size(390, 1100));
      await tester.tap(find.byTooltip('Thao tác với Thuê nhà & dịch vụ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa danh mục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repo.tables['categories']!.any((c) => c['id'] == 2), isTrue);
      await tester.tap(find.byTooltip('Thao tác với Thuê nhà & dịch vụ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa danh mục'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa danh mục'));
      await tester.pumpAndSettle();
      expect(repo.tables['categories']!.any((c) => c['id'] == 2), isFalse);
      expect(repo.tables['categories']!.any((c) => c['id'] == 1), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('load failure can be retried without leaving screen', (
    tester,
  ) async {
    final repo = fixture()..failLoad = true;
    await open(tester, repo);
    expect(find.textContaining('Không thể tải dữ liệu'), findsOneWidget);
    repo.failLoad = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Nhu cầu thiết yếu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'advanced budget management remains reachable for all budget records',
    (tester) async {
      await open(tester, fixture(), size: const Size(390, 1850));
      await tester.ensureVisible(find.byTooltip('Quản lý nâng cao'));
      await tester.tap(find.byTooltip('Quản lý nâng cao'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hạn mức tổng & tùy chọn ngân sách'));
      await tester.pumpAndSettle();
      expect(find.text('Ngân sách'), findsWidgets);
      expect(find.byType(PopupMenuButton<String>), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('swipe removes monthly limit while keeping the category tile', (
    tester,
  ) async {
    final repo = fixture();
    await open(tester, repo, size: const Size(390, 1100));
    await tester.drag(
      find.byKey(const ValueKey('envelope-1')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tắt phong bao tháng này?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Tắt phong bao'));
    await tester.pumpAndSettle();
    expect(find.text('Ăn uống gia đình'), findsOneWidget);
    expect(repo.tables['budgets']!.any((b) => b['category_id'] == 1), isFalse);
    expect(tester.takeException(), isNull);
  });
}
