import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/ai/data/ai_input_repository.dart';
import 'package:project_one/features/ai/models/transaction_draft.dart';
import 'package:project_one/features/ai/screens/ai_quick_input_screen.dart';
import 'package:project_one/features/ai/services/input_preferences.dart';
import 'package:project_one/features/ai/services/voice_input.dart';
import 'package:project_one/features/ai/services/receipt_input.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import '../../helpers/envelope_memory_repository.dart';
import '../../helpers/fake_finance_repository.dart';
import '../../helpers/ui_preview.dart';

final _previewBoundary = GlobalKey();

class FakeInput implements AiInputRepository {
  String? received;
  bool single = false;
  int textCalls = 0;
  ReceiptImage? receipt;
  Object? receiptError;
  Completer<List<TransactionDraft>>? pendingReceipt;
  @override
  Future<List<TransactionDraft>> analyzeReceipt(ReceiptImage image) async {
    receipt = image;
    if (receiptError != null) throw receiptError!;
    if (pendingReceipt != null) return pendingReceipt!.future;
    return [
      TransactionDraft(
        text: 'Hóa đơn quán ăn',
        normalizedText: 'hóa đơn quán ăn',
        amount: 100000,
        type: 'expense',
        category: 'Ăn uống',
        confidence: 0,
        source: 'QWEN',
        occurredOn: DateTime(2026, 11, 10),
      ),
    ];
  }

  @override
  Future<List<TransactionDraft>> analyze(String text) async {
    textCalls++;
    received = text;
    final drafts = [
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
    return single ? [drafts.first] : drafts;
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

class FakeReceipt implements ReceiptInput {
  ReceiptImage? image;
  Completer<ReceiptImage?>? pending;
  @override
  Future<ReceiptImage?> pick() async =>
      pending != null ? pending!.future : image;
}

class FakeVoice implements VoiceInput {
  bool started = false, cancelled = false, disposed = false;
  Completer<void>? permission;

  /// The transcript the fake recogniser returns when recording stops.
  String transcript = 'ăn trưa sáu mươi lăm nghìn';

  @override
  bool get supported => true;
  @override
  Future<void> start() async {
    await permission?.future;
    started = true;
  }

  @override
  Future<String> stop() async => transcript;
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
    int? fixedExpensePlanId,
  }) async {
    if (pending != null) await pending!.future;
    if (failSecond && saved.isNotEmpty) throw StateError('offline');
    saved.add({
      'amount': amount,
      'account_id': accountId,
      'category_id': categoryId,
      'type': transactionType,
      'description': description,
      'date': transactionDate,
    });
  }
}

Future<void> open(
  WidgetTester tester,
  SavingRepository finance, {
  FakeInput? api,
  FakeVoice? voice,
  FakeReceipt? receipt,
  ThemeData? theme,
  double textScale = 1,
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
        theme: theme ?? AppTheme.kakeiboTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
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
                    receiptInput: receipt ?? FakeReceipt(),
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
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('aiAnalyzeButton')));
  await tester.tap(find.text('Xem giao dịch'));
  await tester.pumpAndSettle();
}

