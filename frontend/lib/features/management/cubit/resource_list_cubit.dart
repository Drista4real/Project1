import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart'
    show FinanceRecord;
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/shared/state/async_data_cubit.dart';

class ResourceListState {
  const ResourceListState({
    this.status = DataStatus.initial,
    this.page,
    this.error,
    this.offset = 0,
    this.deleting = false,
  });
  final DataStatus status;
  final Map<String, dynamic>? page;
  final Object? error;
  final int offset;
  final bool deleting;

  ResourceListState copyWith({
    DataStatus? status,
    Map<String, dynamic>? page,
    Object? error,
    bool clearError = false,
    int? offset,
    bool? deleting,
  }) => ResourceListState(
    status: status ?? this.status,
    page: page ?? this.page,
    error: clearError ? null : error ?? this.error,
    offset: offset ?? this.offset,
    deleting: deleting ?? this.deleting,
  );
}

class ResourceListCubit extends Cubit<ResourceListState> {
  ResourceListCubit(this.repository, this.resource)
    : super(const ResourceListState());
  final ManagementRepository repository;
  final String resource;
  int _generation = 0;

  Future<void> refresh() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(state.copyWith(status: DataStatus.loading, clearError: true));
    try {
      final page = await repository.page(resource, offset: state.offset);
      if (!isClosed && generation == _generation) {
        emit(
          state.copyWith(
            status: DataStatus.success,
            page: Map.unmodifiable(page),
          ),
        );
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(status: DataStatus.failure, error: error));
      }
    }
  }

  Future<void> movePage(int delta) async {
    if (isClosed || state.deleting) return;
    final offset = state.offset + delta * 30;
    if (offset < 0) return;
    emit(state.copyWith(offset: offset));
    await refresh();
  }

  Future<void> delete(FinanceRecord item) async {
    if (isClosed || state.deleting) return;
    emit(state.copyWith(deleting: true));
    try {
      await repository.delete(resource, repository.key(resource, item));
      if (!isClosed) {
        emit(state.copyWith(offset: state.offset > 0 ? state.offset - 30 : 0));
        await refresh();
      }
    } finally {
      if (!isClosed) emit(state.copyWith(deleting: false));
    }
  }
}
