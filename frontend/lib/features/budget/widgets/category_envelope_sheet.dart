import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/budget/cubit/envelope_form_cubit.dart';
import 'package:flutter/material.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/shared/widgets/finance_form.dart';
import '../models/category_envelope_data.dart';
import '../models/envelope_pillar.dart';
import '../services/category_envelopes_service.dart';
import 'envelope_amount_field.dart';
import 'envelope_sheet_frame.dart';

class CategoryEnvelopeSheet extends StatefulWidget {
  const CategoryEnvelopeSheet({
    super.key,
    required this.service,
    required this.data,
    this.category,
    this.initialPillar = EnvelopePillar.needs,
  });
  final CategoryEnvelopesService service;
  final CategoryEnvelopeData data;
  final FinanceRecord? category;
  final EnvelopePillar initialPillar;
  @override
  State<CategoryEnvelopeSheet> createState() => _CategoryEnvelopeSheetState();
}

class _CategoryEnvelopeSheetState extends State<CategoryEnvelopeSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.category?['name'] as String? ?? '',
  );
  late final _limit = TextEditingController(text: _initialAmount());
  late EnvelopePillar _pillar =
      EnvelopePillar.fromKey(widget.category?['pillar']) ??
      widget.initialPillar;
  late final _cubit = EnvelopeFormCubit(widget.service, widget.data);
  bool get _busy => _cubit.state.busy;
  String? get _error => _cubit.state.error;
  bool get _system =>
      widget.category != null && widget.category!['user_id'] == null;

  String _initialAmount() {
    final id = widget.category?['id'] as int?;
    final budget = id == null ? null : widget.data.budgetFor(categoryId: id);
    return budget == null
        ? ''
        : envelopeAmountText(financeAmount(budget['limit_amount']));
  }

  Future<void> _save() async {
    if (_busy || !validateFinanceForm(_form)) return;
    await _cubit.saveCategory(
      category: widget.category,
      name: _name.text.trim(),
      pillar: _pillar,
      limit: _limit.text.trim().isEmpty
          ? null
          : '${envelopeAmount(_limit.text)}',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
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
    title: widget.category == null
        ? 'Tạo danh mục mới'
        : _system
        ? 'Chỉnh sửa phong bao'
        : 'Chỉnh sửa danh mục',
    busy: _busy,
    onClose: _busy ? null : () => Navigator.pop(context),
    onSave: _busy ? null : _save,
    saveLabel: _system ? 'Lưu hạn mức' : 'Lưu danh mục',
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_system)
            const Text(
              'Danh mục hệ thống chỉ đọc. Bạn có thể đặt hạn mức riêng cho tháng này.',
              style: TextStyle(
                color: EnvelopeStyle.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          const EnvelopeFieldLabel('Tên danh mục'),
          TextFormField(
            key: const ValueKey('envelope-name'),
            controller: _name,
            enabled: !_busy && !_system,
            maxLength: 500,
            textInputAction: TextInputAction.next,
            decoration: envelopeInput(
              'Ví dụ: Tập gym, Trà chiều...',
            ).copyWith(counterText: ''),
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Vui lòng nhập tên danh mục.'
                : null,
          ),
          const EnvelopeFieldLabel('Trụ cột Kakeibo'),
          for (var row = 0; row < 2; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (var col = 0; col < 2; col++) ...[
                    if (col > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _pillarButton(
                        EnvelopePillar.values[row * 2 + col],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          EnvelopeFieldLabel(
            'Hạn mức tháng ${widget.data.month.month}/${widget.data.month.year} (VNĐ)',
          ),
          EnvelopeAmountField(
            controller: _limit,
            optional: true,
            enabled: !_busy,
            helperText: widget.category == null
                ? null
                : 'Để trống để tắt phong bao của tháng này.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _pillarButton(EnvelopePillar pillar) {
    final selected =
        pillar == _pillar &&
        !(_system &&
            EnvelopePillar.fromKey(widget.category?['pillar']) == null);
    return Semantics(
      selected: selected,
      child: FilledButton(
        key: ValueKey('select-${pillar.key}'),
        onPressed: _busy || _system
            ? null
            : () => setState(() => _pillar = pillar),
        style: FilledButton.styleFrom(
          backgroundColor: selected
              ? EnvelopeStyle.primary
              : EnvelopeStyle.border,
          foregroundColor: selected ? Colors.white : EnvelopeStyle.ink,
          disabledBackgroundColor: selected
              ? EnvelopeStyle.primary
              : EnvelopeStyle.border,
          disabledForegroundColor: selected
              ? Colors.white
              : EnvelopeStyle.muted,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text('${pillar.index + 1}. ${pillar.shortLabel}'),
      ),
    );
  }
}
