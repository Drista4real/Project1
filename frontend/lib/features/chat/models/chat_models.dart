// The value objects exchanged with the conversational assistant.

import 'dart:convert';

import 'package:project_one/core/network/json_numbers.dart';

/// One slot of the plan the assistant collects across turns.
class BudgetSlots {
  const BudgetSlots({
    this.totalIncome,
    this.durationDays,
    this.savingsTarget,
    this.fixedExpenses,
  });

  final num? totalIncome;
  final int? durationDays;
  final num? savingsTarget;
  final num? fixedExpenses;

  factory BudgetSlots.fromJson(Map<String, dynamic> json) => BudgetSlots(
    totalIncome: readDouble(json['total_income']),
    durationDays: readInt(json['duration_days']),
    savingsTarget: readDouble(json['savings_target']),
    fixedExpenses: readDouble(json['fixed_expenses']),
  );

  Map<String, dynamic> toJson() => {
    if (totalIncome != null) 'total_income': totalIncome,
    if (durationDays != null) 'duration_days': durationDays,
    if (savingsTarget != null) 'savings_target': savingsTarget,
    if (fixedExpenses != null) 'fixed_expenses': fixedExpenses,
  };

  /// The slots the assistant still needs before it can build a plan.
  List<String> get missing => [
    if (totalIncome == null) 'total_income',
    if (durationDays == null) 'duration_days',
    if (savingsTarget == null) 'savings_target',
    if (fixedExpenses == null) 'fixed_expenses',
  ];

  bool get isComplete => missing.isEmpty;
}

/// One message inside a conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    this.toolName,
  });

  final int id;
  final String sender;
  final String content;
  final String? toolName;

  bool get isUser => sender == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: (json['id'] as num?)?.toInt() ?? 0,
    sender: json['sender'] as String? ?? 'assistant',
    content: json['content'] as String? ?? '',
    toolName: json['tool_name'] as String?,
  );
}

/// One conversation.
class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.slots,
  });

  final int id;
  final String title;
  final BudgetSlots slots;

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? 'Cuộc trò chuyện tư vấn',
    slots: BudgetSlots.fromJson(
      (json['slots'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );
}

/// The assistant's answer to one message.
class ChatTurn {
  const ChatTurn({
    required this.sessionId,
    required this.reply,
    required this.slots,
    this.toolName,
  });

  final int sessionId;
  final String reply;
  final BudgetSlots slots;
  final String? toolName;

  factory ChatTurn.fromJson(Map<String, dynamic> json) {
    final calls = (json['tool_calls'] as List?) ?? const [];
    final toolName = calls.isEmpty
        ? null
        : (calls.first as Map)['name'] as String?;
    return ChatTurn(
      sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
      reply: json['reply'] as String? ?? '',
      slots: BudgetSlots.fromJson(
        (json['slots'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      toolName: toolName,
    );
  }
}

/// One tool the assistant may call.
class ChatTool {
  const ChatTool({
    required this.name,
    required this.description,
    required this.writes,
  });

  final String name;
  final String description;
  final bool writes;

  factory ChatTool.fromJson(Map<String, dynamic> json) => ChatTool(
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    writes: json['writes'] as bool? ?? false,
  );
}

/// The tools the assistant can use, and whether it is configured.
class ChatToolCatalog {
  const ChatToolCatalog({required this.tools, required this.available});

  final List<ChatTool> tools;
  final bool available;

  factory ChatToolCatalog.fromJson(Map<String, dynamic> json) => ChatToolCatalog(
    tools: ((json['tools'] as List?) ?? const [])
        .map((item) => ChatTool.fromJson((item as Map).cast<String, dynamic>()))
        .toList(),
    available: json['assistant_available'] as bool? ?? false,
  );
}

/// Reads a JSON body that may be missing or malformed.
Map<String, dynamic> decodeObject(Object? raw) {
  if (raw is Map) return raw.cast<String, dynamic>();
  if (raw is String && raw.isNotEmpty) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return decoded.cast<String, dynamic>();
  }
  return const {};
}
