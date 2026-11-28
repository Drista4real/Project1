import 'package:flutter/material.dart';

/// The greeting shown on an empty conversation.
class ChatGreeting extends StatelessWidget {
  const ChatGreeting({required this.displayName, super.key});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chào bạn!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            displayName.isEmpty
                ? 'Mình có thể lên kế hoạch chi tiêu và cảnh báo bạn trước mỗi khoản mua.'
                : 'Mình có thể lên kế hoạch chi tiêu và cảnh báo bạn trước mỗi khoản mua.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The quick question suggestions offered on an empty conversation.
class ChatQuickSuggestions extends StatelessWidget {
  const ChatQuickSuggestions({required this.onTap, super.key});

  final ValueChanged<String> onTap;

  /// The suggestions match the assistant's three scenarios.
  static const List<String> defaults = <String>[
    'Phân bổ ngân sách tháng',
    'Tiết kiệm tiền như thế nào?',
    'Kiểm tra số dư hiện tại',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Text(
          'GỢI Ý CÂU HỎI NHANH',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in defaults)
              _SuggestionChip(label: suggestion, onTap: () => onTap(suggestion)),
          ],
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      identifier: 'chat-suggestion',
      button: true,
      child: ActionChip(
        onPressed: onTap,
        backgroundColor: theme.colorScheme.surface,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        label: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
