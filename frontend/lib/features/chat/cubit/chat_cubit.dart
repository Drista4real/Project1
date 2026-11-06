import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/chat/data/chat_repository.dart';
import 'package:project_one/features/chat/models/chat_models.dart';

/// The state of the conversational canvas.
class ChatState {
  const ChatState({
    this.sessionId,
    this.messages = const [],
    this.slots = const BudgetSlots(),
    this.tools = const [],
    this.assistantAvailable = false,
    this.loading = true,
    this.sending = false,
    this.error,
  });

  final int? sessionId;
  final List<ChatMessage> messages;
  final BudgetSlots slots;
  final List<ChatTool> tools;
  final bool assistantAvailable;
  final bool loading;
  final bool sending;
  final String? error;

  ChatState copyWith({
    int? sessionId,
    List<ChatMessage>? messages,
    BudgetSlots? slots,
    List<ChatTool>? tools,
    bool? assistantAvailable,
    bool? loading,
    bool? sending,
    String? error,
    bool clearError = false,
  }) => ChatState(
    sessionId: sessionId ?? this.sessionId,
    messages: messages ?? this.messages,
    slots: slots ?? this.slots,
    tools: tools ?? this.tools,
    assistantAvailable: assistantAvailable ?? this.assistantAvailable,
    loading: loading ?? this.loading,
    sending: sending ?? this.sending,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives the conversational canvas: the session, the messages and the slots.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this.repository) : super(const ChatState());

  final ChatRepository repository;

  /// Load the tool catalog and open a conversation.
  Future<void> start() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final tools = await repository.tools();
      final session = await repository.createSession();
      // The session is usable as soon as it exists. The history is a
      // convenience: a failure to read it must not lock the composer.
      emit(
        state.copyWith(
          sessionId: session.id,
          slots: session.slots,
          tools: tools,
          assistantAvailable: true,
          loading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          loading: false,
          assistantAvailable: false,
          error: _message(error),
        ),
      );
      return;
    }
    try {
      final history = await repository.messages(state.sessionId!);
      emit(state.copyWith(messages: history, clearError: true));
    } catch (error) {
      emit(state.copyWith(error: _message(error)));
    }
  }

  /// Send one message and append the assistant's answer.
  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.sending) return;
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    final pending = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch,
      sender: 'user',
      content: message,
    );
    emit(
      state.copyWith(
        messages: [...state.messages, pending],
        sending: true,
        clearError: true,
      ),
    );
    try {
      final turn = await repository.send(sessionId: sessionId, message: message);
      emit(
        state.copyWith(
          messages: [
            ...state.messages,
            ChatMessage(
              id: -1,
              sender: 'assistant',
              content: turn.reply,
              toolName: turn.toolName,
              options: turn.options,
            ),
          ],
          slots: turn.slots,
          sending: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          messages: state.messages.where((item) => item.id != pending.id).toList(),
          sending: false,
          error: _message(error),
        ),
      );
    }
  }

  /// Start a new conversation and drop the collected slots.
  Future<void> reset() async {
    emit(const ChatState());
    await start();
  }

  /// Turn an error into a message the user can act on.
  ///
  /// `FinanceApiException.toString()` is already the plain message, so the
  /// prefix check below only covers a wrapped error.
  String _message(Object error) {
    if (error is FinanceApiException) {
      return error.message;
    }
    final text = error.toString();
    if (text.startsWith('FinanceApiException: ')) {
      return text.replaceFirst('FinanceApiException: ', '');
    }
    return 'Không gửi được tin nhắn. Vui lòng thử lại.';
  }
}
