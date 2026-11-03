import 'package:flutter/material.dart';
import 'package:project_one/core/theme/app_theme.dart';

/// One bubble in the conversation.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.isUser,
    this.pending = false,
    super.key,
  });

  final String message;
  final bool isUser;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.45,
                color: isUser
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
            if (pending) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryForestGreen,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The message composer at the bottom of the canvas.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.controller,
    required this.onSend,
    required this.enabled,
    required this.busy,
    this.onVoice,
    this.onImage,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final bool busy;
  final VoidCallback? onVoice;
  final VoidCallback? onImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Semantics(
            container: true,
            identifier: 'chat-voice',
            button: true,
            child: IconButton(
              onPressed: enabled && !busy ? onVoice : null,
              tooltip: 'Nói thay bằng giọng',
              icon: const Icon(Icons.mic_none_rounded),
            ),
          ),
          Expanded(
            child: Semantics(
              container: true,
              identifier: 'chat-input',
              textField: true,
              child: TextField(
                key: const ValueKey('chatMessageField'),
                controller: controller,
                enabled: enabled && !busy,
                minLines: 1,
                maxLines: 4,
                maxLength: 4000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(fontSize: 15, height: 1.4),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Nhập tin nhắn hoặc câu hỏi...',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            container: true,
            identifier: 'chat-image',
            button: true,
            child: IconButton(
              onPressed: enabled && !busy ? onImage : null,
              tooltip: 'Gửi ảnh hóa đơn',
              icon: const Icon(Icons.image_outlined),
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            container: true,
            identifier: 'chat-send',
            button: true,
            child: IconButton.filled(
              onPressed: enabled && !busy ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryForestGreen,
                foregroundColor: Colors.white,
              ),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
