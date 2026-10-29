import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/shared/state/async_data_cubit.dart';

import 'package:project_one/shared/widgets/kakeibo_card.dart';

class FinanceDataController {
  Future<void> Function()? _refresh;
  Future<void> refresh() async {
    await _refresh?.call();
  }
}

/// Fetch once per refresh; render loading and errors without sample-data fallbacks.
class FinanceDataView<T> extends StatefulWidget {
  const FinanceDataView({
    super.key,
    required this.load,
    required this.builder,
    this.controller,
  });
  final Future<T> Function() load;
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() refresh,
  )
  builder;
  final FinanceDataController? controller;

  @override
  State<FinanceDataView<T>> createState() => _FinanceDataViewState<T>();
}

class _FinanceDataViewState<T> extends State<FinanceDataView<T>> {
  late final _cubit = AsyncDataCubit<T>(widget.load)..refresh();
  @override
  void initState() {
    super.initState();
    widget.controller?._refresh = _refresh;
  }

  @override
  void didUpdateWidget(covariant FinanceDataView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._refresh == _refresh) {
        oldWidget.controller?._refresh = null;
      }
      widget.controller?._refresh = _refresh;
    }
    if (oldWidget.load != widget.load) {
      _cubit.replaceLoader(widget.load);
    }
  }

  @override
  void dispose() {
    if (widget.controller?._refresh == _refresh) {
      widget.controller?._refresh = null;
    }
    _cubit.close();
    super.dispose();
  }

  Future<void> _refresh() => _cubit.refresh();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AsyncDataCubit<T>, AsyncDataState<T>>(
        bloc: _cubit,
        builder: (context, state) {
          if (state.status == DataStatus.initial ||
              state.status == DataStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == DataStatus.failure) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                KakeiboCard(
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 36),
                      const SizedBox(height: 12),
                      Text('${state.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: widget.builder(context, state.data as T, _refresh),
          );
        },
      );
}