/// Record and stop, so the fake recogniser returns its transcript.
Future<void> speak(WidgetTester tester) async {
  await tester.tap(find.text('Ghi âm'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dừng ghi âm'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('confirmAiTransactions')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(
    tester.element(find.byKey(const ValueKey('confirmAiTransactions'))),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('confirmAiTransactions')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'one text draft opens review and applies edits before explicit save',
    (tester) async {
      final finance = SavingRepository();
      await open(tester, finance, api: FakeInput()..single = true);
      await analyze(tester);
      expect(find.text('Kiểm tra giao dịch'), findsOneWidget);
      expect(finance.saved, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('draftAmount')),
        '72.000',
      );
      await tester.ensureVisible(find.text('Áp dụng thay đổi'));
      await tester.tap(find.text('Áp dụng thay đổi'));
      await tester.pumpAndSettle();
      expect(find.text('Kiểm tra giao dịch'), findsNothing);
      expect(finance.saved, isEmpty);
      await save(tester);
      expect(finance.saved.single['amount'], 72000);
    },
  );

  testWidgets(
    'dismissing automatic review retains the draft without reopening or saving',
    (tester) async {
      final finance = SavingRepository();
      await open(tester, finance, api: FakeInput()..single = true);
      await analyze(tester);
      expect(find.text('Kiểm tra giao dịch'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Kiểm tra giao dịch'), findsNothing);
      expect(find.text('1 giao dịch'), findsOneWidget);
      expect(finance.saved, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Kiểm tra giao dịch'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Sửa giao dịch'));
      await tester.tap(find.byTooltip('Sửa giao dịch'));
      await tester.pumpAndSettle();
      expect(find.text('Kiểm tra giao dịch'), findsOneWidget);
      expect(finance.saved, isEmpty);
    },
  );

  testWidgets(
    'multiple drafts scroll into view on a narrow phone without opening a sheet',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final finance = SavingRepository();
      await open(tester, finance);
      await analyze(tester);
      expect(find.text('2 giao dịch').hitTestable(), findsOneWidget);
      expect(
        find.byTooltip('Sửa giao dịch').first.hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Kiểm tra giao dịch'), findsNothing);
      expect(finance.saved, isEmpty);
    },
  );

  testWidgets('switching to the manual form retains the typed description', (
    tester,
  ) async {
    final finance = SavingRepository();
    await open(tester, finance);
    await tester.enterText(
      find.byKey(const ValueKey('aiInputText')),
      'cơm trưa 65k',
    );
    await tester.ensureVisible(find.text('Chuyển sang biểu mẫu'));
    await tester.tap(find.text('Chuyển sang biểu mẫu'));
    await tester.pumpAndSettle();
    expect(find.text('cơm trưa 65k'), findsOneWidget);
    expect(find.byKey(const ValueKey('aiInputText')), findsNothing);
    expect(finance.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  if (captureUiEnabled) {
    testWidgets('reference preview', (tester) async {
      await loadEnvelopeFonts();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in ['light', 'dark', 'large-text']) {
        tester.view.physicalSize = Size(
          variant == 'large-text' ? 320 : 360,
          640,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await open(
          tester,
          SavingRepository(),
          theme: variant == 'dark'
              ? AppTheme.kakeiboDarkTheme
              : AppTheme.kakeiboTheme,
          textScale: variant == 'large-text' ? 1.6 : 1,
        );
        await captureUi(tester, _previewBoundary, 'ai-input-$variant');
        await analyze(tester);
        await captureUi(tester, _previewBoundary, 'ai-review-$variant');
        await tester.ensureVisible(find.byTooltip('Sửa giao dịch').first);
        await tester.tap(find.byTooltip('Sửa giao dịch').first);
        await tester.pumpAndSettle();
        await captureUi(tester, _previewBoundary, 'ai-edit-$variant');
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'analysis has editable drafts and does not save until confirmation',
    (tester) async {
      final finance = SavingRepository();
      await open(tester, finance);
      await analyze(tester);
      expect(find.text('2 giao dịch'), findsOneWidget);
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
      find.text('1 giao dịch'),
      -150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 giao dịch'), findsOneWidget);
    await save(tester);
    expect(finance.saved.single['amount'], 35000);
  });

  testWidgets('editing money changes the confirmed payload', (tester) async {
    final finance = SavingRepository();
    await open(tester, finance);
    await analyze(tester);
    await tester.scrollUntilVisible(
      find.byTooltip('Sửa giao dịch').first,
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
    await tester.tap(find.text('Ghi âm'));
    await tester.pumpAndSettle();
    expect(voice.started, isTrue);
    await tester.tap(find.text('Dừng ghi âm'));
    await tester.pumpAndSettle();
    expect(find.text('ăn trưa sáu mươi lăm nghìn'), findsOneWidget);
    expect(finance.saved, isEmpty);
    await tester.ensureVisible(find.byTooltip('Đóng'));
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(voice.disposed, isTrue);
  });

  testWidgets(
    'microphone permission inactive event does not cancel recording',
    (tester) async {
      final voice = FakeVoice()..permission = Completer<void>();
      await open(tester, SavingRepository(), voice: voice);
      await tester.tap(find.text('Ghi âm'));
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

  testWidgets('the spoken transcript reaches the ingestion request unchanged', (
    tester,
  ) async {
    final finance = SavingRepository();
    final api = FakeInput();
    final voice = FakeVoice()..transcript = 'cơm ba mươi nghìn tiền mặt';
    await open(tester, finance, api: api, voice: voice);
    await speak(tester);
    expect(find.text('cơm ba mươi nghìn tiền mặt'), findsOneWidget);
    expect(api.received, 'cơm ba mươi nghìn tiền mặt');
    expect(api.textCalls, 1);
    expect(finance.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty transcript reports the problem and sends nothing', (
    tester,
  ) async {
    final api = FakeInput();
    final voice = FakeVoice()..transcript = '';
    await open(tester, SavingRepository(), api: api, voice: voice);
    await speak(tester);
    expect(find.textContaining('Chưa nhận được lời nói'), findsOneWidget);
    expect(api.received, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a transcript longer than the endpoint limit is truncated', (
    tester,
  ) async {
    final api = FakeInput();
    final voice = FakeVoice()..transcript = 'a' * 2500;
    await open(tester, SavingRepository(), api: api, voice: voice);
    await speak(tester);
    expect(api.received?.length, 2000);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'receipt extraction is reviewed and preserves date on confirmation',
    (tester) async {
      final finance = SavingRepository();
      final api = FakeInput();
      final picker = FakeReceipt()
        ..image = ReceiptImage(
          bytes: Uint8List.fromList([1]),
          mimeType: 'image/png',
        );
      await open(tester, finance, api: api, receipt: picker);
      await tester.tap(find.byKey(const ValueKey('aiReceiptButton')));
      await tester.pumpAndSettle();
      expect(api.receipt, same(picker.image));
      expect(api.textCalls, 0);
      expect(finance.saved, isEmpty);
      expect(find.text('Kiểm tra giao dịch'), findsOneWidget);
      await tester.ensureVisible(find.text('Áp dụng thay đổi'));
      await tester.tap(find.text('Áp dụng thay đổi'));
      await tester.pumpAndSettle();
      expect(finance.saved, isEmpty);
      await save(tester);
      expect(finance.saved.single['amount'], 100000);
      expect(finance.saved.single['date'], DateTime(2026, 11, 10));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canceling receipt selection preserves existing text and drafts',
    (tester) async {
      final api = FakeInput();
      final finance = SavingRepository();
      await open(tester, finance, api: api);
      await analyze(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('aiReceiptButton')));
      await tester.tap(find.byKey(const ValueKey('aiReceiptButton')));
      await tester.pumpAndSettle();
      expect(api.receipt, isNull);
      expect(find.text('2 giao dịch'), findsOneWidget);
      expect(find.text('bún bò 65k, trà sữa 35k'), findsOneWidget);
      expect(finance.saved, isEmpty);
    },
  );

  testWidgets('receipt failure is visible and never saves a transaction', (
    tester,
  ) async {
    final api = FakeInput()
      ..receiptError = Exception('Dịch vụ đọc hóa đơn tạm thời không khả dụng');
    final finance = SavingRepository();
    final picker = FakeReceipt()
      ..image = ReceiptImage(
        bytes: Uint8List.fromList([1]),
        mimeType: 'image/png',
      );
    await open(tester, finance, api: api, receipt: picker);
    await tester.tap(find.byKey(const ValueKey('aiReceiptButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dịch vụ đọc hóa đơn tạm thời'), findsOneWidget);
    expect(finance.saved, isEmpty);
  });

  testWidgets('late receipt response after closing the screen is discarded', (
    tester,
  ) async {
    final api = FakeInput()
      ..pendingReceipt = Completer<List<TransactionDraft>>();
    final finance = SavingRepository();
    final picker = FakeReceipt()
      ..image = ReceiptImage(
        bytes: Uint8List.fromList([1]),
        mimeType: 'image/png',
      );
    await open(tester, finance, api: api, receipt: picker);
    await tester.tap(find.byKey(const ValueKey('aiReceiptButton')));
    await tester.pump();
    expect(find.text('Đang đọc hóa đơn…'), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    api.pendingReceipt!.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(finance.saved, isEmpty);
  });

  testWidgets('the receipt button is disabled while the screen is busy', (
    tester,
  ) async {
    final voice = FakeVoice()..permission = Completer<void>();
    await open(tester, SavingRepository(), voice: voice);
    await tester.tap(find.text('Ghi âm'));
    await tester.pump();
    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('aiReceiptButton')),
    );
    expect(button.onPressed, isNull);
    voice.permission!.complete();
    await tester.pumpAndSettle();
  });

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
