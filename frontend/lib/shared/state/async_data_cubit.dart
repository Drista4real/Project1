import 'package:flutter_bloc/flutter_bloc.dart';

enum DataStatus { initial, loading, success, failure }

class AsyncDataState<T> {
  const AsyncDataState({
    this.status = DataStatus.initial,
    this.data,
    this.error,
  });

  final DataStatus status;
  final T? data;
  final Object? error;
}

/// Owns requests independently of widget rebuilds. Only the newest load wins.
class AsyncDataCubit<T> extends Cubit<AsyncDataState<T>> {
  AsyncDataCubit(this._load) : super(AsyncDataState<T>());

  Future<T> Function() _load;
  int _generation = 0;

  Future<void> replaceLoader(Future<T> Function() load) {
    _load = load;
    return refresh();
  }

  Future<void> refresh() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(AsyncDataState<T>(status: DataStatus.loading));
    try {
      final data = await _load();
      if (!isClosed && generation == _generation) {
        emit(AsyncDataState<T>(status: DataStatus.success, data: data));
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(AsyncDataState<T>(status: DataStatus.failure, error: error));
      }
    }
  }
}
