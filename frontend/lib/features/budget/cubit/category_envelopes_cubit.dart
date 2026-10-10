import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart'
    show FinanceRecord;
import 'package:project_one/features/budget/models/category_envelope_data.dart';
import 'package:project_one/features/budget/services/category_envelopes_service.dart';
import 'package:project_one/shared/state/async_data_cubit.dart';

class CategoryEnvelopesState {
  const CategoryEnvelopesState({
    required this.month,
    this.status = DataStatus.initial,
    this.data,
    this.error,
    this.mutating = false,
    this.query = '',
  });
  final DateTime month;
  final DataStatus status;
  final CategoryEnvelopeData? data;
  final Object? error;
  final bool mutating;
  final String query;

  CategoryEnvelopesState copyWith({
    DateTime? month,
    DataStatus? status,
    CategoryEnvelopeData? data,
    Object? error,
    bool clearError = false,
    bool? mutating,
    String? query,
  }) => CategoryEnvelopesState(
    month: month ?? this.month,
    status: status ?? this.status,
    data: data ?? this.data,
    error: clearError ? null : error ?? this.error,
    mutating: mutating ?? this.mutating,
    query: query ?? this.query,
  );
}

class CategoryEnvelopesCubit extends Cubit<CategoryEnvelopesState> {
  CategoryEnvelopesCubit(this.service, {DateTime? month})
    : super(
        CategoryEnvelopesState(
          month: month ?? DateTime(DateTime.now().year, DateTime.now().month),
        ),
      );
  final CategoryEnvelopesService service;
  int _generation = 0;

  void search(String query) => emit(state.copyWith(query: query));

  Future<void> refresh() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(state.copyWith(status: DataStatus.loading, clearError: true));
    try {
      final data = await service.load(state.month);
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(status: DataStatus.success, data: data));
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(status: DataStatus.failure, error: error));
      }
    }
  }

  Future<void> moveMonth(int delta) async {
    if (isClosed || state.mutating) return;
    emit(
      state.copyWith(
        month: DateTime(state.month.year, state.month.month + delta),
      ),
    );
    await refresh();
  }

  Future<void> disable(CategoryEnvelopeData data, FinanceRecord category) =>
      _mutate(() => service.saveLimit(data, category['id'] as int, null));

  Future<void> deleteCategory(FinanceRecord category) => _mutate(
    () => service.repository.delete(
      'categories',
      service.repository.key('categories', category),
    ),
  );

  Future<void> _mutate(Future<void> Function() action) async {
    if (isClosed || state.mutating) return;
    emit(state.copyWith(mutating: true));
    try {
      await action();
      if (!isClosed) await refresh();
    } finally {
      if (!isClosed) emit(state.copyWith(mutating: false));
    }
  }
}
