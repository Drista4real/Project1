import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/kakeibo_ui.dart';
import 'management_screen.dart';
import 'quick_add_transaction_screen.dart';

class AiQuickInputScreen extends StatefulWidget {
  const AiQuickInputScreen({super.key});
  @override
  State<AiQuickInputScreen> createState() => _AiQuickInputScreenState();
}

class _AiQuickInputScreenState extends State<AiQuickInputScreen> {
  final _textController = TextEditingController();
  bool _opening = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _continueManually() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => QuickAddTransactionScreen(
            initialDescription: _textController.text.trim(),
          ),
        ),
      );
      if (saved == true && mounted) context.pop(true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nhập Nhanh AI')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        KakeiboCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    color: AppTheme.primaryForestGreen,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ghi lại nội dung giao dịch',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Ví dụ: Ăn trưa 65k tiền mặt',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tự động phân tích bằng AI chưa khả dụng. Bạn có thể nhập số tiền, ví và danh mục để lưu giao dịch.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _opening ? null : _continueManually,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Tiếp tục nhập thủ công'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        KakeiboCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dữ liệu tư vấn của bạn',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: const Text('Lịch sử tư vấn'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openFinanceModule(context, 'ai_consultations'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Cuộc trò chuyện'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openFinanceModule(context, 'ai_chat_sessions'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
