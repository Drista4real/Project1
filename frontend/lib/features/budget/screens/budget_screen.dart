import 'package:flutter/material.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/app/widgets/app_screen_navigation.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/features/management/open_finance_module.dart';
import 'package:project_one/features/management/screens/resource_list_screen.dart';
import 'package:project_one/shared/widgets/finance_data_view.dart';
import '../models/budget_month_overview.dart';
import '../models/envelope_pillar.dart';
import '../services/category_envelopes_service.dart';
import '../widgets/budget_overview_content.dart';
import '../widgets/category_envelope_sheet.dart';
import '../widgets/envelope_rebalance_sheet.dart';
import '../widgets/envelope_sheet_frame.dart';
import '../widgets/envelope_theme.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key, this.insights});
  final FinanceInsights? insights;
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _dataController = FinanceDataController();
  late final _insights = widget.insights ?? AppDependencies.financeInsights;
  late final _load = _insights.budgets;
  late final _service = CategoryEnvelopesService(_insights.repository);
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _manage() async {
    await openFinanceModule(
      context,
      'budgets',
      defaults: {
        'month_year':
            '${_month.year}-${_month.month.toString().padLeft(2, '0')}-01',
      },
      repository: _insights.repository,
    );
    if (mounted) await _dataController.refresh();
  }

  Future<void> _savingGoals() async {
    await openFinanceModule(
      context,
      'saving_goals',
      repository: _insights.repository,
    );
    if (mounted) await _dataController.refresh();
  }

  Future<void> _sheet(Widget sheet) async {
    final saved = await showEnvelopeSheet(context, sheet);
    if (mounted) await _dataController.refresh();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật ngân sách.')));
    }
  }

  void _rebalance(BudgetMonthOverview overview) => _sheet(
    EnvelopeRebalanceSheet(service: _service, data: overview.envelopes),
  );

  Future<void> _edit(BudgetMonthOverview overview, FinanceRecord budget) async {
    final category = overview.data.spending.categories[budget['category_id']];
    if (category == null || category['is_income'] == true) {
      await openFinanceModule(
        context,
        'budgets',
        record: budget,
        repository: _insights.repository,
      );
      if (mounted) await _dataController.refresh();
      return;
    }
    await _sheet(
      CategoryEnvelopeSheet(
        service: _service,
        data: overview.envelopes,
        category: category,
      ),
    );
  }

  Future<void> _advanced() async {
    try {
      final resources = await _insights.repository.resources();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResourceListScreen(
            resource: resources.firstWhere((r) => r['name'] == 'budgets'),
            repository: _insights.repository,
          ),
        ),
      );
      if (mounted) await _dataController.refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: envelopeTheme(Theme.of(context)),
    child: Scaffold(
      backgroundColor: EnvelopeStyle.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        backgroundColor: EnvelopeStyle.canvas,
        title: const Text(
          'Ngân sách & phong bao',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: EnvelopeStyle.primary,
          ),
        ),
        actions: [
          IconButton.filledTonal(
            tooltip: 'Quản lý danh mục và phong bao',
            onPressed: _manage,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE5EDE5),
            ),
            icon: const Icon(Icons.category_outlined, size: 21),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FinanceDataView<BudgetData>(
        controller: _dataController,
        load: _load,
        builder: (context, data, refresh) {
          final overview = BudgetMonthOverview(data, _month);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              BudgetOverviewContent(
                overview: overview,
                onMonth: (delta) => setState(
                  () => _month = DateTime(_month.year, _month.month + delta),
                ),
                onManage: _manage,
                onRebalance: () => _rebalance(overview),
                onSavingGoals: _savingGoals,
                onEdit: (record) => _edit(overview, record),
                onAdvanced: _advanced,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: AppScreenNavigation(
        selectedIndex: 2,
        onTransactionAdded: _dataController.refresh,
      ),
    ),
  );
}
