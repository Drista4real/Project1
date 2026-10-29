import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/ai/data/ai_input_repository.dart';
import 'package:project_one/features/ai/models/transaction_draft.dart';
import 'package:project_one/features/ai/screens/ai_quick_input_screen.dart';
import 'package:project_one/features/ai/services/input_preferences.dart';
import 'package:project_one/features/ai/services/voice_input.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import '../../helpers/envelope_memory_repository.dart';
import '../../helpers/fake_finance_repository.dart';
import '../../helpers/ui_preview.dart';

final _previewBoundary = GlobalKey();

class FakeInput implements AiInputRepository {
  String? received;
  @override
  Future<List<TransactionDraft>> analyze(String text) async {
    received = text;
    return [
      const TransactionDraft(
        text: 'Bún bò 65k tiền mặt',
        normalizedText: 'bún bò 65000 đồng tiền mặt',
        amount: 65000,
        type: 'expense',
        category: 'Ăn uống',
        confidence: 0.92,
        source: 'LOCAL',
      ),
      const TransactionDraft(
        text: 'Trà sữa 35k tiền mặt',
        normalizedText: 'trà sữa 35000 đồng tiền mặt',
        amount: 35000,
        type: 'expense',
        category: 'Ăn uống',
        confidence: 0.84,
        source: 'LOCAL',
      ),
    ];
  }
}

class MemoryPreferences implements InputPreferences {
  final categories = <String, int>{};
  @override
  Future<int?> category(String text) async => categories[text];
  @override
  Future<void> remember(String text, int categoryId) async =>
      categories[text] = categoryId;
}

class FakeVoice implements VoiceInput {
  bool started = false, cancelled = false, disposed = false;
  Completer<void>? permission;
  @override
  bool get supported => true;
  @override
  Future<void> start() async {
    await permission?.future;
    started = true;
  }

  @override
  Future<String> stop() async => 'ăn trưa sáu mươi lăm nghìn';
  @override
  Future<void> cancel() async => cancelled = true;
  @override
  Future<void> dispose() async => disposed = true;
}

class SavingRepository extends FakeFinanceRepository {
  final saved = <Map<String, Object?>>[];
  bool failSecond = false;
  Completer<void>? pending;
  @override
  Future<void> addTransaction({
    required double amount,
    required String transactionType,
    required String description,
    int? categoryId,
    String? categoryName,
    int? accountId,
    DateTime? transactionDate,
  }) async {
    if (pending != null) await pending!.future;
    if (failSecond && saved.isNotEmpty) throw StateError('offline');
    saved.add({
      'amount': amount,
      'account_id': accountId,
      'category_id': categoryId,
      'type': transactionType,
      'description': description,
    });
  }
}

Future<void> open(
  WidgetTester tester,
  SavingRepository finance, {
  FakeInput? api,
  FakeVoice? voice,
}) async {
  final management = EnvelopeMemoryRepository();
  final now = DateTime.now();
  management.tables['categories'] = [
    {'id': 1, 'name': 'Ăn uống', 'pillar': 'needs'},
  ];
  management.tables['budgets'] = [
    {
      'id': 1,
      'category_id': null,
      'pillar': null,
      'month_year': '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
      'limit_amount': '450000',
    },
  ];
  await tester.pumpWidget(
    RepaintBoundary(
      key: _previewBoundary,
      child: MaterialApp(
        theme: AppTheme.kakeiboTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiQuickInputScreen(
                    inputRepository: api ?? FakeInput(),
                    financeRepository: finance,
                    voiceInput: voice ?? FakeVoice(),
                    preferences: MemoryPreferences(),
                    insights: FinanceInsights(management),
                  ),
                ),
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
}

Future<void> analyze(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('aiInputText')),
    'bún bò 65k, trà sữa 35k',
  );
  await tester.tap(find.text('Phân tích'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('confirmAiTransactions')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const ValueKey('confirmAiTransactions')));
  await tester.pumpAndSettle();
}

void main() {
  if (captureUiEnabled) {
    testWidgets('reference preview', (tester) async {
      await loadEnvelopeFonts();
      tester.view.physicalSize = const Size(498, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, SavingRepository());
      await analyze(tester);
      await captureUi(tester, _previewBoundary, 'ai-quick-input');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'analysis has editable drafts and does not save until confirmation',
    (tester) async {
      final finance = SavingRepository();
      await open(tester, finance);
      await analyze(tester);
      expect(find.text('Đã tách 2 giao dịch'), findsOneWidget);
      expect(finance.saved, isEmpty);
      await save(tester);
      expect(finance.saved.map((row) => row['amount']), [65000, 35000]);
      expect(finance.saved.every((row) => row['account_id'] == 1), isTrue);
      expect(find.text('Mở'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('swiping away a draft excludes it from saving', (tester) async {
    final finance = SavingRepository();
    await open(tester, finance);
    await analyze(tester);
    final card = find.byKey(const ValueKey('draft-1'));
    await tester.scrollUntilVisible(
      card,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(card, const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Đã tách 1 giao dịch'),
      -150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Đã tách 1 giao dịch'), findsOneWidget);
    await save(tester);
    expect(finance.saved.single['amount'], 35000);
  });

  testWidgets('editing money changes the confirmed payload', (tester) async {
    final finance = SavingRepository();
    await open(tester, finance);
    await analyze(tester);
    await tester.scrollUntilVisible(
      find.byTooltip('Sửa giao dịch'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Sửa giao dịch').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('draftAmount')),
      '70.000,50',
    );
    await tester.ensureVisible(find.text('Áp dụng thay đổi'));
    await tester.tap(find.text('Áp dụng thay đổi'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(finance.saved.first['amount'], 70000.5);
  });

  testWidgets(
    'partial failure keeps unsaved drafts and prevents blind retries',
    (tester) async {
      final finance = SavingRepository()..failSecond = true;
      await open(tester, finance);
      await analyze(tester);
      await save(tester);
      expect(finance.saved, hasLength(1));
      await tester.scrollUntilVisible(
        find.textContaining('tránh lưu trùng'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('tránh lưu trùng'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('confirmAiTransactions')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('confirmAiTransactions')),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('voice populates editable text and never saves automatically', (
    tester,
  ) async {
    final finance = SavingRepository();
    final voice = FakeVoice();
    await open(tester, finance, voice: voice);
    await tester.tap(find.text('Nói nhanh'));
    await tester.pumpAndSettle();
    expect(voice.started, isTrue);
    await tester.tap(find.text('Dừng ghi âm'));
    await tester.pumpAndSettle();
    expect(find.text('ăn trưa sáu mươi lăm nghìn'), findsOneWidget);
    expect(finance.saved, isEmpty);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(voice.disposed, isTrue);
  });

  testWidgets(
    'microphone permission inactive event does not cancel recording',
    (tester) async {
      final voice = FakeVoice()..permission = Completer<void>();
      await open(tester, SavingRepository(), voice: voice);
      await tester.tap(find.text('Nói nhanh'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(voice.cancelled, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      voice.permission!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Dừng ghi âm'), findsOneWidget);
      await tester.tap(find.text('Dừng ghi âm'));
      await tester.pumpAndSettle();
      expect(find.text('ăn trưa sáu mươi lăm nghìn'), findsOneWidget);
    },
  );

  testWidgets('reference layout fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, SavingRepository());
    await analyze(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('confirmAiTransactions')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
