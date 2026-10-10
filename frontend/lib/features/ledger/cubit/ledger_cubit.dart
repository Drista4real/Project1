import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/finance/domain/entities/financial_overview.dart';
import 'package:project_one/features/finance/domain/entities/transaction.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';

class LedgerState {
  LedgerState({
    this.loading = false,
    this.error,
    FinancialOverview? overview,
    List<Transaction> transactions = const [],
    this.showCalendar = true,
    required this.month,
  }) : overview =
           overview ??
           FinancialOverview(
             currentBalance: 0,
             monthlyIncome: 0,
             monthlyExpense: 0,
           ),
       transactions = List.unmodifiable(transactions);

  final bool loading;
  final String? error;
  final FinancialOverview overview;
  final List<Transaction> transactions;
  final bool showCalendar;
  final DateTime month;

  LedgerState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    FinancialOverview? overview,
    List<Transaction>? transactions,
    bool? showCalendar,
    DateTime? month,
  }) => LedgerState(
    loading: loading ?? this.loading,
    error: clearError ? null : error ?? this.error,
    overview: overview ?? this.overview,
    transactions: transactions ?? this.transactions,
    showCalendar: showCalendar ?? this.showCalendar,
    month: month ?? this.month,
  );
}

class LedgerCubit extends Cubit<LedgerState> {
  LedgerCubit(this.repository, {DateTime? now})
    : super(
        LedgerState(
          month: DateTime(
            (now ?? DateTime.now()).year,
            (now ?? DateTime.now()).month,
          ),
        ),
      );

  final FinanceRepository repository;
  int _generation = 0;

  void showCalendar(bool show) => emit(state.copyWith(showCalendar: show));
  void moveMonth(int delta) => emit(
    state.copyWith(
      month: DateTime(state.month.year, state.month.month + delta),
    ),
  );

  Future<void> refresh() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final values = await Future.wait<Object>([
        repository.getOverview(),
        repository.getTransactions(),
      ]);
      if (!isClosed && generation == _generation) {
        emit(
          state.copyWith(
            loading: false,
            overview: values[0] as FinancialOverview,
            transactions: values[1] as List<Transaction>,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(loading: false, error: '$error', transactions: []));
      }
    }
  }
}
