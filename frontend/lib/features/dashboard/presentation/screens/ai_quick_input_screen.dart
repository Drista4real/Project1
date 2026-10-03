import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/ai_input_box_card.dart';
import '../widgets/daily_spending_gauge_card.dart';
import '../widgets/parsed_transaction_card.dart';

class AiQuickInputScreen extends StatefulWidget {
  const AiQuickInputScreen({super.key});

  @override
  State<AiQuickInputScreen> createState() => _AiQuickInputScreenState();
}

class _AiQuickInputScreenState extends State<AiQuickInputScreen> {
  final _textController = TextEditingController(
    text:
        'Ăn trưa bún bò với bạn hết 65k, uống trà sữa 35k chuyển khoản lúc 12h30',
  );
  bool _rememberPillar = true;
  bool _isAnalyzing = false;
  bool _isSaving = false;

  late List<ParsedTransactionItem> _items;

  @override
  void initState() {
    super.initState();
    _initSampleParsedData();
  }

  void _initSampleParsedData() {
    _items = [
      ParsedTransactionItem(
        title: 'Bún bò Huế ăn trưa',
        amount: 65000,
        accountType: 'Tiền mặt',
        timeString: '12:15 hôm nay',
        pillar: 'Thiết yếu(Needs)',
        subCategory: 'Ăn trưa công sở',
        color: const Color(0xFFB64F2D),
        icon: Icons.ramen_dining_outlined,
        badgeText: 'Khớp quy chuẩn',
        isWarning: false,
      ),
      ParsedTransactionItem(
        title: 'Trà sữa bạn bè',
        amount: 35000,
        accountType: 'Vietcombank',
        timeString: '12:30 hôm nay',
        pillar: 'Mong muốn (Wants)',
        subCategory: 'Đồ uống & Xã hội',
        color: const Color(0xFFD96B43),
        icon: Icons.local_cafe_outlined,
        badgeText: '85% ngân sách tuần',
        isWarning: true,
      ),
    ];
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _analyzeInput() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAnalyzing = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI đã nhận diện và tách giao dịch!')),
        );
      });
    });
  }

  Future<void> _saveAllTransactions() async {
    setState(() => _isSaving = true);
    try {
      final addTransaction = AppDependencies.addTransaction;
      for (final item in _items) {
        await addTransaction(
          amount: item.amount,
          transactionType: 'expense',
          description: '${item.title} (${item.subCategory})',
          categoryName: item.pillar,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận & lưu các giao dịch vào Sổ Thu Chi!'),
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu giao dịch: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          // Input Box Card (Widget riêng)
          AiInputBoxCard(
            controller: _textController,
            isAnalyzing: _isAnalyzing,
            onAnalyze: _analyzeInput,
          ),

          const SizedBox(height: 18),

          // Header: "< Đã tách 2 giao dịch [Độ tin cậy 98%]"
          _buildParsedHeader(),

          const SizedBox(height: 12),

          // Danh sách các giao dịch đã tách (Widget riêng)
          for (var i = 0; i < _items.length; i++)
            ParsedTransactionCard(
              item: _items[i],
              index: i,
              onDismissed: () => setState(() => _items.removeAt(i)),
            ),

          const SizedBox(height: 14),

          // Tác động phong bao Kakeibo Card (Widget riêng)
          const PillarImpactCard(),

          const SizedBox(height: 14),

          // Hạn mức chi tiêu hôm nay (70% circular gauge - Widget riêng)
          const DailySpendingLimitGaugeCard(),

          const SizedBox(height: 14),

          // Checkbox "Ghi nhớ phong bao này cho các lần chi tương tự"
          _buildRememberCheckbox(),

          const SizedBox(height: 12),

          // Nút Xác nhận & Lưu vào Sổ Thu Chi
          _buildSubmitButton(),

          const SizedBox(height: 10),

          // Mẹo vuốt
          const Center(
            child: Text(
              'Mẹo: Vuốt sang trái trên từng giao dịch để xóa nếu không muốn lưu',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: AppTheme.primaryForestGreen),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          const Text(
            'Nhập Nhanh AI',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryForestGreen,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE5EDE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, size: 13, color: AppTheme.primaryForestGreen),
                Text(
                  'Kakeibo AI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryForestGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, color: AppTheme.textMuted, size: 21),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Nhập liệu tự nhiên Kakeibo AI'),
                content: const Text(
                  'Bạn có thể gõ hoặc nói tự nhiên một câu chứa nhiều giao dịch:\n\n"Ăn trưa 65k tiền mặt, cafe 35k chuyển khoản Techcombank"\n\nAI sẽ tự động tách rời từng giao dịch và phân vào 4 phong bao chuẩn xác.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildParsedHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(
              Icons.chevron_left,
              size: 20,
              color: AppTheme.primaryForestGreen,
            ),
            const SizedBox(width: 4),
            Text(
              'Đã tách ${_items.length} giao dịch',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textCharcoal,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE5EDE7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Độ tin cậy 98%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryForestGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _rememberPillar,
          activeColor: AppTheme.primaryForestGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: (val) => setState(() => _rememberPillar = val ?? true),
        ),
        const Expanded(
          child: Text(
            'Ghi nhớ phong bao này cho các lần chi tương tự',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textCharcoal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveAllTransactions,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryForestGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_outline, size: 20),
        label: Text(
          _isSaving ? 'Đang lưu vào sổ...' : 'Xác nhận & Lưu vào Sổ Thu Chi',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
