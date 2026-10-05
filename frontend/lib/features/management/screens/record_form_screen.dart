import 'package:flutter/material.dart';

import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/shared/widgets/finance_form.dart';
import 'package:project_one/features/management/config/management_metadata.dart';
import 'package:project_one/features/management/widgets/management_error_panel.dart';

class RecordFormScreen extends StatefulWidget {
  const RecordFormScreen({
    super.key,
    required this.resource,
    required this.repository,
    this.record,
    this.initialValues = const {},
  });
  final Map<String, dynamic> resource;
  final ManagementRepository repository;
  final Map<String, dynamic>? record;
  final Map<String, dynamic> initialValues;
  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _values = <String, dynamic>{};
  final _options = <String, List<Map<String, dynamic>>>{};
  late final Map<String, dynamic> _schema = Map<String, dynamic>.from(
    widget.resource['schema'] as Map,
  );
  late final Map<String, dynamic> _properties = Map<String, dynamic>.from(
    _schema['properties'] as Map,
  );
  late Future<void> _loading;
  bool _busy = false;
  bool _ready = false;
  String? _error;
  String get name => widget.resource['name'] as String;
  bool get _readOnly =>
      name == 'categories' &&
      widget.record != null &&
      widget.record!['user_id'] == null;

  Map<String, dynamic> _type(Map raw) {
    if (raw['anyOf'] is List) {
      return Map<String, dynamic>.from(
        (raw['anyOf'] as List).firstWhere((entry) => entry['type'] != 'null')
            as Map,
      );
    }
    return Map<String, dynamic>.from(raw);
  }

  bool _nullable(Map raw) =>
      (raw['anyOf'] as List?)?.any((entry) => entry['type'] == 'null') ?? false;

  @override
  void initState() {
    super.initState();
    for (final entry in _properties.entries) {
      final raw = entry.value as Map;
      final value = widget.record == null
          ? widget.initialValues[entry.key] ?? raw['default']
          : widget.record![entry.key];
      _values[entry.key] = value;
      _controllers[entry.key] = TextEditingController(
        text: value == null
            ? ''
            : value is Map
            ? '${value['ghi_chu'] ?? ''}'
            : '$value',
      );
    }
    if (name == 'budgets' && _controllers['month_year']!.text.isEmpty) {
      final now = DateTime.now();
      _controllers['month_year']!.text =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    }
    _loading = _loadReferences();
  }

