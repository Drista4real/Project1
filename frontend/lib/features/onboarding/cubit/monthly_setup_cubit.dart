import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';

/// Sets the single available balance the ledger shows.
typedef BalanceSync = Future<void> Function(num amount);

/// The balance the user states becomes the ledger's "Còn dư khả dụng".
Future<void> syncLedgerBalance(num amount) async {
  await BackendClient().request(
    'PUT',
    '/balance',
    body: {'amount': amount.toStringAsFixed(2)},
  );
}

/// How the spendable budget is split between food, transport and lifestyle.
enum SpendingStyle {
  saving(
    'Tiết kiệm',
    'Ưu tiên ăn uống, hạn chế mua sắm',
    Icons.savings_outlined,
    70,
    15,
    15,
  ),
  balanced(
    'Cân bằng',
    'Phù hợp với đa số người dùng',
    Icons.balance_outlined,
    60,
    15,
    25,
  ),
  relaxed(
    'Thoải mái',
    'Dư dả hơn cho giải trí, mua sắm',
    Icons.celebration_outlined,
    50,
    15,
    35,
  );

  const SpendingStyle(
    this.label,
    this.description,
    this.icon,
    this.food,
    this.transport,
    this.lifestyle,
  );

  final String label;
  final String description;
  final IconData icon;
  final int food;
  final int transport;
  final int lifestyle;
}

/// One fixed expense line the user can tick in step 3.
class FixedExpenseDraft {
  const FixedExpenseDraft({
    required this.label,
    this.amount = 0,
    this.selected = false,
    this.paid = false,
    this.note,
  });

  final String label;
  final num amount;
  final bool selected;
  final bool paid;
  final String? note;

  /// Whether the expense still has to be paid inside the plan window.
  bool get counts => selected && !paid && amount > 0;

  FixedExpenseDraft copyWith({num? amount, bool? selected, bool? paid}) =>
      FixedExpenseDraft(
        label: label,
        amount: amount ?? this.amount,
        selected: selected ?? this.selected,
        paid: paid ?? this.paid,
        note: note,
      );
}

/// The fixed expenses offered when the user records none yet.
const presetFixedExpenses = [
  'Tiền nhà',
  'Điện nước',
  'Internet',
  'Học phí',
  'Trả nợ',
];

/// The six steps of the monthly setup.
const monthlySetupSteps = 6;

/// The savings shares the setup offers next to a typed amount.
const savingsPercents = [0, 10, 20];

class MonthlySetupState {
  const MonthlySetupState({
    required this.today,
    required this.incomeDate,
    this.step = 0,
    this.loadingDefaults = true,
    this.defaultsError,
    this.prefilledBalance,
    this.incomeSource = 'none',
    this.incomeLabel,
    this.amount = 0,
    this.hasFixedIncome = true,
    this.fixedExpenses = const [],
    this.savingsPercent = 10,
    this.customSavings = 0,
    this.style = SpendingStyle.balanced,
    this.preview,
    this.previewLoading = false,
    this.previewError,
    this.submitting = false,
    this.submitError,
    this.created,
    this.balanceSyncError,
  });

  final DateTime today;
  final DateTime incomeDate;
  final int step;
  final bool loadingDefaults;
  final String? defaultsError;
  final num? prefilledBalance;

  /// `recurring`, `payroll_day`, `manual` or `none`.
  final String incomeSource;
  final String? incomeLabel;
  final num amount;
  final bool hasFixedIncome;
  final List<FixedExpenseDraft> fixedExpenses;

  /// A share of [amount], or `null` when the user typed [customSavings].
  final int? savingsPercent;
  final num customSavings;
  final SpendingStyle style;
  final PlanPreview? preview;
  final bool previewLoading;
  final String? previewError;
  final bool submitting;
  final String? submitError;
  final BudgetPlan? created;

  /// Why the ledger balance was not updated after the plan was saved.
  final String? balanceSyncError;

  /// The day the plan ends: the next fixed income, or 30 days without one.
  DateTime get endDate =>
      hasFixedIncome ? incomeDate : today.add(const Duration(days: 30));

  int get durationDays => endDate.difference(today).inDays.clamp(1, 365);

  num get fixedTotal => fixedExpenses
      .where((item) => item.counts)
      .fold<num>(0, (sum, item) => sum + item.amount);

  num get savingsTarget {
    final percent = savingsPercent;
    if (percent == null) return customSavings;
    return (amount * percent / 100).round();
  }

  bool get isLastStep => step == monthlySetupSteps - 1;

  bool get canContinue => switch (step) {
    0 => amount > 0,
    5 => preview != null && !previewLoading && !submitting,
    _ => true,
  };

