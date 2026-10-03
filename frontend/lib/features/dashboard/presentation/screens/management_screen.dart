import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../finance/domain/repositories/management_repository.dart';

/// Reuse the authenticated CRUD forms from the existing feature screens.
Future<void> openFinanceModule(
  BuildContext context,
  String name, {
  bool create = false,
  Map<String, dynamic>? record,
  Map<String, dynamic> defaults = const {},
  ManagementRepository? repository,
}) async {
  final source = repository ?? AppDependencies.managementRepository;
  try {
    final resources = await source.resources();
    final resource = resources.firstWhere((item) => item['name'] == name);
    Map<String, dynamic>? fresh;
    if (record != null || name == 'profile') {
      fresh = await source.get(
        name,
        name == 'profile' ? 'me' : source.key(name, record!),
      );
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => create || fresh != null
            ? _RecordForm(
                resource: resource,
                repository: source,
                record: fresh,
                initialValues: defaults,
              )
            : _ResourceList(resource: resource, repository: source),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

const _labels = <String, String>{
  'name': 'Tên',
  'account_type': 'Loại tài khoản',
  'balance': 'Số dư',
  'currency': 'Tiền tệ',
  'icon': 'Biểu tượng',
  'color': 'Màu sắc',
  'account_number': 'Số tài khoản / thẻ',
  'institution_name': 'Ngân hàng / tổ chức',
  'credit_limit': 'Hạn mức tín dụng',
  'statement_day': 'Ngày chốt sao kê',
  'payment_due_day': 'Ngày đến hạn',
  'is_included_in_total': 'Tính vào tổng tài sản',
  'is_archived': 'Lưu trữ ví',
  'parent_id': 'Danh mục cha',
  'is_income': 'Danh mục thu nhập',
  'pillar': 'Trụ cột Kakeibo',
  'display_order': 'Thứ tự hiển thị',
  'transaction_id': 'Giao dịch',
  'tag_id': 'Thẻ',
  'category_id': 'Danh mục',
  'month_year': 'Tháng ngân sách (ngày đầu tháng)',
  'limit_amount': 'Hạn mức',
  'alert_threshold_percent': 'Ngưỡng cảnh báo (%)',
  'account_id': 'Ví',
  'target_amount': 'Số tiền mục tiêu',
  'current_amount': 'Đã tiết kiệm',
  'target_date': 'Ngày mục tiêu',
  'status': 'Trạng thái',
  'notes': 'Ghi chú',
  'type': 'Loại khoản nợ',
  'person_name': 'Người / tổ chức',
  'phone_number': 'Số điện thoại',
  'amount': 'Số tiền',
  'paid_amount': 'Đã thanh toán',
  'due_date': 'Hạn thanh toán',
  'interest_rate': 'Lãi suất (% / năm)',
  'transaction_type': 'Loại giao dịch',
  'description': 'Mô tả',
  'frequency': 'Chu kỳ',
  'start_date': 'Ngày bắt đầu',
  'end_date': 'Ngày kết thúc',
  'next_execution_date': 'Ngày thực hiện tiếp theo',
  'auto_create': 'Tự tạo khi đến hạn',
  'is_active': 'Đang hoạt động',
  'forecast_date': 'Ngày dự báo',
  'predicted_balance': 'Số dư dự báo',
  'predicted_income': 'Thu nhập dự báo',
  'predicted_expense': 'Chi tiêu dự báo',
  'lower_bound': 'Cận dưới',
  'upper_bound': 'Cận trên',
  'risk_level': 'Mức rủi ro',
  'model_name': 'Mô hình',
  'alert_type': 'Loại cảnh báo',
  'severity': 'Mức độ',
  'title': 'Tiêu đề',
  'message': 'Nội dung',
  'predicted_deficit_date': 'Ngày thiếu hụt dự báo',
  'predicted_deficit_amount': 'Số tiền thiếu hụt',
  'suggested_action': 'Đề xuất',
  'is_read': 'Đã đọc',
  'is_resolved': 'Đã xử lý',
  'user_query': 'Câu hỏi',
  'context_summary': 'Bối cảnh tư vấn',
  'ai_recommendation': 'Nội dung tư vấn',
  'session_id': 'Cuộc trò chuyện',
  'sender': 'Người gửi',
  'content': 'Tin nhắn',
  'context_snapshot': 'Bối cảnh tin nhắn',
  'full_name': 'Họ tên',
  'avatar_url': 'Đường dẫn ảnh đại diện',
  'payroll_day': 'Ngày nhận lương',
  'monthly_savings_target': 'Mục tiêu tiết kiệm mỗi tháng',
  'reminder_time': 'Giờ nhắc nhở',
  'biometrics_enabled': 'Sinh trắc học',
  'dark_mode_enabled': 'Chế độ tối',
  'current_balance': 'Số dư hiện tại',
  'monthly_income': 'Thu nhập tháng',
  'monthly_expense': 'Chi tiêu tháng',
  'burn_rate': 'Mức chi tiêu mỗi ngày',
  'days_to_payroll': 'Số ngày tới kỳ lương',
};
const _choices = <String, String>{
  'cash': 'Tiền mặt',
  'bank': 'Ngân hàng',
  'e_wallet': 'Ví điện tử',
  'credit_card': 'Thẻ tín dụng',
  'investment': 'Đầu tư',
  'savings': 'Tiết kiệm',
  'needs': 'Thiết yếu',
  'wants': 'Mong muốn',
  'culture': 'Văn hóa',
  'unexpected': 'Dự phòng',
  'income': 'Thu nhập',
  'expense': 'Chi tiêu',
  'in_progress': 'Đang thực hiện',
  'completed': 'Hoàn thành',
  'cancelled': 'Đã hủy',
  'debt': 'Đi vay',
  'loan': 'Cho vay',
  'pending': 'Chưa thanh toán',
  'partial': 'Thanh toán một phần',
  'paid': 'Đã thanh toán',
  'overdue': 'Quá hạn',
  'daily': 'Hàng ngày',
  'weekly': 'Hàng tuần',
  'biweekly': 'Hai tuần',
  'monthly': 'Hàng tháng',
  'quarterly': 'Hàng quý',
  'yearly': 'Hàng năm',
  'safe': 'An toàn',
  'warning': 'Cảnh báo',
  'danger': 'Nguy hiểm',
  'info': 'Thông tin',
  'critical': 'Nghiêm trọng',
  'deficit_risk': 'Nguy cơ thiếu hụt',
  'budget_exceeded': 'Vượt ngân sách',
  'unusual_expense': 'Chi tiêu bất thường',
  'low_balance': 'Số dư thấp',
  'bill_due': 'Hóa đơn đến hạn',
  'user': 'Bạn',
  'assistant': 'Trợ lý',
  'system': 'Hệ thống',
};
const _relations = <String, String>{
  'account_id': 'accounts',
  'category_id': 'categories',
  'parent_id': 'categories',
  'transaction_id': 'transactions',
  'tag_id': 'tags',
  'session_id': 'ai_chat_sessions',
};

String _caption(Map<String, dynamic> item) {
  for (final field in [
    'name',
    'title',
    'person_name',
    'description',
    'clean_description',
    'raw_description',
    'user_query',
    'content',
    'full_name',
    'email',
    'forecast_date',
    'month_year',
  ]) {
    if (item[field] != null && '${item[field]}'.isNotEmpty) {
      return '${item[field]}';
    }
  }
  if (item.containsKey('transaction_id')) {
    return 'Giao dịch #${item['transaction_id']} · Thẻ #${item['tag_id']}';
  }
  return 'Bản ghi #${item['id']}';
}

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key, this.repository});
  final ManagementRepository? repository;
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  late final _repository =
      widget.repository ?? AppDependencies.managementRepository;
  late Future<List<Map<String, dynamic>>> _resources = _repository.resources();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý tài chính')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _resources,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
            error: snapshot.error!,
            retry: () => setState(() {
              _resources = _repository.resources();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Dữ liệu của bạn',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryForestGreen,
              ),
            ),
            const SizedBox(height: 12),
            for (final resource in snapshot.data!)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.folder_outlined,
                    color: AppTheme.primaryForestGreen,
                  ),
                  title: Text(resource['title'] as String),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ResourceList(
                        resource: resource,
                        repository: _repository,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

class _ResourceList extends StatefulWidget {
  const _ResourceList({required this.resource, required this.repository});
  final Map<String, dynamic> resource;
  final ManagementRepository repository;
  @override
  State<_ResourceList> createState() => _ResourceListState();
}

class _ResourceListState extends State<_ResourceList> {
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
          builder: (_) => _RecordForm(
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
        title: const Text('Xóa bản ghi?'),
        content: Text('${_caption(item)}$extra'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: singleton
        ? null
        : FloatingActionButton.extended(
            onPressed: _deleting ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Thêm mới'),
          ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _page,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(error: snapshot.error!, retry: _load);
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
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Chưa có dữ liệu.'),
              ),
            for (final item in items)
              Card(
                child: ListTile(
                  title: Text(
                    _caption(item),
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
                      ? null
                      : IconButton(
                          tooltip: 'Xóa',
                          onPressed: _deleting ? null : () => _delete(item),
                          icon: const Icon(Icons.delete_outline),
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
        parts.add(
          '${_labels[field]}: ${_choices['${item[field]}'] ?? item[field]}',
        );
      }
    }
    return parts.isEmpty ? 'Nhấn để xem chi tiết' : parts.join(' · ');
  }
}

class _RecordForm extends StatefulWidget {
  const _RecordForm({
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
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
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
    _loading = _loadReferences();
  }

  Future<void> _loadReferences() async {
    final targets = _properties.keys
        .where(_relations.containsKey)
        .map((key) => _relations[key]!)
        .toSet();
    for (final target in targets) {
      _options[target] = await widget.repository.references(target);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final data = <String, dynamic>{};
    for (final entry in _properties.entries) {
      final key = entry.key;
      final raw = entry.value as Map;
      final type = _type(raw);
      if (type['type'] == 'boolean' ||
          type['enum'] != null ||
          _relations.containsKey(key)) {
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
      if (mounted) setState(() => _error = '$error');
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
    final label = _labels[key] ?? key;
    final nullable = _nullable(raw);
    final disabled = _busy || _readOnly;
    if (type['type'] == 'boolean') {
      return SwitchListTile(
        title: Text(label),
        value: _values[key] == true,
        onChanged: disabled ? null : (value) => _choose(key, value),
      );
    }
    final relation = _relations[key];
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
          choices[item['id']] = _caption(item);
        }
      } else {
        for (final value in type['enum'] as List) {
          if (name == 'categories' &&
              key == 'pillar' &&
              ((value == 'income') != (_values['is_income'] == true))) {
            continue;
          }
          choices[value] = _choices['$value'] ?? '$value';
        }
      }
      if (_values[key] != null && !choices.containsKey(_values[key])) {
        choices[_values[key]] = 'Đã lưu #${_values[key]}';
      }
      return DropdownButtonFormField<dynamic>(
        key: ValueKey('$key:${_values[key]}'),
        initialValue: _values[key],
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
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
      controller: _controllers[key],
      enabled: !disabled,
      readOnly: isDate || isTime,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
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
      decoration: InputDecoration(
        labelText: label,
        helperText: numeric && type['type'] == 'number'
            ? 'Nhập số, ví dụ 150000 hoặc 150000,50'
            : type['type'] == 'object'
            ? 'Ghi chú bổ sung; thông tin bối cảnh đã lưu được giữ lại.'
            : null,
        suffixIcon: isDate || isTime
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (nullable && !disabled)
                    IconButton(
                      onPressed: () =>
                          setState(() => _controllers[key]!.clear()),
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
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    DateTime.tryParse(_controllers[key]!.text) ??
                    DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
              );
              if (picked != null && mounted) {
                setState(
                  () => _controllers[key]!.text =
                      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
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
        final text = (value ?? '').trim();
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
                  '${_labels['${entry.key}'] ?? entry.key}: ${_contextValue(entry.value)}',
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
                '${_labels['${entry.key}'] ?? entry.key}: ${_contextValue(entry.value)}',
          )
          .join(' · ');
    }
    if (value is List) return value.map(_contextValue).join(', ');
    return '$value';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${_readOnly
            ? 'Xem'
            : widget.record == null
            ? 'Thêm'
            : 'Sửa'} ${widget.resource['title']}',
      ),
    ),
    body: FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
            error: snapshot.error!,
            retry: () => setState(() => _loading = _loadReferences()),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_readOnly)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Danh mục mặc định của hệ thống chỉ được xem.'),
                ),
              for (final entry in _properties.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _field(entry.key, entry.value as Map),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (!_readOnly)
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu thay đổi'),
                ),
            ],
          ),
        );
      },
    ),
  );
}
