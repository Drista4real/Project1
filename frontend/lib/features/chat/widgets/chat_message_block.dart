import 'package:flutter/material.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/chat/models/chat_models.dart';
import 'package:project_one/features/chat/widgets/chat_message_bubble.dart';
import 'package:project_one/features/chat/widgets/chat_option_chips.dart';

/// One assistant message with the batch of questions it offered.
///
/// Every question of the batch gets its own group of chips, so the user sees
/// all of them at once instead of one question per turn. The answers are
/// collected here and sent as a single message when the user taps the send
/// button at the end of the batch.
///
/// Only the last batch stays interactive: once the user answered it, the
/// chips turn into the record of what was picked.
class ChatMessageBlock extends StatefulWidget {
  const ChatMessageBlock({
    required this.message,
    required this.isLast,
    required this.busy,
    required this.onSend,
    this.answeredPicks = const {},
    super.key,
  });

  final ChatMessage message;
  final bool isLast;
  final bool busy;
  final ValueChanged<String> onSend;

  /// The answers already picked for every question, keyed by the question
  /// index. A batch that was answered in an earlier session comes back from
  /// the history with its answers, so the chips show them read-only.
  final Map<int, List<String>> answeredPicks;

  @override
  State<ChatMessageBlock> createState() => _ChatMessageBlockState();
}

class _ChatMessageBlockState extends State<ChatMessageBlock> {
  /// The picked option of every question, keyed by the question index.
  final Map<int, List<ChatQuestionOption>> _picked = {};

  /// True once the batch was sent: the chips become read-only.
  bool _answered = false;

  bool get _interactive =>
      widget.message.hasQuestions &&
      widget.isLast &&
      !widget.busy &&
      !_answered;

  void _toggle(int questionIndex, ChatQuestionOption option) {
    setState(() {
      final picked = _picked.putIfAbsent(questionIndex, () => []);
      final question = widget.message.questions[questionIndex];
      if (option.exclusive) {
        // An exclusive answer rules the other options of its question out.
        picked
          ..clear()
          ..add(option);
        return;
      }
      final existing = picked.indexWhere((item) => item.label == option.label);
      if (existing >= 0) {
        picked.removeAt(existing);
        return;
      }
      if (!question.multiSelect) {
        picked
          ..clear()
          ..add(option);
        return;
      }
      picked.add(option);
    });
  }

  /// True when every question of the batch has an answer.
  bool get _complete {
    for (var index = 0; index < widget.message.questions.length; index++) {
      if ((_picked[index] ?? const []).isEmpty) return false;
    }
    return true;
  }

  /// Render the answers as one message the assistant can read back.
  String _buildAnswer() {
    final lines = <String>['Trả lời:'];
    for (var index = 0; index < widget.message.questions.length; index++) {
      final picked = _picked[index] ?? const <ChatQuestionOption>[];
      if (picked.isEmpty) continue;
      final answers = picked.map((option) => option.answer).join(' | ');
      lines.add('${index + 1}. $answers');
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatMessageBubble(
          message: widget.message.content,
          isUser: widget.message.isUser,
        ),
        if (widget.message.hasQuestions && !widget.message.isUser) ...[
          const SizedBox(height: 2),
          for (
            var index = 0;
            index < widget.message.questions.length;
            index++
          ) ...[
            _QuestionGroup(
              number: index + 1,
              question: widget.message.questions[index],
              picked: _picked[index] ?? const [],
              answered: widget.answeredPicks[index] ?? const [],
              interactive: _interactive,
              onToggle: (option) => _toggle(index, option),
            ),
            const SizedBox(height: 10),
          ],
          if (_interactive)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey('chatSendAnswersButton'),
                onPressed: _complete
                    ? () {
                        setState(() => _answered = true);
                        widget.onSend(_buildAnswer());
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryForestGreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                label: const Text('Gửi câu trả lời'),
              ),
            ),
        ] else if (widget.message.hasOptions && !widget.message.isUser) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ChatOptionChips(
              options: widget.message.options
                  .map((label) => ChatQuestionOption(label: label, answer: label))
                  .toList(),
              enabled: widget.isLast && !widget.busy,
              onToggle: (option) => widget.onSend(option.answer),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// One question of the batch with its own group of chips.
class _QuestionGroup extends StatelessWidget {
  const _QuestionGroup({
    required this.number,
    required this.question,
    required this.picked,
    required this.answered,
    required this.interactive,
    required this.onToggle,
  });

  /// The number of the question in the batch. The answers carry it, so the
  /// user and the assistant talk about the same question.
  final int number;

  final ChatQuestion question;
  final List<ChatQuestionOption> picked;
  final List<String> answered;
  final bool interactive;
  final ValueChanged<ChatQuestionOption> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = picked.isNotEmpty
        ? picked.map((option) => option.label).toList()
        : answered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            '$number. ${questionCaption(question.question)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: ChatOptionChips(
            options: question.options,
            multiSelect: question.multiSelect,
            selected: selected,
            readOnly: !interactive,
            enabled: interactive,
            onToggle: onToggle,
          ),
        ),
      ],
    );
  }
}
