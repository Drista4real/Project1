import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/budget/widgets/envelope_amount_field.dart';
import 'package:project_one/features/onboarding/cubit/monthly_setup_cubit.dart';
import 'package:project_one/features/plan/widgets/plan_widgets.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';

/// The question and helper text of every setup step.
({String title, String? subtitle}) setupStepCopy(
  MonthlySetupState state,
) => switch (state.step) {
  0 => (
    title: 'Bạn đang có bao nhiêu tiền?',
    subtitle:
        'Số tiền này sẽ được chia đều cho tới ngày bạn có thu nhập tiếp theo.',
  ),
  1 => (
    title: 'Bạn có thu nhập cố định không?',
    subtitle: 'Kế hoạch sẽ kéo dài tới ngày bạn có thu nhập tiếp theo.',
  ),
  2 => (
    title: 'Khoản chi cố định trước ${formatDayMonth(state.endDate)}',
    subtitle:
        'Chọn các khoản phải trả trong kỳ này. Khoản đã trả rồi sẽ không bị trừ.',
  ),
  3 => (
    title: 'Muốn để dành bao nhiêu?',
    subtitle: 'Khoản này được giữ riêng, không tính vào tiền chi mỗi ngày.',
  ),
  4 => (
    title: 'Kiểu chi tiêu của bạn',
    subtitle: 'Chia tiền mỗi ngày cho ăn uống, đi lại và chi tiêu linh hoạt.',
  ),
  _ => (title: 'Kế hoạch của bạn', subtitle: null),
};

Widget setupStepBody(MonthlySetupState state) => switch (state.step) {
  0 => AmountStep(state: state),
  1 => IncomeStep(state: state),
  2 => FixedExpensesStep(state: state),
  3 => SavingsStep(state: state),
  4 => StyleStep(state: state),
  _ => PreviewStep(state: state),
};

// ---------------------------------------------------------------------------
// Step 1 · Số tiền hiện có

class AmountStep extends StatefulWidget {
  const AmountStep({super.key, required this.state});

  final MonthlySetupState state;

  @override
  State<AmountStep> createState() => _AmountStepState();
}

