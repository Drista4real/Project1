import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/onboarding/data/monthly_setup_gate.dart';
import 'package:project_one/features/chat/data/chat_repository.dart';
import 'package:project_one/features/chat/models/chat_models.dart';
import 'package:project_one/features/chat/screens/chat_home_screen.dart';

/// Tap a chip that may sit below the fold of the conversation.
///
/// The batch renders several groups of chips, so the last ones are outside
/// the viewport of the test window. The tap only lands when the widget was
/// brought on screen first.
Future<void> tapOption(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scroll the conversation until [text] is built.
///
/// The empty canvas holds the greeting, the monthly setup entry and the
/// suggestions, so a message under them sits below the 600 px test window.
Future<void> scrollCanvasTo(WidgetTester tester, String text) =>
    tester.scrollUntilVisible(
      find.text(text),
      120,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({this.available = true, this.failHistory = false});

  final bool available;
  final bool failHistory;
  final List<String> sent = [];

  @override
  Future<List<ChatTool>> tools() async => const [
    ChatTool(
      name: 'create_budget_plan',
      description: 'Lập kế hoạch chi tiêu',
      writes: true,
    ),
  ];

  @override
  Future<ChatSession> createSession({String title = 'Cuộc trò chuyện tư vấn'}) async {
    return ChatSession(id: 1, title: title, slots: const BudgetSlots());
  }

  @override
  Future<ChatSession> session(int sessionId) async {
    return ChatSession(id: sessionId, title: 'Cuộc trò chuyện', slots: const BudgetSlots());
  }

  @override
  Future<List<ChatMessage>> messages(int sessionId) async {
    if (failHistory) {
      throw const FinanceApiException('Không tải được lịch sử trò chuyện.');
    }
    return const [];
  }

  @override
  Future<ChatTurn> send({required int sessionId, required String message}) async {
    sent.add(message);
    if (message == 'Bắt đầu') {
      return ChatTurn(
        sessionId: sessionId,
        reply: 'Bạn muốn kế hoạch kéo dài bao lâu?',
        slots: const BudgetSlots(totalIncome: 20000000),
        options: const ['1 tháng', '3 tháng', '6 tháng'],
      );
    }
    if (message == 'Lô câu hỏi') {
      return ChatTurn(
        sessionId: sessionId,
        reply:
            'Mình cần bạn trả lời mấy câu sau:\n'
            '1. Bạn có khoản chi phí cố định nào không?\n'
            '2. Ăn uống hết bao nhiêu tiền?',
        slots: const BudgetSlots(totalIncome: 500000),
        questions: const [
          ChatQuestion(
            question: 'Bạn có khoản chi phí cố định nào không?',
            multiSelect: true,
            options: [
              ChatQuestionOption(label: 'Ăn uống'),
              ChatQuestionOption(label: 'Xăng xe'),
              ChatQuestionOption(label: 'Không có khoản cố định', exclusive: true),
            ],
          ),
          ChatQuestion(
            question: 'Ăn uống hết bao nhiêu tiền?',
            options: [
              ChatQuestionOption(
                label: '40%',
                amount: '200000.00',
                answer: '200000.00',
              ),
              ChatQuestionOption(
                label: '50%',
                amount: '250000.00',
                answer: '250000.00',
              ),
            ],
          ),
        ],
      );
    }
    if (message == 'Lô nhiều lựa chọn') {
      // The model offered five choices and a "Khác" of its own.
      return ChatTurn(
        sessionId: sessionId,
        reply: 'Mình cần bạn trả lời mấy câu sau:',
        slots: const BudgetSlots(totalIncome: 500000),
        questions: const [
          ChatQuestion(
            question: 'Bạn chi tiêu cho những khoản nào?',
            multiSelect: true,
            options: [
              ChatQuestionOption(label: 'Ăn uống'),
              ChatQuestionOption(label: 'Xăng xe'),
              ChatQuestionOption(label: 'Nhà hàng'),
              ChatQuestionOption(label: 'Thể thao'),
              ChatQuestionOption(label: 'Du lịch'),
              ChatQuestionOption(label: 'Khác'),
            ],
          ),
        ],
      );
    }
    return ChatTurn(
      sessionId: sessionId,
      reply: 'Đã ghi nhận: $message',
      slots: const BudgetSlots(totalIncome: 20000000),
    );
  }
}

class _FakeSetupGate implements MonthlySetupGate {
  _FakeSetupGate({required this.open});

  final bool open;
  int marked = 0;

  @override
  Future<bool> shouldAutoOpen() async => open && marked == 0;

  @override
  Future<void> markPrompted() async => marked++;
}

Future<void> _pumpHomeWithRouter(
  WidgetTester tester,
  MonthlySetupGate gate,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) =>
            ChatHomeScreen(repository: FakeChatRepository(), setupGate: gate),
      ),
      GoRoute(
        path: AppRoutes.monthlySetup,
        builder: (_, _) => const Scaffold(body: Text('SETUP')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty conversation shows the greeting and the suggestions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: FakeChatRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào bạn!'), findsOneWidget);
    expect(find.text('GỢI Ý CÂU HỎI NHANH'), findsOneWidget);
    expect(find.text('Phân bổ ngân sách tháng'), findsOneWidget);
    expect(find.byKey(const ValueKey('chatMessageField')), findsOneWidget);
  });

  testWidgets('the home screen offers the monthly setup next to the suggestions', (
    tester,
  ) async {
    await _pumpHomeWithRouter(tester, _FakeSetupGate(open: false));

    expect(find.text('Thiết lập kế hoạch tháng'), findsOneWidget);
    expect(find.text('Tiết kiệm tiền như thế nào?'), findsOneWidget);
    expect(find.text('Kiểm tra số dư hiện tại'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('monthly-setup-entry')));
    await tester.pumpAndSettle();
    expect(find.text('SETUP'), findsOneWidget);
  });

  testWidgets('a first sign-in opens the monthly setup once', (tester) async {
    final gate = _FakeSetupGate(open: true);
    await _pumpHomeWithRouter(tester, gate);

    expect(find.text('SETUP'), findsOneWidget);
    expect(gate.marked, 1);
  });

  testWidgets('a prompted user stays on the home screen', (tester) async {
    final gate = _FakeSetupGate(open: false);
    await _pumpHomeWithRouter(tester, gate);

    expect(find.text('SETUP'), findsNothing);
    expect(find.text('Chào bạn!'), findsOneWidget);
    expect(gate.marked, 0);
  });

  testWidgets('a suggestion starts the conversation', (tester) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Phân bổ ngân sách tháng'));
    await tester.pumpAndSettle();

    expect(repository.sent, ['Phân bổ ngân sách tháng']);
    expect(find.text('Đã ghi nhận: Phân bổ ngân sách tháng'), findsOneWidget);
  });

  testWidgets('the typed message reaches the assistant', (tester) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chatMessageField')),
      'Thu nhập 20 triệu',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(repository.sent, ['Thu nhập 20 triệu']);
  });

  testWidgets('a question offers tappable options', (tester) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chatMessageField')),
      'Bắt đầu',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Bạn muốn kế hoạch kéo dài bao lâu?'), findsOneWidget);
    expect(find.text('1 tháng'), findsOneWidget);
    expect(find.text('3 tháng'), findsOneWidget);
    expect(find.text('Khác'), findsOneWidget);

    await tester.tap(find.text('3 tháng'));
    await tester.pumpAndSettle();

    expect(repository.sent, ['Bắt đầu', '3 tháng']);
  });

  testWidgets('the custom option lets the user type an answer', (tester) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chatMessageField')),
      'Bắt đầu',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Khác'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chatCustomOptionField')),
      '12 tháng',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(repository.sent, ['Bắt đầu', '12 tháng']);
  });

  testWidgets('a failing history still leaves the composer usable', (
    tester,
  ) async {
    final repository = FakeChatRepository(failHistory: true);
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('chatMessageField')),
    );
    expect(field.enabled, isTrue);
    await scrollCanvasTo(tester, 'Không tải được lịch sử trò chuyện.');
    expect(find.text('Không tải được lịch sử trò chuyện.'), findsOneWidget);
  });

  testWidgets('a batch shows a chip group for every question', (tester) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chatMessageField')),
      'Lô câu hỏi',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // Both questions are on screen at once, not one per turn.
    expect(
      find.text('1. Bạn có khoản chi phí cố định nào không?'),
      findsOneWidget,
    );
    expect(find.text('2. Ăn uống hết bao nhiêu tiền?'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Xăng xe'), findsOneWidget);
    expect(find.text('Không có khoản cố định'), findsOneWidget);
    // The figure behind a ratio travels with the chip.
    expect(find.text('200000.00'), findsOneWidget);
    expect(find.text('250000.00'), findsOneWidget);
  });

  testWidgets('one button sends the answers of the whole batch', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chatMessageField')),
      'Lô câu hỏi',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // The button stays off until every question has an answer.
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('chatSendAnswersButton')),
    );
    expect(button.onPressed, isNull);

    await tapOption(tester, 'Ăn uống');
    await tapOption(tester, '40%');

    await tester.tap(find.byKey(const ValueKey('chatSendAnswersButton')));
    await tester.pumpAndSettle();

    expect(repository.sent.last, 'Trả lời:\n1. Ăn uống\n2. 200000.00');
  });
  testWidgets('a multi-select question keeps every picked option', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chatMessageField')),
      'Lô câu hỏi',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    await tapOption(tester, 'Ăn uống');
    await tapOption(tester, 'Xăng xe');
    await tapOption(tester, '50%');

    await tester.tap(find.byKey(const ValueKey('chatSendAnswersButton')));
    await tester.pumpAndSettle();

    expect(repository.sent.last, 'Trả lời:\n1. Ăn uống | Xăng xe\n2. 250000.00');
  });

  testWidgets('an exclusive option clears the other options', (tester) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chatMessageField')),
      'Lô câu hỏi',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    await tapOption(tester, 'Ăn uống');
    await tapOption(tester, 'Không có khoản cố định');
    await tapOption(tester, '40%');

    await tester.tap(find.byKey(const ValueKey('chatSendAnswersButton')));
    await tester.pumpAndSettle();

    // "Không có khoản cố định" rules the other options of its question out.
    expect(
      repository.sent.last,
      'Trả lời:\n1. Không có khoản cố định\n2. 200000.00',
    );
  });

  testWidgets('an answered batch shows only the picked chips', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chatMessageField')),
      'Lô câu hỏi',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    await tapOption(tester, 'Ăn uống');
    await tapOption(tester, '40%');
    await tester.tap(find.byKey(const ValueKey('chatSendAnswersButton')));
    await tester.pumpAndSettle();

    // The answer stays on screen, but the options that were not picked are
    // gone and the chips cannot be tapped any more.
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Xăng xe'), findsNothing);
    expect(find.text('Không có khoản cố định'), findsNothing);
    expect(find.byKey(const ValueKey('chatSendAnswersButton')), findsNothing);
  });

  testWidgets('a model option named "Khác" does not double the free-text entry', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChatHomeScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chatMessageField')),
      'Lô nhiều lựa chọn',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // The client offers its own "Khác" that opens the input field, so the
    // one the model wrote is not shown a second time.
    expect(find.text('Khác'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Du lịch'), findsOneWidget);

    // The letters keep their order without a gap: the five real choices are
    // A to E and the free-text entry follows them as F.
    expect(find.text('A.'), findsOneWidget);
    expect(find.text('E.'), findsOneWidget);
    expect(find.text('F.'), findsOneWidget);

    // The free-text entry still opens the input field.
    await tapOption(tester, 'Khác');
    expect(find.byKey(const ValueKey('chatCustomOptionField')), findsOneWidget);
  });

  testWidgets('an unavailable assistant offers a retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatHomeScreen(repository: _BrokenChatRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trợ lý hội thoại chưa sẵn sàng'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('a failed turn keeps the conversation on screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatHomeScreen(repository: _FailingTurnChatRepository()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chatMessageField')),
      'khoản 1 triệu',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // The conversation stays: the composer keeps working and the error is
    // shown next to the messages instead of replacing the whole canvas.
    expect(find.text('Trợ lý hội thoại chưa sẵn sàng'), findsNothing);
    await scrollCanvasTo(tester, 'Không gửi được tin nhắn.');
    expect(find.text('Không gửi được tin nhắn.'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('chatMessageField')),
    );
    expect(field.enabled, isTrue);
  });
}

class _FailingTurnChatRepository extends FakeChatRepository {
  @override
  Future<ChatTurn> send({required int sessionId, required String message}) async {
    throw const FinanceApiException('Không gửi được tin nhắn.');
  }
}

class _BrokenChatRepository implements ChatRepository {
  @override
  Future<List<ChatTool>> tools() async {
    throw const FinanceApiException('Máy chủ chưa sẵn sàng.');
  }

  @override
  Future<ChatSession> createSession({String title = 'Cuộc trò chuyện tư vấn'}) async {
    return ChatSession(id: 1, title: title, slots: const BudgetSlots());
  }

  @override
  Future<ChatSession> session(int sessionId) async {
    return ChatSession(id: sessionId, title: 'Cuộc trò chuyện', slots: const BudgetSlots());
  }

  @override
  Future<List<ChatMessage>> messages(int sessionId) async => const [];

  @override
  Future<ChatTurn> send({required int sessionId, required String message}) async {
    return ChatTurn(
      sessionId: sessionId,
      reply: '',
      slots: const BudgetSlots(),
    );
  }
}
