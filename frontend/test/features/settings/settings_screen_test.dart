import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/settings/screens/settings_screen.dart';
import '../../helpers/settings_repository.dart';
import '../../helpers/supabase_test_setup.dart';

void main() {
  configureTestSupabase();
  group('SettingsScreen UI', () {
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
