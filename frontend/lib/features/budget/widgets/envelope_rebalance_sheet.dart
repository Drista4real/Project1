import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/budget/cubit/envelope_form_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_one/shared/widgets/finance_form.dart';
import '../models/category_envelope_data.dart';
import '../models/envelope_pillar.dart';
import '../services/category_envelopes_service.dart';
import 'envelope_amount_field.dart';
import 'envelope_sheet_frame.dart';

class EnvelopeRebalanceSheet extends StatefulWidget {
  const EnvelopeRebalanceSheet({
    super.key,
    required this.service,
    required this.data,
  });
  final CategoryEnvelopesService service;
  final CategoryEnvelopeData data;
  @override
  State<EnvelopeRebalanceSheet> createState() => _EnvelopeRebalanceSheetState();
}

class _EnvelopeRebalanceSheetState extends State<EnvelopeRebalanceSheet> {
  final _form = GlobalKey<FormState>();
  late final _total = TextEditingController(
    text: widget.data.totalLimit > 0
        ? envelopeAmountText(widget.data.totalLimit)
        : widget.data.allocated > 0
        ? envelopeAmountText(widget.data.allocated)
        : '',
  );
  late final _percent = List.generate(
    4,
    (i) => TextEditingController(text: '${widget.data.roundedPercentages[i]}'),
  );
  late final _cubit = EnvelopeFormCubit(widget.service, widget.data);
  bool get _busy => _cubit.state.busy;
  String? get _error => _cubit.state.error;
  List<int> get _values =>
      _percent.map((c) => int.tryParse(c.text) ?? 0).toList();
  int get _sum => _values.fold(0, (a, b) => a + b);

  Future<void> _save() async {
    if (_busy || !validateFinanceForm(_form)) return;
    await _cubit.rebalance(envelopeAmount(_total.text)!, _values);
  }

  @override
  void dispose() {
    _total.dispose();
    for (final c in _percent) {
      c.dispose();
    }
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<EnvelopeFormCubit, EnvelopeFormState>(
        bloc: _cubit,
        listenWhen: (previous, current) => !previous.saved && current.saved,
        listener: (context, state) => Navigator.pop(context, true),
        builder: (context, state) => _buildContent(context),
      );

  Widget _buildContent(BuildContext context) => EnvelopeSheetFrame(
    title: 'Tái cân bằng phong bao',
    saveLabel: 'Lưu phân bổ',
    busy: _busy,
    onSave: _busy ? null : _save,
    onClose: _busy ? null : () => Navigator.pop(context),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phân chia ngân sách tháng ${widget.data.month.month}/${widget.data.month.year} theo 4 trụ cột. Hạn mức riêng của danh mục được giữ nguyên.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: EnvelopeStyle.muted,
            ),
          ),
          const EnvelopeFieldLabel('Ngân sách tháng (VNĐ)'),
          EnvelopeAmountField(
            controller: _total,
            enabled: !_busy,
            fieldKey: 'rebalance-total',
          ),
          const SizedBox(height: 12),
          for (final pillar in EnvelopePillar.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: pillar.tint,
                    child: Text(
                      '${pillar.index + 1}',
                      style: TextStyle(fontSize: 12, color: pillar.color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pillar.title,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: TextFormField(
                      key: ValueKey('percent-${pillar.key}'),
                      controller: _percent[pillar.index],
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: envelopeInput('0').copyWith(suffixText: '%'),
                      validator: (v) =>
                          int.tryParse(v ?? '') == null || int.parse(v!) > 100
                          ? '0–100%'
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Tổng phân bổ: $_sum%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _sum == 100
                  ? EnvelopeStyle.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
