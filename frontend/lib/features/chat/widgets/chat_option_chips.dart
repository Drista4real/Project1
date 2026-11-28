import 'package:flutter/material.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/chat/models/chat_models.dart';

/// The choices of one question, rendered as tappable chips.
///
/// Each chip is prefixed with a letter (A, B, C, D, E) so the user can tell
/// the options apart at a glance, and the last chip lets the user type an
/// answer of their own instead of picking one.
///
/// The picked state belongs to the batch, not to the chips: the batch is what
/// knows which options of which question are selected, because an exclusive
/// answer clears the other options of its own question only.
class ChatOptionChips extends StatefulWidget {
  const ChatOptionChips({
    required this.options,
    required this.onToggle,
    this.enabled = true,
    this.multiSelect = false,
    this.selected = const [],
    this.readOnly = false,
    super.key,
  });

  /// The offered choices, in the order the assistant listed them.
  final List<ChatQuestionOption> options;

  /// Called with the option the user tapped.
  final ValueChanged<ChatQuestionOption> onToggle;

  /// False while the assistant is busy or the turn was already answered.
  final bool enabled;

  /// True when the user may pick several options of this question.
  final bool multiSelect;

  /// The answers already picked for this question.
  ///
  /// An answer is matched against the option answer first and against its
  /// label second, so a batch that comes back from the history is matched
  /// even when the figure behind a ratio option is the answer.
  final List<String> selected;

  /// True when the question was answered: the chips show the answer and
  /// cannot be changed any more.
  final bool readOnly;

  @override
  State<ChatOptionChips> createState() => _ChatOptionChipsState();
}

class _ChatOptionChipsState extends State<ChatOptionChips> {
  final _controller = TextEditingController();
  bool _customOpen = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onToggle(ChatQuestionOption(label: text, answer: text));
    setState(() {
      _customOpen = false;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.readOnly) {
      return _buildReadOnly();
    }
    // The client's own free-text entry is left out of the letters, so the
    // visible choices stay labelled in order without a gap.
    final visible = widget.options
        .where((option) => !_isFreeText(option))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < visible.length; index++)
              _OptionChip(
                option: visible[index],
                letter: _letterFor(index),
                selected: _isPicked(visible[index]),
                onTap: widget.enabled
                    ? () => widget.onToggle(visible[index])
                    : null,
              ),
            // The free-text answer is offered by the client, so a "Khác" the
            // model wrote would be a second entry for the same thing. It is
            // left out and the input field takes its place.
            _OptionChip(
              option: const ChatQuestionOption(label: 'Khác'),
              letter: _letterFor(visible.length),
              filled: true,
              onTap: widget.enabled
                  ? () => setState(() => _customOpen = !_customOpen)
                  : null,
            ),
          ],
        ),
        if (_customOpen) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('chatCustomOptionField'),
                  controller: _controller,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitCustom(),
                  style: const TextStyle(fontSize: 14, height: 1.4),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Nhập câu trả lời của bạn...',
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _submitCustom,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryForestGreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// The chips of a question the user already answered.
  ///
  /// Only the picked options stay visible: the question is settled, and the
  /// other choices would only invite the user to change a finished answer.
  Widget _buildReadOnly() {
    final picked = widget.options
        .where((option) => _isPicked(option))
        .toList();
    if (picked.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < picked.length; index++)
          _OptionChip(
            option: picked[index],
            letter: _letterFor(index),
            selected: true,
            onTap: null,
          ),
      ],
    );
  }

  /// True when this option was the answer the user picked.
  bool _isPicked(ChatQuestionOption option) {
    for (final answer in widget.selected) {
      if (answer == option.label) return true;
      if (option.answer.isNotEmpty && answer == option.answer) return true;
    }
    return false;
  }

  /// True when the option is the free-text entry the client offers itself.
  ///
  /// The model sometimes lists a "Khác" of its own. The client already ends
  /// every question with a "Khác" that opens the input field, so the model's
  /// one is left out instead of showing the same entry twice.
  bool _isFreeText(ChatQuestionOption option) {
    final label = option.label.trim().toLowerCase();
    return label == 'khác' || label == 'khac' || label == 'other';
  }

  /// The letter that labels the nth option.
  String _letterFor(int index) => String.fromCharCode(65 + index);
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.option,
    required this.letter,
    this.filled = false,
    this.selected = false,
    this.onTap,
  });

  final ChatQuestionOption option;
  final String letter;
  final bool filled;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected || filled
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surface;
    return Semantics(
      container: true,
      identifier: 'chat-option',
      button: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected || filled
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$letter.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    option.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (option.amount != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    option.amount!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
