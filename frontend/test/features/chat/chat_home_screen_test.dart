import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/chat/data/chat_repository.dart';
import 'package:project_one/features/chat/models/chat_models.dart';
import 'package:project_one/features/chat/screens/chat_home_screen.dart';

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
    return ChatTurn(
      sessionId: sessionId,
      reply: 'Đã ghi nhận: $message',
      slots: const BudgetSlots(totalIncome: 20000000),
    );
  }
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
    expect(find.text('Không tải được lịch sử trò chuyện.'), findsOneWidget);
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
