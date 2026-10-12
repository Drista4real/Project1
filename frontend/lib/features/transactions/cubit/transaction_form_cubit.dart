import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/finance/domain/entities/account.dart';
import 'package:project_one/features/finance/domain/entities/category.dart';
import 'package:project_one/features/finance/domain/entities/transaction.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';

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
  }) : categories = List.unmodifiable(categories),
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
  );
}

class TransactionFormCubit extends Cubit<TransactionFormState> {
  TransactionFormCubit(this.repository, {this.transaction})
    : super(
        TransactionFormState(
          accountId: transaction?.accountId,
          toAccountId: transaction?.toAccountId,
          date: transaction?.transactionDate ?? DateTime.now(),
          type: transaction?.transactionType ?? 'expense',
        ),
      );
  final FinanceRepository repository;
  final Transaction? transaction;
  int _generation = 0;
  bool _referencesLoaded = false;

  void selectType(String type) =>
      emit(state.copyWith(type: type, clearSelected: true));
  void selectAccount(int? id) => emit(state.copyWith(accountId: id));
  void selectToAccount(int? id) => emit(state.copyWith(toAccountId: id));
  void selectCategory(Category? category) =>
      emit(state.copyWith(selected: category, clearSelected: category == null));
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
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(loading: false, loadError: '$error'));
      }
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
        );
      }
      if (!isClosed) emit(state.copyWith(saving: false, saved: true));
    } catch (error) {
      if (!isClosed) emit(state.copyWith(saving: false, saveError: '$error'));
    }
  }
}
