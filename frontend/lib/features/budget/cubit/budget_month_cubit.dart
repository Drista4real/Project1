import 'package:flutter_bloc/flutter_bloc.dart';

class BudgetMonthCubit extends Cubit<DateTime> {
  BudgetMonthCubit({DateTime? now})
    : super(
        DateTime((now ?? DateTime.now()).year, (now ?? DateTime.now()).month),
      );

  void move(int delta) => emit(DateTime(state.year, state.month + delta));
}
