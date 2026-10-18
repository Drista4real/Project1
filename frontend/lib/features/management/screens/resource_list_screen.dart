import 'package:project_one/shared/state/async_data_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/management/cubit/resource_list_cubit.dart';
import 'package:flutter/material.dart';

import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/shared/widgets/finance_form.dart';
import 'package:project_one/features/management/config/management_metadata.dart';
import 'package:project_one/features/management/widgets/management_error_panel.dart';
import 'package:project_one/features/management/screens/record_form_screen.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import 'package:project_one/features/management/widgets/record_details_sheet.dart';
import 'package:project_one/features/management/widgets/management_theme.dart';

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
  bool get _readOnly => generatedFinanceResources.contains(name);
  bool get singleton => widget.resource['singleton'] == true;
  late final _cubit = ResourceListCubit(widget.repository, name)..refresh();
  int get _offset => _cubit.state.offset;
  bool get _deleting => _cubit.state.deleting;
  Future<void> _load() => _cubit.refresh();
  bool _opening = false;

  Future<void> _view(Map<String, dynamic> item) async {
    if (_opening || _deleting) return;
    setState(() => _opening = true);
    Map<String, dynamic> fresh;
    final references = <String, String>{};
    try {
      fresh = await widget.repository.get(
        name,
        widget.repository.key(name, item),
      );
      final fields = managementRelations.keys.where(
        (field) => fresh[field] != null,
      );
      await Future.wait(
        fields.map((field) async {
          final records = await widget.repository.references(
            managementRelations[field]!,
          );
          for (final record in records) {
            if (record['id'] == fresh[field]) {
              references[field] = recordCaption(record);
            }
          }
        }),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở chi tiết: $error')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _opening = false);
    }
    if (!mounted) return;
    final readOnly =
        _readOnly || (name == 'categories' && fresh['user_id'] == null);
    final action = await showModalBottomSheet<RecordAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => ManagementTheme(
        builder: (context) => RecordDetailsSheet(
          resource: widget.resource,
          record: fresh,
          references: references,
          readOnly: readOnly,
        ),
      ),
    );
    if (!mounted) return;
    if (action == RecordAction.edit) await _edit(fresh);
    if (action == RecordAction.delete) await _delete(fresh);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _edit([Map<String, dynamic>? record]) async {
    if (_readOnly && record == null) return;
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
    if (_readOnly || singleton) return;
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
    try {
      await _cubit.delete(item);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ManagementTheme(
    builder: (context) => BlocBuilder<ResourceListCubit, ResourceListState>(
      bloc: _cubit,
      builder: (context, state) => _buildContent(context, state),
    ),
  );

  Widget _buildContent(
    BuildContext context,
    ResourceListState state,
  ) => Scaffold(
    appBar: AppBar(
      title: Text(widget.resource['title'] as String),
      actions: [
        if (_opening)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: 'Đang mở chi tiết',
              ),
            ),
          ),
        IconButton(
          onPressed: _deleting ? null : _load,
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton:
        singleton ||
            _readOnly ||
            (state.status == DataStatus.success &&
                (state.page!['items'] as List).isEmpty)
        ? null
        : FloatingActionButton.extended(
            elevation: 0,
            onPressed: _deleting ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: Text(managementCreateLabels[name] ?? 'Thêm mới'),
          ),
    body: Builder(
      builder: (context) {
        if (state.status == DataStatus.failure) {
          return ManagementErrorPanel(error: state.error!, retry: _load);
        }
        if (state.status != DataStatus.success) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = (state.page!['items'] as List)
            .cast<Map<String, dynamic>>();
        final total = (state.page!['total'] as num).toInt();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Text(
              managementDescriptions[name] ??
                  'Xem thông tin đã lưu. Chạm vào một mục để xem chi tiết.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (name == 'recurring_transactions')
              const Text(
                'Lịch được lưu để quản lý; chưa tự động phát sinh giao dịch.',
              ),
            if (_readOnly)
              const Text(
                'Dữ liệu do hệ thống tạo · Chỉ xem. Xử lý cảnh báo tại màn Dự báo.',
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '$total mục',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (items.isEmpty)
              FinanceFormSection(
                title: _readOnly
                    ? 'Chưa có dữ liệu được lưu'
                    : 'Bắt đầu từ mục đầu tiên',
                subtitle: _readOnly
                    ? 'Dự báo và tư vấn đã lưu sẽ xuất hiện tại đây.'
                    : 'Thêm mục đầu tiên để bắt đầu theo dõi.',
                child: _readOnly
                    ? const Icon(Icons.history, size: 40)
                    : FilledButton.icon(
                        onPressed: () => _edit(),
                        icon: const Icon(Icons.add),
                        label: Text(managementCreateLabels[name] ?? 'Thêm mới'),
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
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      managementAppearanceIcons[item['icon']] ??
                          managementModuleIcons[name] ??
                          Icons.folder_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    recordCaption(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    name == 'categories' && item['user_id'] == null
                        ? 'Danh mục hệ thống · Chỉ xem'
                        : _summary(item),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  onTap: _deleting || _opening ? null : () => _view(item),
                  trailing:
                      _readOnly ||
                          singleton ||
                          (name == 'categories' && item['user_id'] == null)
                      ? const Icon(Icons.chevron_right)
                      : PopupMenuButton<String>(
                          tooltip: 'Thao tác',
                          enabled: !_deleting && !_opening,
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
            if (total > 30 || _offset > 0)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _offset == 0 || _deleting
                        ? null
                        : () => _cubit.movePage(-1),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Trước'),
                  ),
                  Text(
                    '${total == 0 ? 0 : _offset + 1}–${_offset + items.length} / $total',
                  ),
                  TextButton.icon(
                    onPressed: _offset + items.length >= total || _deleting
                        ? null
                        : () => _cubit.movePage(1),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Tiếp'),
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
