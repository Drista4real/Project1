import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/finance/domain/entities/transaction.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';

class TransactionDetailState {
  const TransactionDetailState({
    this.transaction,
    this.error,
    this.busy = false,
    this.deleted = false,
    this.deleteError,
  });
  final Transaction? transaction;
  final String? error;
  final bool busy;
  final bool deleted;
  final String? deleteError;
}

class TransactionDetailCubit extends Cubit<TransactionDetailState> {
  TransactionDetailCubit(this.repository, this.id)
    : super(const TransactionDetailState());
  final FinanceRepository repository;
  final int id;
  int _generation = 0;

  Future<void> refresh() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(TransactionDetailState(transaction: state.transaction, busy: true));
    try {
      final transaction = await repository.getTransaction(id);
      if (!isClosed && generation == _generation) {
        emit(TransactionDetailState(transaction: transaction));
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(TransactionDetailState(error: '$error'));
      }
    }
  }

  Future<void> delete() async {
    if (isClosed || state.busy) return;
    emit(TransactionDetailState(transaction: state.transaction, busy: true));
    try {
      await repository.deleteTransaction(id);
      if (!isClosed) emit(const TransactionDetailState(deleted: true));
    } catch (error) {
      if (!isClosed) {
        emit(
          TransactionDetailState(
            transaction: state.transaction,
            deleteError: '$error',
          ),
        );
      }
    }
  }
}
