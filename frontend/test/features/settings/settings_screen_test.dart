import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/settings/screens/settings_screen.dart';
import 'package:project_one/features/settings/services/report_exporter.dart';
import 'package:project_one/core/theme/app_theme.dart';
import '../../helpers/settings_repository.dart';
import '../../helpers/supabase_test_setup.dart';

class ExportSettingsRepository extends SettingsRepository {
  @override
  Future<List<Map<String, dynamic>>> references(String resource) async {
    if (resource == 'transactions') {
      return List.generate(
        16,
        (i) => {
          'id': i + 1,
          'amount': '15000.50',
          'transaction_type': 'expense',
          'transaction_date': DateTime.now().toIso8601String(),
          'clean_description': i < 15 ? 'Cà phê $i' : 'Khác',
          'account_id': 1,
        },
      );
    }
    if (resource == 'transaction_tags') {
      return List.generate(15, (i) => {'transaction_id': i + 1, 'tag_id': 1});
    }
    if (resource == 'accounts') {
      return [
        {'id': 1, 'name': 'Tiền mặt'},
      ];
    }
    return super.references(resource);
  }
}

class RecordingExporter extends ReportExporter {
  List<Map<String, dynamic>>? items;
  String? filter;
  @override
  Future<bool> export(
    ReportFormat format,
    List<Map<String, dynamic>> items,
    String filter, {
    Rect? origin,
  }) async {
    this.items = items;
    this.filter = filter;
    return true;
  }
}

void main() {
  configureTestSupabase();
  group('SettingsScreen UI', () {
    testWidgets('dark settings fit a narrow phone through all utilities', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.kakeiboDarkTheme,
          home: SettingsScreen(repository: SettingsRepository()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Giao diện tối'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );
    });
    testWidgets(
      'export uses all matching rows, tags and query beyond the preview limit',
      (tester) async {
        final exporter = RecordingExporter();
        await tester.pumpWidget(
          MaterialApp(
            home: SettingsScreen(
              repository: ExportSettingsRepository(),
              exporter: exporter,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Cà phê');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('# dulich'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('# dulich'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Xuất báo cáo Excel / PDF'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Xuất báo cáo Excel / PDF'));
        await tester.pumpAndSettle();
        expect(
          find.text('Xuất 15 giao dịch theo bộ lọc hiện tại'),
          findsOneWidget,
        );
        await tester.tap(find.text('Excel (.xlsx)'));
        await tester.pumpAndSettle();
        expect(exporter.items, hasLength(15));
        expect(exporter.items!.last['id'], 15);
        expect(exporter.items!.first['accounts']['name'], 'Tiền mặt');
        expect(exporter.filter, contains('Cà phê'));
        expect(exporter.filter, contains('dulich'));
      },
    );
    testWidgets('shows search, transaction tags and date ranges', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(repository: SettingsRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('# dulich'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Tuần này'), findsOneWidget);
    });

    testWidgets('updates the selected transaction tag', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(repository: SettingsRepository())),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('# dulich'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      final tag = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, '# dulich'),
      );
      expect(tag.selected, isFalse);

      await tester.tap(find.widgetWithText(FilterChip, '# dulich'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '# dulich'))
            .selected,
        isTrue,
      );
    });
  });
}
