import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/app/widgets/app_screen_navigation.dart';
import 'package:project_one/core/config/supabase_config.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/chat/cubit/chat_cubit.dart';
import 'package:project_one/features/chat/data/chat_repository.dart';
import 'package:project_one/features/chat/widgets/chat_greeting.dart';
import 'package:project_one/features/chat/widgets/chat_message_bubble.dart';

/// The conversational home canvas.
///
/// The screen is the entry point of the assistant: a greeting, the quick
/// question suggestions and the conversation itself. The ledger keeps its own
/// route and navigation entry.
class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key, this.repository});

  final ChatRepository? repository;

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  final _controller = TextEditingController();
  late final ChatCubit _cubit = ChatCubit(
    widget.repository ?? BackendChatRepository(),
  )..start();

  @override
  void dispose() {
    _controller.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final message = text.trim();
    if (message.isEmpty) return;
    _controller.clear();
    await _cubit.send(message);
  }

  /// Hand the turn over to the multimodal ingestion route.
  Future<void> _openIngestion(
    BuildContext context,
    String route,
    String prompt,
  ) async {
    await context.push(route, extra: prompt);
  }

  String _displayName() {
    try {
      final metadata = SupabaseConfig.client.auth.currentUser?.userMetadata;
      for (final key in const ['full_name', 'name', 'display_name']) {
        final value = metadata?[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    } catch (_) {
      // The assistant still works without a signed-in profile.
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<ChatCubit, ChatState>(
        builder: (context, state) => _buildContent(context, state),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ChatState state) {
    return Scaffold(
      appBar: _buildAppBar(context, state),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildCanvas(context, state)),
            ChatComposer(
              controller: _controller,
              onSend: () => _send(_controller.text),
              enabled: state.sessionId != null,
              busy: state.sending,
              onVoice: () => _openIngestion(
                context,
                AppRoutes.aiQuickInput,
                'Nói để mình nhập giao dịch',
              ),
              onImage: () => _openIngestion(
                context,
                AppRoutes.aiQuickInput,
                'Chụp ảnh hóa đơn để mình đọc giúp',
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppScreenNavigation(selectedIndex: 0),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ChatState state) {
    final theme = Theme.of(context);
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 22,
              color: AppTheme.primaryForestGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trợ lý Tài chính',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  'CONVERSATIONAL CANVAS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: state.loading ? null : _cubit.reset,
          tooltip: 'Cuộc trò chuyện mới',
          icon: const Icon(Icons.add_comment_outlined),
        ),
      ],
    );
  }

  Widget _buildCanvas(BuildContext context, ChatState state) {
    if (state.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryForestGreen),
      );
    }
    if (state.error != null && state.messages.isEmpty && state.sessionId == null) {
      return _buildUnavailable(context, state);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (state.messages.isEmpty) ...[
          ChatGreeting(displayName: _displayName()),
          ChatQuickSuggestions(onTap: _send),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.plan),
            icon: const Icon(Icons.route_outlined, size: 18),
            label: const Text('Xem kế hoạch chi tiêu'),
          ),
        ] else ...[
          for (final message in state.messages)
            ChatMessageBubble(
              message: message.content,
              isUser: message.isUser,
            ),
          if (state.sending)
            const ChatMessageBubble(message: '', isUser: false, pending: true),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 8),
          Text(
            state.error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUnavailable(BuildContext context, ChatState state) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        ChatGreeting(displayName: _displayName()),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trợ lý hội thoại chưa sẵn sàng',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                state.error ??
                    'Hãy thêm GEMINI_API_KEY vào backend/.env để bật trợ lý hội thoại.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: state.loading ? null : _cubit.start,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.ledger),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Mở sổ thu chi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