  Future<void> _loadReferences() async {
    _ready = false;
    final targets = _properties.keys
        .where(managementRelations.containsKey)
        .map((key) => managementRelations[key]!)
        .toSet();
    for (final target in targets) {
      _options[target] = await widget.repository.references(target);
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !validateFinanceForm(_form)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final data = <String, dynamic>{};
    for (final entry in _properties.entries) {
      final key = entry.key;
      final raw = entry.value as Map;
      final type = _type(raw);
      if (type['type'] == 'boolean' ||
          type['enum'] != null ||
          managementRelations.containsKey(key)) {
        data[key] = _values[key];
      } else {
        final text = _controllers[key]!.text.trim();
        if (type['type'] == 'object') {
          final existing = _values[key];
          final context = existing is Map
              ? Map<String, dynamic>.from(existing)
              : <String, dynamic>{};
          if (text.isEmpty) {
            context.remove('ghi_chu');
          } else {
            context['ghi_chu'] = text;
          }
          data[key] = context.isEmpty ? null : context;
          continue;
        }
        if (text.isEmpty && _nullable(raw)) {
          data[key] = null;
          continue;
        }
        data[key] = type['type'] == 'integer'
            ? int.parse(text)
            : type['type'] == 'number'
            ? text.replaceAll(',', '.')
            : text;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        name,
        data,
        key: widget.record == null
            ? null
            : widget.repository.key(name, widget.record!),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lưu dữ liệu: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _choose(String field, dynamic value) {
    setState(() {
      _values[field] = value;
      if (field == 'is_income') {
        _values['pillar'] = value == true ? 'income' : 'needs';
        _values['parent_id'] = null;
      }
      if (field == 'transaction_type') {
        _values['category_id'] = null;
      }
      if (name == 'budgets' && value != null) {
        if (field == 'category_id') {
          _values['pillar'] = null;
        }
        if (field == 'pillar') {
          _values['category_id'] = null;
        }
      }
    });
  }

  Widget _field(String key, Map raw) {
    final type = _type(raw);
    final nullable = _nullable(raw);
    final label =
        '${managementLabels[key] ?? key}${nullable || type['type'] == 'boolean' ? '' : ' *'}';
    final disabled = _busy || _readOnly;
    if (key == 'icon') {
      final current = _controllers[key]!.text;
      return DropdownButtonFormField<String>(
        initialValue: current.isEmpty ? null : current,
        isExpanded: true,
        decoration: financeInputDecoration(label),
        items: [
          for (final entry in managementAppearanceIcons.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Row(
                children: [
                  Icon(
                    entry.value,
                    size: 20,
                    color: AppTheme.primaryForestGreen,
                  ),
                  const SizedBox(width: 10),
                  Text(managementIconLabels[entry.key]!),
                ],
              ),
            ),
          if (current.isNotEmpty &&
              !managementAppearanceIcons.containsKey(current))
            DropdownMenuItem(
              value: current,
              child: const Text('Biểu tượng hiện tại'),
            ),
        ],
        onChanged: disabled
            ? null
            : (value) => setState(() => _controllers[key]!.text = value!),
        validator: (value) => value == null ? 'Vui lòng chọn biểu tượng' : null,
      );
    }
    if (type['type'] == 'boolean') {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: _values[key] == true,
        onChanged: disabled ? null : (value) => _choose(key, value),
      );
    }
    final relation = managementRelations[key];
    if (relation != null || type['enum'] is List) {
      final choices = <dynamic, String>{};
      if (relation != null) {
        for (final item in _options[relation] ?? <Map<String, dynamic>>[]) {
          if (relation == 'categories') {
            final expectedIncome = name == 'categories'
                ? _values['is_income'] == true
                : _values['transaction_type'] == 'income';
            if (item['is_income'] != expectedIncome &&
                item['id'] != _values[key]) {
              continue;
            }
          }
          if (key == 'parent_id' && item['id'] == widget.record?['id']) {
            continue;
          }
          if (relation == 'accounts' &&
              item['is_archived'] == true &&
              item['id'] != _values[key]) {
            continue;
          }
          choices[item['id']] = recordCaption(item);
        }
      } else {
        for (final value in type['enum'] as List) {
          if (name == 'categories' &&
              key == 'pillar' &&
              ((value == 'income') != (_values['is_income'] == true))) {
            continue;
          }
          choices[value] = managementChoices['$value'] ?? '$value';
        }
      }
      if (_values[key] != null && !choices.containsKey(_values[key])) {
        choices[_values[key]] = 'Đã lưu #${_values[key]}';
      }
      return DropdownButtonFormField<dynamic>(
        key: ValueKey('$key:${_values[key]}'),
        initialValue: _values[key],
        isExpanded: true,
        decoration: financeInputDecoration(
          label,
          helper: name == 'budgets' && key == 'category_id'
              ? 'Để trống danh mục và trụ cột nếu muốn đặt ngân sách tổng.'
              : null,
        ),
        items: [
          if (nullable)
            const DropdownMenuItem(value: null, child: Text('Không chọn')),
          for (final entry in choices.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: disabled ? null : (value) => _choose(key, value),
        validator: (value) =>
            value == null && !nullable ? 'Vui lòng chọn $label' : null,
      );
    }
    final isDate = type['format'] == 'date';
    final isTime = type['format'] == 'time';
    final numeric = type['type'] == 'integer' || type['type'] == 'number';
    final input = TextFormField(
      key: isDate || isTime
          ? ValueKey('$key:${_controllers[key]!.text}')
          : ValueKey(key),
      controller: isDate || isTime ? null : _controllers[key],
      initialValue: isDate || isTime ? _dateLabel(key, isTime: isTime) : null,
      enabled: !disabled,
      readOnly: isDate || isTime,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : key == 'phone_number'
          ? TextInputType.phone
          : null,
      textInputAction: TextInputAction.next,
      onChanged: key == 'color' || key == 'currency'
          ? (_) => setState(() {})
          : null,
      minLines:
          [
                'notes',
                'message',
                'content',
                'user_query',
                'ai_recommendation',
              ].contains(key) ||
              type['type'] == 'object'
          ? 3
          : 1,
      maxLines: type['type'] == 'object'
          ? 8
          : [
              'notes',
              'message',
              'content',
              'user_query',
              'ai_recommendation',
            ].contains(key)
          ? 6
          : 1,
      decoration: financeInputDecoration(
        label,
        helper: numeric && type['type'] == 'number'
            ? 'Nhập số, ví dụ 150000 hoặc 150000,50'
            : type['type'] == 'object'
            ? 'Ghi chú bổ sung; thông tin bối cảnh đã lưu được giữ lại.'
            : null,
        suffixText: managementMoneyFields.contains(key)
            ? (_controllers['currency']?.text ?? 'VND') == 'VND'
                  ? '₫'
                  : _controllers['currency']!.text
            : key.contains('percent') || key == 'interest_rate'
            ? '%'
            : null,
        suffix: isDate || isTime
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (nullable && !disabled)
                    IconButton(
                      onPressed: () =>
                          setState(() => _controllers[key]!.clear()),
                      tooltip: 'Bỏ chọn',
                      icon: const Icon(Icons.clear),
                    ),
                  Icon(isDate ? Icons.calendar_month : Icons.schedule),
                  const SizedBox(width: 12),
                ],
              )
            : null,
      ),
      onTap: disabled
          ? null
          : isDate
          ? () async {
              final DateTime? picked;
              if (key == 'month_year') {
                picked = await _pickMonth();
              } else {
                picked = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.tryParse(_controllers[key]!.text) ??
                      DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2200),
                );
              }
              if (picked != null && mounted) {
                final date = picked;
                setState(
                  () => _controllers[key]!.text =
                      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                );
              }
            }
          : isTime
          ? () async {
              final parts = _controllers[key]!.text.split(':');
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: int.tryParse(parts.first) ?? 20,
                  minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30,
                ),
              );
              if (picked != null && mounted) {
                setState(
                  () => _controllers[key]!.text =
                      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00',
                );
              }
            }
          : null,
      validator: (value) {
        final text = (isDate || isTime ? _controllers[key]!.text : value ?? '')
            .trim();
        if (text.isEmpty) return nullable ? null : 'Vui lòng nhập $label';
        if (type['type'] == 'integer' && int.tryParse(text) == null) {
          return 'Nhập số nguyên';
        }
        if (type['type'] == 'number' &&
            !RegExp(r'^-?\d+(?:[.,]\d{1,2})?$').hasMatch(text)) {
          return 'Nhập số với tối đa 2 chữ số thập phân';
        }
        if (type['pattern'] != null &&
            !RegExp(type['pattern'] as String).hasMatch(text)) {
          return 'Giá trị không đúng định dạng';
        }
        if (type['maxLength'] != null &&
            text.length > (type['maxLength'] as num)) {
          return 'Nội dung quá dài';
        }
        if (isDate &&
            key == 'month_year' &&
            DateTime.tryParse(text)?.day != 1) {
          return 'Chọn ngày đầu tháng';
        }
        if (numeric) {
          final number = num.tryParse(text.replaceAll(',', '.'));
          if (number != null &&
              type['minimum'] != null &&
              number < (type['minimum'] as num)) {
            return 'Giá trị quá nhỏ';
          }
          if (number != null &&
              type['exclusiveMinimum'] != null &&
              number <= (type['exclusiveMinimum'] as num)) {
            return 'Giá trị phải lớn hơn ${type['exclusiveMinimum']}';
          }
          if (number != null &&
              type['maximum'] != null &&
              number > (type['maximum'] as num)) {
            return 'Giá trị quá lớn';
          }
        }
        return null;
      },
    );
    if (key == 'color') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in [
                '#2D5A43',
                '#10B981',
                '#4E9F86',
                '#D96B43',
                '#F59E0B',
                '#64748B',
                '#8B5CF6',
                '#3ECF8E',
              ])
                Semantics(
                  label: 'Màu $hex',
                  selected: _controllers[key]!.text.toUpperCase() == hex,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: disabled
                        ? null
                        : () => setState(() => _controllers[key]!.text = hex),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(hex.substring(1), radix: 16) + 0xFF000000,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: _controllers[key]!.text.toUpperCase() == hex
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          input,
        ],
      );
    }
    final savedContext = _values[key];
    if (type['type'] == 'object' &&
        savedContext is Map &&
        savedContext.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in savedContext.entries)
            if (entry.key != 'ghi_chu')
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${managementLabels['${entry.key}'] ?? entry.key}: ${_contextValue(entry.value)}',
                ),
              ),
          input,
        ],
      );
    }
    return input;
  }

  String _contextValue(dynamic value) {
    if (value == null) return 'Chưa có';
    if (value is bool) return value ? 'Có' : 'Không';
    if (value is Map) {
      return value.entries
          .map(
            (entry) =>
                '${managementLabels['${entry.key}'] ?? entry.key}: ${_contextValue(entry.value)}',
          )
          .join(' · ');
    }
    if (value is List) return value.map(_contextValue).join(', ');
    return '$value';
  }

  String _dateLabel(String key, {bool isTime = false}) {
    final text = _controllers[key]!.text;
    if (text.isEmpty) return '';
    if (isTime) return text.length >= 5 ? text.substring(0, 5) : text;
    final date = DateTime.tryParse(text);
    if (date == null) return text;
    return key == 'month_year'
        ? '${date.month.toString().padLeft(2, '0')}/${date.year}'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<DateTime?> _pickMonth() async {
    final current =
        DateTime.tryParse(_controllers['month_year']!.text) ?? DateTime.now();
    var year = current.year;
    var month = current.month;
    return showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Chọn tháng ngân sách'),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: year,
                    decoration: financeInputDecoration('Năm'),
                    items: [
                      for (var y = 1900; y <= 2200; y++)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (value) => update(() => year = value!),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var m = 1; m <= 12; m++)
                        ChoiceChip(
                          label: Text('Tháng $m'),
                          selected: m == month,
                          onSelected: (_) => update(() => month = m),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, DateTime(year, month)),
              child: const Text('Chọn tháng'),
            ),
          ],
        ),
      ),
    );
  }

  String _groupFor(String key, Map raw) {
    final type = _type(raw);
    if (['icon', 'color', 'display_order'].contains(key)) {
      return 'Hiển thị';
    }
    if (type['type'] == 'boolean' || ['currency', 'model_name'].contains(key)) {
      return 'Tùy chọn';
    }
    if (type['format'] == 'date' ||
        type['format'] == 'time' ||
        [
          'frequency',
          'statement_day',
          'payment_due_day',
          'payroll_day',
        ].contains(key)) {
      return 'Thời gian và lịch';
    }
    if (managementMoneyFields.contains(key) ||
        ['interest_rate', 'alert_threshold_percent'].contains(key)) {
      return 'Số tiền và hạn mức';
    }
    if ([
          'notes',
          'message',
          'content',
          'context_summary',
          'ai_recommendation',
          'suggested_action',
        ].contains(key) ||
        type['type'] == 'object') {
      return 'Nội dung bổ sung';
    }
    return 'Thông tin chính';
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<String>>{
      'Thông tin chính': [],
      'Số tiền và hạn mức': [],
      'Thời gian và lịch': [],
      'Nội dung bổ sung': [],
      'Hiển thị': [],
      'Tùy chọn': [],
    };
    for (final entry in _properties.entries) {
      groups[_groupFor(entry.key, entry.value as Map)]!.add(entry.key);
    }
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${_readOnly
                ? 'Xem'
                : widget.record == null
                ? 'Thêm'
                : 'Sửa'} ${widget.resource['title']}',
          ),
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back),
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
        ),
        bottomNavigationBar: _readOnly
            ? null
            : FinanceSaveBar(
                busy: _busy,
                onSave: _ready ? _save : null,
                label: widget.record == null
                    ? (managementCreateLabels[name] ?? 'Lưu dữ liệu')
                    : 'Lưu thay đổi',
              ),
        body: FutureBuilder<void>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ManagementErrorPanel(
                error: snapshot.error!,
                retry: () => setState(() => _loading = _loadReferences()),
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _form,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text(
                            _readOnly
                                ? 'Danh mục mặc định của hệ thống chỉ được xem.'
                                : 'Các trường có dấu * cần được điền trước khi lưu.',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (_error != null)
                          FinanceFormSection(
                            title: 'Chưa lưu được dữ liệu',
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppTheme.expenseCoral,
                              ),
                            ),
                          ),
                        for (final group in groups.entries)
                          if (group.value.isNotEmpty)
                            FinanceFormSection(
                              title: group.key,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (
                                    var i = 0;
                                    i < group.value.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const SizedBox(height: 18),
                                    _field(
                                      group.value[i],
                                      _properties[group.value[i]] as Map,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
