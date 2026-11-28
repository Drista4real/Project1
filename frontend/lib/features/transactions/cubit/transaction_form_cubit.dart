import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/finance/domain/entities/account.dart';
import 'package:project_one/features/finance/domain/entities/category.dart';
import 'package:project_one/features/finance/domain/entities/transaction.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';

class TransactionFormState {
  TransactionFormState({
    List<Category> categories = const [],
    List<Account> accounts = const [],
    this.accountId,
    this.toAccountId,
    required this.date,
    this.selected,
    this.type = 'expense',
    this.loading = true,
    this.saving = false,
    this.loadError,
    this.saveError,
    this.saved = false,
    this.planId,
    this.fixedExpense = false,
    List<String> fixedExpenseNames = const [],
  }) : fixedExpenseNames = List.unmodifiable(fixedExpenseNames),
       categories = List.unmodifiable(categories),
       accounts = List.unmodifiable(accounts);
  final List<Category> categories;
  final List<Account> accounts;
  final int? accountId;
  final int? toAccountId;
  final DateTime date;
  final Category? selected;
  final String type;
  final bool loading;
  final bool saving;
  final String? loadError;
  final String? saveError;
  final bool saved;

  /// The plan a fixed expense marker attaches to, or null when none.
  final int? planId;

  /// Set only by the user; a match is shown as a suggestion, never applied.
  final bool fixedExpense;

  /// Recurring fixed expenses that a category or note may match.
  final List<String> fixedExpenseNames;

  bool get canMarkFixedExpense => type == 'expense' && planId != null;

  /// The recurring item the category or [note] matches, if any.
  String? fixedExpenseSuggestion(String note) {
    String key(String? text) => (text ?? '').trim().toLowerCase();
    final candidates = {key(selected?.name), key(note)}..remove('');
    for (final name in fixedExpenseNames) {
      if (candidates.contains(key(name))) return name;
    }
    return null;
  }

  TransactionFormState copyWith({
    List<Category>? categories,
    List<Account>? accounts,
    int? accountId,
    int? toAccountId,
    DateTime? date,
    Category? selected,
    bool clearSelected = false,
    String? type,
    bool? loading,
    bool? saving,
    String? loadError,
    bool clearLoadError = false,
    String? saveError,
    bool clearSaveError = false,
    bool? saved,
    int? planId,
    bool? fixedExpense,
    List<String>? fixedExpenseNames,
  }) => TransactionFormState(
    categories: categories ?? this.categories,
    accounts: accounts ?? this.accounts,
    accountId: accountId ?? this.accountId,
    toAccountId: toAccountId ?? this.toAccountId,
    date: date ?? this.date,
    selected: clearSelected ? null : selected ?? this.selected,
    type: type ?? this.type,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    loadError: clearLoadError ? null : loadError ?? this.loadError,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
    saved: saved ?? this.saved,
    planId: planId ?? this.planId,
    fixedExpense: fixedExpense ?? this.fixedExpense,
    fixedExpenseNames: fixedExpenseNames ?? this.fixedExpenseNames,
  );
}

class TransactionFormCubit extends Cubit<TransactionFormState> {
  TransactionFormCubit(this.repository, {this.transaction, this.plans})
    : super(
        TransactionFormState(
          accountId: transaction?.accountId,
          toAccountId: transaction?.toAccountId,
          date: transaction?.transactionDate ?? DateTime.now(),
          type: transaction?.transactionType ?? 'expense',
          planId: transaction?.fixedExpensePlanId,
          fixedExpense: transaction?.fixedExpensePlanId != null,
        ),
      );
  final FinanceRepository repository;
  final Transaction? transaction;
  final BudgetPlanRepository? plans;
  int _generation = 0;
  bool _referencesLoaded = false;

  void selectType(String type) =>
      emit(state.copyWith(type: type, clearSelected: true));
  void selectAccount(int? id) => emit(state.copyWith(accountId: id));
  void selectToAccount(int? id) => emit(state.copyWith(toAccountId: id));
  void selectCategory(Category? category) =>
      emit(state.copyWith(selected: category, clearSelected: category == null));
  void setFixedExpense(bool value) =>
      emit(state.copyWith(fixedExpense: value));
  void selectDate(DateTime date) => emit(
    state.copyWith(
      date: DateTime(
        date.year,
        date.month,
        date.day,
        state.date.hour,
        state.date.minute,
      ),
    ),
  );

  Future<void> loadReferences() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(state.copyWith(loading: true, clearLoadError: true));
    try {
      final values = await Future.wait<Object>([
        repository.getCategories(),
        repository.getAccounts(),
      ]);
      if (isClosed || generation != _generation) return;
      final categories = values[0] as List<Category>;
      final accounts = values[1] as List<Account>;
      final selectedId = _referencesLoaded
          ? state.selected?.id
          : transaction?.categoryId;
      Category? selected;
      for (final category in categories) {
        if (category.id == selectedId) selected = category;
      }
      _referencesLoaded = true;
      emit(
        state.copyWith(
          categories: categories,
          accounts: accounts,
          loading: false,
          accountId:
              state.accountId ?? (accounts.isEmpty ? null : accounts.first.id),
          selected: selected,
          clearSelected: selected == null,
        ),
      );
      await _loadPlan(generation);
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(loading: false, loadError: '$error'));
      }
    }
  }

  /// The active plan, as the plan screen picks it, and its recurring items.
  ///
  /// Both are optional: without them the marker or the suggestion is hidden,
  /// and a marker already saved on the transaction is kept.
  Future<void> _loadPlan(int generation) async {
    final plans = this.plans;
    if (plans == null) return;
    try {
      final active = await plans.plans(activeOnly: true);
      if (isClosed || generation != _generation) return;
      if (state.planId == null && active.isNotEmpty) {
        emit(state.copyWith(planId: active.first.id));
      }
      final defaults = await plans.setupDefaults();
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          fixedExpenseNames: [
            for (final item in defaults.fixedExpenses) item.description,
          ],
        ),
      );
    } catch (_) {
      // An unreadable plan only hides the marker; it never blocks saving.
    }
  }

  Future<void> save(double amount, String description) async {
    if (isClosed ||
        state.saving ||
        state.loading ||
        state.loadError != null ||
        state.accounts.isEmpty) {
      return;
    }
    final form = state;
    final fixedExpensePlanId = form.canMarkFixedExpense && form.fixedExpense
        ? form.planId
        : null;
    emit(state.copyWith(saving: true, clearSaveError: true));
    try {
      if (transaction != null) {
        await repository.updateTransaction(transaction!.id, {
          'amount': amount.toStringAsFixed(2),
          'transaction_type': form.type,
          'raw_description': description.trim(),
          'clean_description': description.trim(),
          'category_id': form.type == 'transfer' ? null : form.selected?.id,
          'account_id': form.accountId,
          'to_account_id': form.type == 'transfer' ? form.toAccountId : null,
          'transaction_date': form.date.toUtc().toIso8601String(),
          'fixed_expense_plan_id': fixedExpensePlanId,
        });
      } else {
        await repository.addTransaction(
          amount: amount,
          transactionType: form.type,
          description: description.trim().isEmpty
              ? 'Giao dịch'
              : description.trim(),
          categoryId: form.selected?.id,
          categoryName: form.selected?.name,
          accountId: form.accountId,
          transactionDate: form.date,
          fixedExpensePlanId: fixedExpensePlanId,
        );
      }
      if (!isClosed) emit(state.copyWith(saving: false, saved: true));
    } catch (error) {
      if (!isClosed) emit(state.copyWith(saving: false, saveError: '$error'));
    }
  }
}
