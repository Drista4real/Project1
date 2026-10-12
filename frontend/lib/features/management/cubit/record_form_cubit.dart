import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/shared/state/async_data_cubit.dart';

class RecordFormState {
  const RecordFormState({
    this.status = DataStatus.initial,
    this.options = const {},
    this.loadError,
    this.saving = false,
    this.saved = false,
    this.saveError,
  });
  final DataStatus status;
  final Map<String, List<Map<String, dynamic>>> options;
  final Object? loadError;
  final bool saving;
  final bool saved;
  final String? saveError;

  RecordFormState copyWith({
    DataStatus? status,
    Map<String, List<Map<String, dynamic>>>? options,
    Object? loadError,
    bool clearLoadError = false,
    bool? saving,
    bool? saved,
    String? saveError,
    bool clearSaveError = false,
  }) => RecordFormState(
    status: status ?? this.status,
    options: options ?? this.options,
    loadError: clearLoadError ? null : loadError ?? this.loadError,
    saving: saving ?? this.saving,
    saved: saved ?? this.saved,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
  );
}

class RecordFormCubit extends Cubit<RecordFormState> {
  RecordFormCubit(
    this.repository,
    this.resource,
    Set<String> targets, {
    this.recordKey,
  }) : targets = Set.unmodifiable(targets),
       super(const RecordFormState());
  final ManagementRepository repository;
  final String resource;
  final Set<String> targets;
  final String? recordKey;
  int _generation = 0;

  Future<void> loadReferences() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(state.copyWith(status: DataStatus.loading, clearLoadError: true));
    try {
      final options = <String, List<Map<String, dynamic>>>{};
      for (final target in targets) {
        final records = await repository.references(target);
        options[target] = List.unmodifiable(
          records.map((r) => Map<String, dynamic>.unmodifiable(r)),
        );
      }
      if (!isClosed && generation == _generation) {
        emit(
          state.copyWith(
            status: DataStatus.success,
            options: Map.unmodifiable(options),
          ),
        );
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(status: DataStatus.failure, loadError: error));
      }
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    if (isClosed || state.saving || state.status != DataStatus.success) return;
    emit(state.copyWith(saving: true, clearSaveError: true));
    try {
      await repository.save(resource, data, key: recordKey);
      if (!isClosed) emit(state.copyWith(saving: false, saved: true));
    } catch (error) {
      if (!isClosed) emit(state.copyWith(saving: false, saveError: '$error'));
    }
  }
}
