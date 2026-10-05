import 'package:flutter/material.dart';

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
  late Future<T> _future = widget.load();
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
      _future = widget.load();
    }
  }

  @override
  void dispose() {
    if (widget.controller?._refresh == _refresh) {
      widget.controller?._refresh = null;
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final next = widget.load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      /* FutureBuilder presents the error. */
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            KakeiboCard(
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 36),
                  const SizedBox(height: 12),
                  Text('${snapshot.error}', textAlign: TextAlign.center),
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
        child: widget.builder(context, snapshot.data as T, _refresh),
      );
    },
  );
}
