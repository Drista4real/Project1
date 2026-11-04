import 'package:flutter/material.dart';
import 'package:project_one/features/chat/models/chat_models.dart';
import 'package:project_one/features/chat/widgets/chat_message_bubble.dart';
import 'package:project_one/features/chat/widgets/chat_option_chips.dart';

/// One message with the choices it offered, if it offered any.
///
/// The options belong to the question, so they sit right under the bubble.
/// Only the last question stays tappable: once the user has answered, the
/// chips remain as the record of what could have been chosen.
class ChatMessageBlock extends StatelessWidget {
  const ChatMessageBlock({
    required this.message,
    required this.isLast,
    required this.busy,
    required this.onSend,
    super.key,
  });

  final ChatMessage message;
  final bool isLast;
  final bool busy;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatMessageBubble(message: message.content, isUser: message.isUser),
        if (message.hasOptions && !message.isUser) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ChatOptionChips(
              options: message.options,
              enabled: isLast && !busy,
              onSelected: onSend,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
