import 'package:flutter/material.dart';

import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/shared/widgets/finance_form.dart';
import 'package:project_one/features/management/config/management_metadata.dart';
import 'package:project_one/features/management/widgets/management_error_panel.dart';
import 'package:project_one/features/management/screens/record_form_screen.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';

class ResourceListScreen extends StatefulWidget {
  const ResourceListScreen({
    super.key,
    required this.resource,
    required this.repository,
  });
  final Map<String, dynamic> resource;
  final ManagementRepository repository;
  @override
  State<ResourceListScreen> createState() => _ResourceListScreenState();
}

class _ResourceListScreenState extends State<ResourceListScreen> {
  String get name => widget.resource['name'] as String;
  bool get singleton => widget.resource['singleton'] == true;
  int _offset = 0;
  late Future<Map<String, dynamic>> _page = widget.repository.page(name);
  bool _deleting = false;
  void _load() =>
      setState(() => _page = widget.repository.page(name, offset: _offset));

  Future<void> _edit([Map<String, dynamic>? record]) async {
    try {
      final fresh = record == null
          ? null
          : await widget.repository.get(
              name,
              widget.repository.key(name, record),
            );
      if (!mounted) return;
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RecordFormScreen(
            resource: widget.resource,
            repository: widget.repository,
            record: fresh,
          ),
        ),
      );
      if (changed == true && mounted) _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final extra = name == 'ai_chat_sessions'
        ? '\nToàn bộ tin nhắn trong cuộc trò chuyện cũng sẽ bị xóa.'
        : name == 'tags'
        ? '\nThẻ cũng sẽ được gỡ khỏi các giao dịch.'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa dữ liệu này?'),
        content: Text(
          'Bạn muốn xóa “${recordCaption(item)}”? Thao tác này không thể hoàn tác.$extra',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.expenseCoral,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.repository.delete(name, widget.repository.key(name, item));
      if (mounted) {
        if (_offset > 0) _offset -= 30;
        _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.resource['title'] as String),
      actions: [
        IconButton(
          onPressed: _deleting ? null : _load,
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: singleton
        ? null
        : FloatingActionButton.extended(
            onPressed: _deleting ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: Text(managementCreateLabels[name] ?? 'Thêm mới'),
          ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _page,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ManagementErrorPanel(error: snapshot.error!, retry: _load);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = (snapshot.data!['items'] as List)
            .cast<Map<String, dynamic>>();
        final total = (snapshot.data!['total'] as num).toInt();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            if (name == 'recurring_transactions')
              const Text(
                'Lịch được lưu để quản lý; chưa tự động phát sinh giao dịch.',
              ),
            if (name.startsWith('ai_') || name == 'cashflow_forecasts')
              const Text(
                'Quản lý dữ liệu đã lưu. Chức năng này không tự tạo phản hồi hay dự báo AI.',
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '$total mục',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ),
            if (items.isEmpty)
              FinanceFormSection(
                title: 'Bắt đầu từ mục đầu tiên',
                subtitle: 'Dữ liệu bạn thêm sẽ xuất hiện tại đây.',
                child: Icon(
                  managementModuleIcons[name] ?? Icons.folder_outlined,
                  size: 40,
                  color: AppTheme.primaryForestGreen,
                ),
              ),
            for (final item in items)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.lightMintBg,
                    child: Icon(
                      managementModuleIcons[name] ?? Icons.folder_outlined,
                      color: AppTheme.primaryForestGreen,
                    ),
                  ),
                  title: Text(
                    recordCaption(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    name == 'categories' && item['user_id'] == null
                        ? 'Danh mục hệ thống · Chỉ xem'
                        : _summary(item),
                  ),
                  onTap: _deleting ? null : () => _edit(item),
                  trailing:
                      singleton ||
                          (name == 'categories' && item['user_id'] == null)
                      ? const Icon(Icons.chevron_right)
                      : PopupMenuButton<String>(
                          tooltip: 'Thao tác',
                          enabled: !_deleting,
                          onSelected: (action) =>
                              action == 'edit' ? _edit(item) : _delete(item),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Chỉnh sửa'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.expenseCoral,
                                ),
                                title: Text(
                                  'Xóa',
                                  style: TextStyle(
                                    color: AppTheme.expenseCoral,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _offset == 0 || _deleting
                      ? null
                      : () {
                          _offset -= 30;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${total == 0 ? 0 : _offset + 1}–${_offset + items.length} / $total',
                ),
                IconButton(
                  onPressed: _offset + items.length >= total || _deleting
                      ? null
                      : () {
                          _offset += 30;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  String _summary(Map<String, dynamic> item) {
    final parts = <String>[];
    for (final field in [
      'balance',
      'amount',
      'limit_amount',
      'target_amount',
      'predicted_balance',
      'status',
      'frequency',
    ]) {
      if (item[field] != null) {
        final value = '${item[field]}';
        final amount = num.tryParse(value);
        final currency = item['currency'] ?? 'VND';
        final display = managementMoneyFields.contains(field) && amount != null
            ? currency == 'VND'
                  ? '${amount < 0 ? '−' : ''}${formatVnd(amount)}'
                  : '$value $currency'
            : managementChoices[value] ?? value;
        parts.add('${managementLabels[field]}: $display');
      }
    }
    return parts.isEmpty ? 'Nhấn để xem chi tiết' : parts.join(' · ');
  }
}
