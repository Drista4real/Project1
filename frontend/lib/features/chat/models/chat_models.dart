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

/// One choice offered with a question.
class ChatQuestionOption {
  const ChatQuestionOption({
    required this.label,
    this.amount,
    this.exclusive = false,
    String? answer,
  }) : _answer = answer ?? '';

  /// The text shown on the chip.
  final String label;

  /// The figure the server computed from a ratio, if the option carries one.
  final String? amount;

  /// True when picking this option clears the other options of the question.
  final bool exclusive;

  final String _answer;

  /// The text sent back to the assistant when the user picks this option.
  ///
  /// An option without its own answer answers with its label: the assistant
  /// reads the label, and only a figure is worth a different answer.
  String get answer => _answer.isNotEmpty ? _answer : label;

  factory ChatQuestionOption.fromJson(Map<String, dynamic> json) =>
      ChatQuestionOption(
        label: json['label'] as String? ?? '',
        amount: json['amount']?.toString(),
        exclusive: json['exclusive'] as bool? ?? false,
        answer: json['answer'] as String? ?? json['label'] as String? ?? '',
      );
}

/// The caption of a question, without the number the model may have added.
///
/// The client numbers the questions of a batch itself, so a number the model
/// put in front of the question would show up twice.
String questionCaption(String question) {
  return question.replaceFirst(RegExp(r'^\s*\d+[.)]\s*'), '').trim();
}

/// One question of a batch, with the choices offered for it.
class ChatQuestion {
  const ChatQuestion({
    required this.question,
    required this.options,
    this.multiSelect = false,
  });

  final String question;
  final List<ChatQuestionOption> options;

  /// True when the user may pick several options of this question.
  final bool multiSelect;

  factory ChatQuestion.fromJson(Map<String, dynamic> json) => ChatQuestion(
    question: json['question'] as String? ?? '',
    options: ((json['options'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => ChatQuestionOption.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.label.trim().isNotEmpty)
        .toList(),
    multiSelect: json['multi_select'] as bool? ?? false,
  );
}

/// Reads the answers of a batch back from the message the user sent.
///
/// The client sends the answers of a batch as one numbered message, so the
/// history can show which chips were picked when the conversation is opened
/// again.
List<String> parseBatchAnswers(String content) {
  final answers = <String>[];
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    final match = RegExp(r'^(\d+)\.\s*(.*)$').firstMatch(trimmed);
    if (match == null) continue;
    final index = int.parse(match.group(1)!);
    if (index < 1) continue;
    while (answers.length < index) {
      answers.add('');
    }
    answers[index - 1] = match.group(2)!.trim();
  }
  return answers;
}

/// One message inside a conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    this.toolName,
    this.options = const [],
    this.questions = const [],
  });

  final int id;
  final String sender;
  final String content;
  final String? toolName;

  /// The choices the assistant offered, shown as tappable chips.
  final List<String> options;

  /// The questions the assistant offered, each with its own chips.
  final List<ChatQuestion> questions;

  bool get isUser => sender == 'user';
  bool get hasOptions => options.isNotEmpty;
  bool get hasQuestions => questions.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: (json['id'] as num?)?.toInt() ?? 0,
    sender: json['sender'] as String? ?? 'assistant',
    content: json['content'] as String? ?? '',
    toolName: json['tool_name'] as String?,
    options: ((json['options'] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(),
    questions: ((json['questions'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => ChatQuestion.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.options.isNotEmpty)
        .toList(),
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
    this.options = const [],
    this.questions = const [],
  });

  final int sessionId;
  final String reply;
  final BudgetSlots slots;
  final String? toolName;

  /// The choices the assistant offered, shown as tappable chips.
  final List<String> options;

  /// The questions the assistant offered, each with its own chips.
  final List<ChatQuestion> questions;

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
      options: ((json['options'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      questions: ((json['questions'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => ChatQuestion.fromJson(item.cast<String, dynamic>()))
          .where((item) => item.options.isNotEmpty)
          .toList(),
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
