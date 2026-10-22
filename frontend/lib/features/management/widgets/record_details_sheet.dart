import 'package:flutter/material.dart';
import 'package:project_one/features/management/config/management_metadata.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';

enum RecordAction { edit, delete, initialIncome }

/// Read a record without entering a form or accidentally changing a value.
class RecordDetailsSheet extends StatelessWidget {
  const RecordDetailsSheet({
    super.key,
    required this.resource,
    required this.record,
    required this.references,
    required this.readOnly,
  });
  final Map<String, dynamic> resource;
  final Map<String, dynamic> record;
  final Map<String, String> references;
  final bool readOnly;

  String _value(String field, dynamic value) {
    if (references.containsKey(field)) return references[field]!;
    if (value is bool) return value ? 'Có' : 'Không';
    if (managementRelations.containsKey(field)) return 'Liên kết đã lưu';
    if (managementMoneyFields.contains(field)) {
      final amount = num.tryParse('$value');
      if (amount != null) {
        return record['currency'] == null || record['currency'] == 'VND'
            ? '${amount < 0 ? '−' : ''}${formatVnd(amount)}'
            : '$value ${record['currency']}';
      }
    }
    if (field.contains('date') || field == 'month_year') {
      final date = DateTime.tryParse('$value')?.toLocal();
      if (date != null) return '${date.day}/${date.month}/${date.year}';
    }
    if (value is Map) {
      return value.entries
          .map(
            (e) =>
                '${managementLabels['${e.key}'] ?? e.key}: ${_value('${e.key}', e.value)}',
          )
          .join('\n');
    }
    if (value is List) return value.map((v) => _value(field, v)).join(', ');
    return managementChoices['$value'] ?? '$value';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fields = Map<String, dynamic>.from(
      (resource['schema'] as Map)['properties'] as Map,
    );
    // Appearance codes are represented visually; device opt-ins live in Settings.
    fields.removeWhere(
      (key, _) => {
        'icon',
        'color',
        'reminder_time',
        'dark_mode_enabled',
        'biometrics_enabled',
        'record_initial_income',
        'client_request_id',
      }.contains(key),
    );
    if (resource['name'] == 'accounts' &&
        record['account_type'] != 'credit_card') {
      fields.removeWhere(
        (key, _) =>
            {'credit_limit', 'statement_day', 'payment_due_day'}.contains(key),
      );
    }
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          managementTitle(resource),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resource['name'] == 'transaction_tags'
                              ? '${references['tag_id'] ?? 'Thẻ'} · ${references['transaction_id'] ?? 'Giao dịch'}'
                              : recordCaption(record),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng chi tiết',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (readOnly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text('Dữ liệu của hệ thống · Chỉ xem'),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final field in fields.keys)
                      if (record[field] != null &&
                          '${record[field]}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                managementLabels[field] ?? field,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                _value(field, record[field]),
                                style: TextStyle(
                                  fontSize:
                                      managementMoneyFields.contains(field)
                                      ? 18
                                      : 14,
                                  fontWeight:
                                      managementMoneyFields.contains(field)
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
            if (!readOnly)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (resource['name'] == 'accounts' &&
                        record['is_archived'] != true &&
                        record['initial_income_request_id'] == null &&
                        (num.tryParse('${record['balance']}') ?? 0) > 0)
                      OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pop(context, RecordAction.initialIncome),
                        icon: const Icon(Icons.add_chart),
                        label: const Text('Ghi nhận số dư ban đầu là thu nhập'),
                      ),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, RecordAction.edit),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Chỉnh sửa'),
                    ),
                    if (resource['singleton'] != true)
                      TextButton.icon(
                        onPressed: () =>
                            Navigator.pop(context, RecordAction.delete),
                        icon: Icon(Icons.delete_outline, color: colors.error),
                        label: Text(
                          'Xóa',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
