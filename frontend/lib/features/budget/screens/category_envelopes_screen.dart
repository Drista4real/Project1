import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/app/widgets/app_screen_navigation.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/features/management/screens/resource_list_screen.dart';
import 'package:project_one/features/management/widgets/management_error_panel.dart';
import '../models/category_envelope_data.dart';
import '../models/envelope_pillar.dart';
import '../services/category_envelopes_service.dart';
import '../widgets/category_envelope_content.dart';
import '../widgets/category_envelope_sheet.dart';
import '../widgets/envelope_rebalance_sheet.dart';
import '../widgets/envelope_theme.dart';
import '../widgets/envelope_sheet_frame.dart';

class CategoryEnvelopesScreen extends StatefulWidget {
  const CategoryEnvelopesScreen({super.key, this.repository, this.month});
  final ManagementRepository? repository;
  final DateTime? month;
  @override
  State<CategoryEnvelopesScreen> createState() =>
      _CategoryEnvelopesScreenState();
}

class _CategoryEnvelopesScreenState extends State<CategoryEnvelopesScreen> {
  late final _service = CategoryEnvelopesService(
    widget.repository ?? AppDependencies.managementRepository,
  );
  late DateTime _month =
      widget.month ?? DateTime(DateTime.now().year, DateTime.now().month);
  late Future<CategoryEnvelopeData> _future = _service.load(_month);
  final _search = TextEditingController();
  bool _mutating = false;
  void _reload() => setState(() {
    _future = _service.load(_month);
  });
  Future<void> _refresh() async {
    if (!mounted) return;
    _reload();
    try {
      await _future;
    } catch (_) {
      // The FutureBuilder renders the load error and its retry action.
    }
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _future = _service.load(_month);
    });
  }

  Future<void> _sheet(Widget child) async {
    final saved = await showEnvelopeSheet(context, child);
    if (mounted) _reload();
    if (saved == true && mounted) _notice('Đã lưu thay đổi.');
  }

  void _edit(
    CategoryEnvelopeData data, {
    FinanceRecord? category,
    EnvelopePillar pillar = EnvelopePillar.needs,
  }) => _sheet(
    CategoryEnvelopeSheet(
      service: _service,
      data: data,
      category: category,
      initialPillar: pillar,
    ),
  );

  Future<void> _disable(
    CategoryEnvelopeData data,
    FinanceRecord category,
  ) async {
    if (_mutating) return;
    final confirmed = await _confirm(
      'Tắt phong bao tháng này?',
      'Gỡ hạn mức của “${category['name']}” trong tháng ${_month.month}/${_month.year}. Danh mục và giao dịch vẫn được giữ lại.',
      'Tắt phong bao',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _mutating = true);
    try {
      await _service.saveLimit(data, category['id'] as int, null);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) _notice('Không thể tắt phong bao: $error');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _action(
    CategoryEnvelopeData data,
    FinanceRecord category,
    String action,
  ) async {
    if (action == 'edit') {
      _edit(data, category: category);
      return;
    }
    if (action == 'disable') {
      await _disable(data, category);
      return;
    }
    if (_mutating || category['user_id'] == null) return;
    if (data.budgetFor(categoryId: category['id'] as int) != null) {
      _notice('Hãy tắt phong bao trước khi xóa danh mục.');
      return;
    }
    final confirmed = await _confirm(
      'Xóa danh mục?',
      'Bạn muốn xóa “${category['name']}”? Danh mục đang có giao dịch hoặc liên kết khác sẽ được bảo vệ.',
      'Xóa danh mục',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _mutating = true);
    try {
      await _service.repository.delete(
        'categories',
        _service.repository.key('categories', category),
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) _notice('Chưa thể xóa danh mục: $error');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<bool?> _confirm(String title, String message, String action) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      );
  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _advanced(String resourceName) async {
    try {
      final resources = await _service.repository.resources();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResourceListScreen(
            resource: resources.firstWhere((r) => r['name'] == resourceName),
            repository: _service.repository,
          ),
        ),
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) _notice('$error');
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: envelopeTheme(Theme.of(context)),
    child: Scaffold(
      backgroundColor: EnvelopeStyle.canvas,
      appBar: AppBar(
        backgroundColor: EnvelopeStyle.canvas,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        titleSpacing: 0,
        title: const Text(
          'Quản lý danh mục & phong bao',
          maxLines: 2,
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: EnvelopeStyle.primary,
          ),
        ),
        actions: [
          IconButton.filledTonal(
            tooltip: 'Thêm danh mục mới',
            onPressed: _mutating
                ? null
                : () async {
                    try {
                      final data = await _future;
                      if (mounted) _edit(data);
                    } catch (_) {
                      if (mounted) {
                        _notice(
                          'Vui lòng tải lại danh mục trước khi thêm mới.',
                        );
                      }
                    }
                  },
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE5EDE5),
            ),
            icon: const Icon(Icons.add, size: 22),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<CategoryEnvelopeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ManagementErrorPanel(error: snapshot.error!, retry: _reload);
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Đang tải danh mục và phong bao',
              ),
            );
          }
          final data = snapshot.data!;
          return AbsorbPointer(
            absorbing: _mutating,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (_mutating) const LinearProgressIndicator(),
                  CategoryEnvelopeContent(
                    data: data,
                    search: _search,
                    onSearch: () => setState(() {}),
                    onMonth: _moveMonth,
                    onAdd: (pillar) => _edit(data, pillar: pillar),
                    onRebalance: () => _sheet(
                      EnvelopeRebalanceSheet(service: _service, data: data),
                    ),
                    onEdit: (c) => _edit(data, category: c),
                    onAction: (c, action) => _action(data, c, action),
                    onDisable: (c) => _disable(data, c),
                    onAdvanced: _advanced,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: AppScreenNavigation(
        selectedIndex: 2,
        onSelectedTab: () {
          final router = GoRouter.of(context);
          Navigator.pop(context);
          router.go(AppRoutes.budget);
        },
        onTransactionAdded: _refresh,
      ),
    ),
  );
}
