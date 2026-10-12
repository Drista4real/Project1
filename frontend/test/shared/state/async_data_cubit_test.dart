import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/shared/state/async_data_cubit.dart';

void main() {
  test('a slower earlier refresh cannot overwrite the newest result', () async {
    final requests = <Completer<int>>[];
    final cubit = AsyncDataCubit<int>(() {
      final request = Completer<int>();
      requests.add(request);
      return request.future;
    });
    addTearDown(cubit.close);
    final first = cubit.refresh();
    final second = cubit.refresh();
    requests[1].complete(2);
    await second;
    requests[0].complete(1);
    await first;
    expect(cubit.state.status, DataStatus.success);
    expect(cubit.state.data, 2);
  });

  test('an outdated failure cannot replace a newer success', () async {
    final requests = <Completer<int>>[];
    final cubit = AsyncDataCubit<int>(() {
      final request = Completer<int>();
      requests.add(request);
      return request.future;
    });
    addTearDown(cubit.close);
    final first = cubit.refresh();
    final second = cubit.refresh();
    requests[1].complete(2);
    await second;
    requests[0].completeError(StateError('old request failed'));
    await first;
    expect(cubit.state.status, DataStatus.success);
    expect(cubit.state.data, 2);
    expect(cubit.state.error, isNull);
  });

  test('retry clears the error and loads fresh data', () async {
    var fail = true;
    final cubit = AsyncDataCubit<int>(() async {
      if (fail) throw StateError('offline');
      return 3;
    });
    addTearDown(cubit.close);
    await cubit.refresh();
    expect(cubit.state.status, DataStatus.failure);
    fail = false;
    await cubit.refresh();
    expect(cubit.state.status, DataStatus.success);
    expect(cubit.state.error, isNull);
    expect(cubit.state.data, 3);
  });

  test('closing during a load safely ignores its result', () async {
    final request = Completer<int>();
    final cubit = AsyncDataCubit<int>(() => request.future);
    final refresh = cubit.refresh();
    await cubit.close();
    request.complete(1);
    await expectLater(refresh, completes);
    await expectLater(cubit.refresh(), completes);
  });

  test('changing the loader invalidates an unfinished request', () async {
    final old = Completer<int>();
    final cubit = AsyncDataCubit<int>(() => old.future);
    addTearDown(cubit.close);
    final first = cubit.refresh();
    await cubit.replaceLoader(() async => 4);
    old.complete(1);
    await first;
    expect(cubit.state.data, 4);
  });
}
