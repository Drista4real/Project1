import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';

class ForecastState {
  ForecastState({this.days = 14, Set<int> saving = const {}})
    : saving = Set.unmodifiable(saving);
  final int days;
  final Set<int> saving;
}

class ForecastCubit extends Cubit<ForecastState> {
  ForecastCubit(this.repository) : super(ForecastState());
  final ManagementRepository repository;

  void selectDays(int days) =>
      emit(ForecastState(days: days, saving: state.saving));

  Future<bool> updateAlert(int id, String field) async {
    if (isClosed || state.saving.contains(id)) return false;
    emit(ForecastState(days: state.days, saving: {...state.saving, id}));
    try {
      await repository.save('cashflow_alerts', {field: true}, key: '$id');
      return !isClosed;
    } finally {
      if (!isClosed) {
        emit(
          ForecastState(
            days: state.days,
            saving: {...state.saving}..remove(id),
          ),
        );
      }
    }
  }
}