  PlanDraft draft({String? idempotencyKey}) => PlanDraft(
    totalIncome: amount,
    durationDays: durationDays,
    savingsTarget: savingsTarget,
    fixedExpenses: fixedTotal,
    foodRatio: style.food,
    transportRatio: style.transport,
    lifestyleRatio: style.lifestyle,
    startDate: today,
    idempotencyKey: idempotencyKey,
  );

  MonthlySetupState copyWith({
    int? step,
    bool? loadingDefaults,
    String? defaultsError,
    num? prefilledBalance,
    String? incomeSource,
    String? incomeLabel,
    DateTime? incomeDate,
    num? amount,
    bool? hasFixedIncome,
    List<FixedExpenseDraft>? fixedExpenses,
    int? savingsPercent,
    bool customSavingsMode = false,
    num? customSavings,
    SpendingStyle? style,
    PlanPreview? preview,
    bool clearPreview = false,
    bool? previewLoading,
    String? previewError,
    bool? submitting,
    String? submitError,
    bool clearSubmitError = false,
    BudgetPlan? created,
    String? balanceSyncError,
  }) => MonthlySetupState(
    today: today,
    incomeDate: incomeDate ?? this.incomeDate,
    step: step ?? this.step,
    loadingDefaults: loadingDefaults ?? this.loadingDefaults,
    defaultsError: defaultsError ?? this.defaultsError,
    prefilledBalance: prefilledBalance ?? this.prefilledBalance,
    incomeSource: incomeSource ?? this.incomeSource,
    incomeLabel: incomeLabel ?? this.incomeLabel,
    amount: amount ?? this.amount,
    hasFixedIncome: hasFixedIncome ?? this.hasFixedIncome,
    fixedExpenses: fixedExpenses ?? this.fixedExpenses,
    savingsPercent: customSavingsMode
        ? null
        : (savingsPercent ?? this.savingsPercent),
    customSavings: customSavings ?? this.customSavings,
    style: style ?? this.style,
    preview: clearPreview ? null : (preview ?? this.preview),
    previewLoading: previewLoading ?? this.previewLoading,
    // Changing an answer drops the old preview and its error together.
    previewError: clearPreview
        ? previewError
        : (previewError ?? this.previewError),
    submitting: submitting ?? this.submitting,
    submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    created: created ?? this.created,
    balanceSyncError: balanceSyncError ?? this.balanceSyncError,
  );
}

/// Collects the monthly setup answers and asks the engine for the figures.
///
/// The cubit only assembles inputs (the fixed expenses that still count, the
/// savings share). Every plan figure — spendable budget, daily allowance,
/// survival floor — comes from the engine (ADR 0009).
class MonthlySetupCubit extends Cubit<MonthlySetupState> {
  MonthlySetupCubit(
    this.repository, {
    required DateTime today,
    BalanceSync? syncBalance,
  }) : syncBalance = syncBalance ?? syncLedgerBalance,
       super(
         MonthlySetupState(
           today: _dateOnly(today),
           incomeDate: _dateOnly(today).add(const Duration(days: 30)),
         ),
       );

  final BudgetPlanRepository repository;

  /// Writes the stated amount as the single balance the ledger shows.
  final BalanceSync syncBalance;

  /// One key per opened setup, so a double tap never creates two plans.
  final String _idempotencyKey = _uuidV4();

  /// Prefill the answers from what the server already knows.
  Future<void> start() async {
    try {
      final defaults = await repository.setupDefaults();
      final recurring = [
        for (final item in defaults.fixedExpenses)
          FixedExpenseDraft(
            label: item.description,
            amount: item.amount,
            selected: true,
            note: item.nextDate == null
                ? 'Từ giao dịch định kỳ'
                : 'Ngày ${formatDayMonth(item.nextDate!)} · từ định kỳ',
          ),
      ];
      final income = defaults.nextIncomeDate;
      final savings = defaults.monthlySavingsTarget;
      emit(
        state.copyWith(
          loadingDefaults: false,
          prefilledBalance: defaults.availableBalance,
          amount: defaults.availableBalance > 0 ? defaults.availableBalance : 0,
          incomeSource: defaults.nextIncomeSource,
          incomeLabel: defaults.nextIncomeLabel,
          incomeDate: income == null ? null : _dateOnly(income),
          hasFixedIncome: income != null,
          fixedExpenses: [...recurring, ..._presetsMissingFrom(recurring)],
          customSavingsMode: savings > 0,
          customSavings: savings,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loadingDefaults: false,
          defaultsError:
              'Chưa lấy được số dư và lịch thu chi. Bạn nhập tay giúp mình nhé.',
          fixedExpenses: _presetsMissingFrom(const []),
        ),
      );
    }
  }

