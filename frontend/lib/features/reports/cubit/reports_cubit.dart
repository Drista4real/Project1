import 'package:flutter_bloc/flutter_bloc.dart';

class ReportsState {
  const ReportsState({
    this.period = 'Tháng',
    this.activeTab = 'history',
    required this.anchor,
  });
  final String period;
  final String activeTab;
  final DateTime anchor;

  (DateTime, DateTime) get range => switch (period) {
    'Tuần' => (
      DateTime(anchor.year, anchor.month, anchor.day - anchor.weekday + 1),
      DateTime(anchor.year, anchor.month, anchor.day - anchor.weekday + 8),
    ),
    'Năm' => (DateTime(anchor.year), DateTime(anchor.year + 1)),
    _ => (
      DateTime(anchor.year, anchor.month),
      DateTime(anchor.year, anchor.month + 1),
    ),
  };
}

class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit({DateTime? now})
    : super(ReportsState(anchor: now ?? DateTime.now()));
  void selectPeriod(String period) => emit(
    ReportsState(
      period: period,
      activeTab: state.activeTab,
      anchor: state.anchor,
    ),
  );
  void selectTab(String tab) => emit(
    ReportsState(period: state.period, activeTab: tab, anchor: state.anchor),
  );
  void move(int step) => emit(
    ReportsState(
      period: state.period,
      activeTab: state.activeTab,
      anchor: switch (state.period) {
        'Tuần' => DateTime(
          state.anchor.year,
          state.anchor.month,
          state.anchor.day + step * 7,
        ),
        'Năm' => DateTime(state.anchor.year + step, state.anchor.month),
        _ => DateTime(state.anchor.year, state.anchor.month + step),
      },
    ),
  );
}
