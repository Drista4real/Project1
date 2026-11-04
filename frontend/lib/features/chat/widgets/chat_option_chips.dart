import 'package:flutter/material.dart';
import 'package:project_one/core/theme/app_theme.dart';

/// The choices the assistant offered, rendered as tappable chips.
///
/// Each chip is prefixed with a letter (A, B, C, D) so the user can tell the
/// options apart at a glance, and the last chip lets the user type an answer
/// of their own instead of picking one.
class ChatOptionChips extends StatefulWidget {
  const ChatOptionChips({
    required this.options,
    required this.onSelected,
    this.enabled = true,
    super.key,
  });

  /// The offered choices, in the order the assistant listed them.
  final List<String> options;

  /// Called with the chosen text, or with the text the user typed.
  final ValueChanged<String> onSelected;

  /// False while the assistant is busy or the turn was already answered.
  final bool enabled;

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
    widget.onSelected(text);
    setState(() {
      _customOpen = false;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < widget.options.length; index++)
              _OptionChip(
                label: widget.options[index],
                letter: _letterFor(index),
                onTap: widget.enabled
                    ? () => widget.onSelected(widget.options[index])
                    : null,
              ),
            _OptionChip(
              label: 'Khác',
              letter: _letterFor(widget.options.length),
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

  /// The letter that labels the nth option.
  String _letterFor(int index) => String.fromCharCode(65 + index);
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.letter,
    this.filled = false,
    this.onTap,
  });

  final String label;
  final String letter;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = filled
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
            color: filled
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
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
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