class _AmountStepState extends State<AmountStep> {
  late final _controller = TextEditingController(
    text: widget.state.amount > 0
        ? envelopeAmountText(widget.state.amount)
        : '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(int amount) {
    _controller.text = envelopeAmountText(amount);
    context.read<MonthlySetupCubit>().setAmount(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final prefilled = state.prefilledBalance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('setup-amount'),
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(13),
            VndInputFormatter(),
          ],
          onChanged: (text) => context.read<MonthlySetupCubit>().setAmount(
            envelopeAmount(text) ?? 0,
          ),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            labelText: 'Số tiền hiện có',
            hintText: '0',
            suffixText: '₫',
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        if (prefilled != null && prefilled > 0) ...[
          const SizedBox(height: 10),
          _NoteRow(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppTheme.incomeEmerald,
            text: 'Đã điền từ số dư hiện tại: ${formatVnd(prefilled)}',
          ),
        ],
        if (state.defaultsError != null) ...[
          const SizedBox(height: 10),
          _NoteRow(
            icon: Icons.cloud_off_outlined,
            iconColor: AppTheme.warningAmber,
            text: state.defaultsError!,
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amount in const [3000000, 5000000, 10000000])
              ChoiceChip(
                label: Text(envelopeAmountText(amount)),
                selected: state.amount == amount,
                onSelected: (_) => _pick(amount),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const SetupInfoBox(
          icon: Icons.lightbulb_outline,
          text:
              'Khi bắt đầu kế hoạch, số này sẽ thay cho số dư hiện tại trong '
              'Sổ thu chi.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 · Thu nhập cố định

class IncomeStep extends StatelessWidget {
  const IncomeStep({super.key, required this.state});

  final MonthlySetupState state;

  String get _source => switch (state.incomeSource) {
    'recurring' => 'Theo khoản thu định kỳ: ${state.incomeLabel ?? 'Lương'}',
    'payroll_day' => 'Theo ngày nhận lương trong hồ sơ',
    'manual' => 'Ngày bạn đã chọn',
    _ => 'Chưa có lịch thu nhập — bạn chọn ngày giúp mình nhé',
  };

  Future<void> _pickDate(BuildContext context) async {
    final cubit = context.read<MonthlySetupCubit>();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.incomeDate.isAfter(state.today)
          ? state.incomeDate
          : state.today.add(const Duration(days: 1)),
      firstDate: state.today.add(const Duration(days: 1)),
      lastDate: state.today.add(const Duration(days: 365)),
      helpText: 'Ngày có thu nhập tiếp theo',
    );
    if (picked != null) cubit.setIncomeDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MonthlySetupCubit>();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SetupOptionCard(
          icon: Icons.work_outline,
          title: 'Có, nhận lương định kỳ',
          subtitle: 'Lương, trợ cấp hay khoản thu về cùng ngày mỗi kỳ',
          selected: state.hasFixedIncome,
          onTap: () => cubit.setHasFixedIncome(true),
        ),
        const SizedBox(height: 10),
        SetupOptionCard(
          icon: Icons.trending_up,
          title: 'Không, thu nhập linh hoạt',
          subtitle: 'Tiền không về cố định — kế hoạch mặc định 30 ngày',
          selected: !state.hasFixedIncome,
          onTap: () => cubit.setHasFixedIncome(false),
        ),
        if (state.hasFixedIncome) ...[
          const SizedBox(height: 16),
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const ValueKey('setup-income-date'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => _pickDate(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.event,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngày thu nhập tiếp theo',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatFullDate(state.incomeDate),
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_calendar, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _NoteRow(icon: Icons.info_outline, text: _source),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.date_range, color: theme.colorScheme.onPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kế hoạch dài ${state.durationDays} ngày',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Từ ${formatFullDate(state.today)} đến '
                      '${formatFullDate(state.endDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 · Khoản chi cố định

class FixedExpensesStep extends StatelessWidget {
  const FixedExpensesStep({super.key, required this.state});

  final MonthlySetupState state;

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<MonthlySetupCubit>();
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm khoản chi cố định'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ví dụ: Gửi xe'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) cubit.addFixed(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paidCount = state.fixedExpenses
        .where((item) => item.selected && item.paid)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (var index = 0; index < state.fixedExpenses.length; index++)
                _FixedExpenseRow(
                  index: index,
                  item: state.fixedExpenses[index],
                  divider: index > 0,
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Thêm khoản khác'),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng cần trả trong kỳ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (paidCount > 0)
                      Text(
                        'Không tính $paidCount khoản đã trả',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                formatVnd(state.fixedTotal),
                key: const ValueKey('setup-fixed-total'),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.expenseCoral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FixedExpenseRow extends StatelessWidget {
  const _FixedExpenseRow({
    required this.index,
    required this.item,
    required this.divider,
  });

  final int index;
  final FixedExpenseDraft item;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MonthlySetupCubit>();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
      decoration: BoxDecoration(
        border: divider
            ? Border(top: BorderSide(color: theme.colorScheme.outlineVariant))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.selected,
            onChanged: (value) => cubit.toggleFixed(index, value ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      decoration: item.paid ? TextDecoration.lineThrough : null,
                      color: item.paid
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  if (item.note != null)
                    Text(
                      item.note!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (item.selected) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('setup-fixed-amount-$index'),
                            initialValue: item.amount > 0
                                ? envelopeAmountText(item.amount)
                                : '',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(13),
                              VndInputFormatter(),
                            ],
                            onChanged: (text) => cubit.setFixedAmount(
                              index,
                              envelopeAmount(text) ?? 0,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Số tiền',
                              suffixText: '₫',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Đã trả'),
                          selected: item.paid,
                          onSelected: (value) =>
                              cubit.setFixedPaid(index, value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4 · Mục tiêu tiết kiệm

class SavingsStep extends StatefulWidget {
  const SavingsStep({super.key, required this.state});

  final MonthlySetupState state;

  @override
  State<SavingsStep> createState() => _SavingsStepState();
}

class _SavingsStepState extends State<SavingsStep> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _typed(String text) {
    final cubit = context.read<MonthlySetupCubit>();
    cubit.setCustomSavings(envelopeAmount(text) ?? 0);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), cubit.refreshPreview);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MonthlySetupCubit>();
    final theme = Theme.of(context);
    final state = widget.state;
    final percent = state.savingsPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in savingsPercents)
              ChoiceChip(
                label: Text('$value%'),
                selected: percent == value,
                onSelected: (_) => cubit.setSavingsPercent(value),
              ),
            ChoiceChip(
              label: const Text('Tự nhập'),
              selected: percent == null,
              onSelected: (_) => cubit.setCustomSavings(state.customSavings),
            ),
          ],
        ),
        if (percent == null) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('setup-custom-savings'),
            initialValue: state.customSavings > 0
                ? envelopeAmountText(state.customSavings)
                : '',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(13),
              VndInputFormatter(),
            ],
            onChanged: _typed,
            decoration: const InputDecoration(
              labelText: 'Số tiền để dành',
              suffixText: '₫',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Để dành trong kỳ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatVnd(state.savingsTarget),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppTheme.incomeEmerald,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                percent == null
                    ? 'Số bạn tự nhập'
                    : '$percent% của ${formatVnd(state.amount)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SetupBreakdown(state: state, title: 'TẠM TÍNH'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 5 · Kiểu chi tiêu

class StyleStep extends StatelessWidget {
  const StyleStep({super.key, required this.state});

  final MonthlySetupState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MonthlySetupCubit>();
    return Column(
      children: [
        for (final style in SpendingStyle.values) ...[
          SetupOptionCard(
            icon: style.icon,
            title: style.label,
            subtitle: style.description,
            selected: state.style == style,
            onTap: () => cubit.setStyle(style),
            footer: _RatioBar(style: style),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RatioBar extends StatelessWidget {
  const _RatioBar({required this.style});

  final SpendingStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = [
      ('food', style.food, theme.colorScheme.primary),
      ('transport', style.transport, AppTheme.expenseCoral),
      ('lifestyle', style.lifestyle, AppTheme.incomeEmerald),
    ];
    // One box with hard gradient stops draws the three shares as segments.
    final colors = <Color>[];
    final stops = <double>[];
    var start = 0.0;
    for (final (_, share, color) in parts) {
      final end = start + share / 100;
      colors.addAll([color, color]);
      stops.addAll([start, end]);
      start = end;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: ValueKey('ratio-bar-${style.name}'),
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(colors: colors, stops: stops),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            for (final (key, share, _) in parts)
              Text(
                '${planGroupLabels[key]} $share%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 6 · Xem trước

class PreviewStep extends StatelessWidget {
  const PreviewStep({super.key, required this.state});

  final MonthlySetupState state;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview;
    if (state.previewLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tính kế hoạch…'),
          ],
        ),
      );
    }
    if (preview == null) return _PreviewFailure(state: state);
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.date_range, size: 18, color: onPrimary),
                  const SizedBox(width: 8),
                  Text(
                    '${state.durationDays} NGÀY · ${formatDayMonth(state.today)} – '
                    '${formatDayMonth(state.endDate)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: onPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Mỗi ngày được chi',
                style: theme.textTheme.bodyMedium?.copyWith(color: onPrimary),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatVnd(preview.dailyAllowance),
                  key: const ValueKey('setup-daily-allowance'),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: onPrimary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: onPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mức sàn sinh tồn: '
                        '${formatVnd(preview.survivalFloor)}/ngày',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chia theo nhóm mỗi ngày',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final group in preview.groups)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        planGroupIcons[group.groupKey] ?? Icons.circle_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          planGroupLabels[group.groupKey] ?? group.groupKey,
                        ),
                      ),
                      Text(
                        formatVnd(group.dailyAmount),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SetupBreakdown(state: state, title: 'Cách tính', showDays: true),
        if (state.submitError != null) ...[
          const SizedBox(height: 12),
          Text(
            state.submitError!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _PreviewFailure extends StatelessWidget {
  const _PreviewFailure({required this.state});

  final MonthlySetupState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<MonthlySetupCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('setup-preview-error'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.expenseCoral.withAlpha(28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.expenseCoral),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.expenseCoral),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chưa lập được kế hoạch',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.expenseCoral,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                state.previewError ??
                    'Số tiền hiện có phải nhiều hơn chi cố định và tiền để dành.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SetupBreakdown(state: state),
        const SizedBox(height: 16),
        Text(
          'Bạn có thể',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => cubit.setSavingsPercent(0),
              icon: const Icon(Icons.savings_outlined),
              label: const Text('Giảm để dành về 0%'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => cubit.goTo(2),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Xem lại khoản chi cố định'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => cubit.goTo(0),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Sửa số tiền hiện có'),
            ),
            TextButton.icon(
              onPressed: cubit.refreshPreview,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces

/// The arithmetic behind a plan: the user's inputs and the engine's result.
class SetupBreakdown extends StatelessWidget {
  const SetupBreakdown({
    super.key,
    required this.state,
    this.title,
    this.showDays = false,
  });

  final MonthlySetupState state;
  final String? title;
  final bool showDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = state.preview;
    final percent = state.savingsPercent;
    Widget line(String label, Widget value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: strong ? null : theme.colorScheme.onSurfaceVariant,
                fontWeight: strong ? FontWeight.w700 : null,
              ),
            ),
          ),
          value,
        ],
      ),
    );
    Text amount(num value, {Color? color, bool strong = false}) => Text(
      formatVnd(value),
      style: TextStyle(
        color: color,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    final Widget result = state.previewLoading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : preview == null
        ? Text('—', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
        : amount(
            preview.spendableBudget,
            color: theme.colorScheme.primary,
            strong: true,
          );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Icon(
                  Icons.calculate_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  title!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          line('Số tiền hiện có', amount(state.amount)),
          line(
            '−  Chi cố định',
            amount(state.fixedTotal, color: AppTheme.expenseCoral),
          ),
          line(
            percent == null ? '−  Để dành' : '−  Để dành ($percent%)',
            amount(state.savingsTarget, color: AppTheme.incomeEmerald),
          ),
          Divider(color: theme.colorScheme.outlineVariant),
          line(
            showDays
                ? '=  Có thể chi ÷ ${state.durationDays} ngày'
                : '=  Có thể chi trong kỳ',
            result,
            strong: true,
          ),
        ],
      ),
    );
  }
}

/// A large selectable answer card with a radio mark.
class SetupOptionCard extends StatelessWidget {
  const SetupOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.surface
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: scheme.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected ? scheme.primary : scheme.outline,
                    ),
                  ],
                ),
                if (footer != null) ...[const SizedBox(height: 12), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tinted hint box.
class SetupInfoBox extends StatelessWidget {
  const SetupInfoBox({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.icon, required this.text, this.iconColor});

  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor ?? theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
