import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/chat/models/chat_models.dart';

/// The conversational assistant's server contract.
abstract interface class ChatRepository {
  Future<List<ChatTool>> tools();

  Future<ChatSession> createSession({String title});

  Future<ChatSession> session(int sessionId);

  Future<List<ChatMessage>> messages(int sessionId);

  Future<ChatTurn> send({required int sessionId, required String message});
}

class BackendChatRepository implements ChatRepository {
  BackendChatRepository({BackendClient? client}) : client = client ?? BackendClient();

  final BackendClient client;

  @override
  Future<List<ChatTool>> tools() async {
    final response =
        await client.request('GET', '/chat/tools') as Map<String, dynamic>;
    return ChatToolCatalog.fromJson(response).tools;
  }

  @override
  Future<ChatSession> createSession({String title = 'Cuộc trò chuyện tư vấn'}) async {
    final response =
        await client.request(
              'POST',
              '/chat/sessions',
              body: {'title': title},
            )
            as Map<String, dynamic>;
    return ChatSession.fromJson(
      decodeObject(response['session']),
    );
  }

  @override
  Future<ChatSession> session(int sessionId) async {
    final response =
        await client.request('GET', '/chat/sessions/$sessionId')
            as Map<String, dynamic>;
    return ChatSession.fromJson(decodeObject(response['session']));
  }

  @override
  Future<List<ChatMessage>> messages(int sessionId) async {
    final response =
        await client.request('GET', '/chat/sessions/$sessionId/messages')
            as Map<String, dynamic>;
    final items = (response['items'] as List?) ?? const [];
    return items
        .map((item) => ChatMessage.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<ChatTurn> send({
    required int sessionId,
    required String message,
  }) async {
    final response =
        await client.request(
              'POST',
              '/chat/turn',
              body: {'session_id': sessionId, 'message': message},
            )
            as Map<String, dynamic>;
    return ChatTurn.fromJson(decodeObject(response['turn']));
  }
}