  void setAmount(num amount) =>
      emit(state.copyWith(amount: amount < 0 ? 0 : amount, clearPreview: true));

  void setHasFixedIncome(bool value) =>
      emit(state.copyWith(hasFixedIncome: value, clearPreview: true));

  void setIncomeDate(DateTime date) => emit(
    state.copyWith(
      incomeDate: _dateOnly(date),
      hasFixedIncome: true,
      incomeSource: 'manual',
      clearPreview: true,
    ),
  );

  void toggleFixed(int index, bool selected) =>
      _updateFixed(index, (item) => item.copyWith(selected: selected));

  void setFixedAmount(int index, num amount) => _updateFixed(
    index,
    (item) =>
        item.copyWith(amount: amount, selected: amount > 0 || item.selected),
  );

  void setFixedPaid(int index, bool paid) =>
      _updateFixed(index, (item) => item.copyWith(paid: paid));

  void addFixed(String label) {
    final name = label.trim();
    if (name.isEmpty) return;
    emit(
      state.copyWith(
        fixedExpenses: [
          ...state.fixedExpenses,
          FixedExpenseDraft(label: name, selected: true),
        ],
        clearPreview: true,
      ),
    );
  }

  Future<void> setSavingsPercent(int percent) async {
    emit(state.copyWith(savingsPercent: percent, clearPreview: true));
    await refreshPreview();
  }

  /// Keep a typed savings amount; the screen refreshes the preview once the
  /// user stops typing, so every keystroke does not reach the engine.
  void setCustomSavings(num amount) => emit(
    state.copyWith(
      customSavingsMode: true,
      customSavings: amount < 0 ? 0 : amount,
      clearPreview: true,
    ),
  );

  void setStyle(SpendingStyle style) =>
      emit(state.copyWith(style: style, clearPreview: true));

  Future<void> goTo(int step) async {
    emit(state.copyWith(step: step.clamp(0, monthlySetupSteps - 1)));
    // Step 4 shows the running total and step 6 the whole plan.
    if (state.step >= 3) await refreshPreview();
  }

  Future<void> next() async {
    if (!state.canContinue) return;
    if (state.isLastStep) return submit();
    await goTo(state.step + 1);
  }

  Future<void> back() => goTo(state.step - 1);

  /// Ask the engine for the figures of the current answers.
  Future<void> refreshPreview() async {
    if (state.amount <= 0) return;
    emit(state.copyWith(previewLoading: true, clearPreview: true));
    try {
      final preview = await repository.preview(state.draft());
      emit(state.copyWith(preview: preview, previewLoading: false));
    } catch (error) {
      emit(
        state.copyWith(
          previewLoading: false,
          clearPreview: true,
          previewError: _message(error),
        ),
      );
    }
  }

  /// Save the plan the user just previewed.
  Future<void> submit() async {
    if (state.submitting || state.preview == null || state.created != null) {
      return;
    }
    emit(state.copyWith(submitting: true, clearSubmitError: true));
    try {
      final plan = await repository.create(
        state.draft(idempotencyKey: _idempotencyKey),
      );
      String? syncError;
      try {
        await syncBalance(state.amount);
      } catch (error) {
        // The plan is saved; the balance can still be fixed in the ledger.
        syncError = _message(error);
      }
      emit(
        state.copyWith(
          submitting: false,
          created: plan,
          balanceSyncError: syncError,
        ),
      );
    } catch (error) {
      emit(state.copyWith(submitting: false, submitError: _message(error)));
    }
  }

  void _updateFixed(
    int index,
    FixedExpenseDraft Function(FixedExpenseDraft) change,
  ) {
    if (index < 0 || index >= state.fixedExpenses.length) return;
    final items = [...state.fixedExpenses];
    items[index] = change(items[index]);
    emit(state.copyWith(fixedExpenses: items, clearPreview: true));
  }

  List<FixedExpenseDraft> _presetsMissingFrom(List<FixedExpenseDraft> taken) {
    final names = taken.map((item) => item.label.toLowerCase()).toSet();
    return [
      for (final label in presetFixedExpenses)
        if (!names.contains(label.toLowerCase()))
          FixedExpenseDraft(label: label),
    ];
  }

  String _message(Object error) {
    if (error is FinanceApiException) return error.message;
    return 'Không tính được kế hoạch. Vui lòng thử lại.';
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// `dd/MM`, the short date the setup and the plan calendar show.
String formatDayMonth(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}';

/// `dd/MM/yyyy`.
String formatFullDate(DateTime date) => '${formatDayMonth(date)}/${date.year}';

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
