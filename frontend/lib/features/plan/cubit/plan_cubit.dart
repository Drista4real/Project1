import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';

/// The state of the plan screen.
class PlanState {
  const PlanState({
    this.plans = const [],
    this.selected,
    this.allocations = const [],
    this.loading = true,
    this.error,
  });

  final List<BudgetPlan> plans;
  final BudgetPlan? selected;
  final List<DailyAllocation> allocations;
  final bool loading;
  final String? error;

  PlanState copyWith({
    List<BudgetPlan>? plans,
    BudgetPlan? selected,
    List<DailyAllocation>? allocations,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => PlanState(
    plans: plans ?? this.plans,
    selected: selected ?? this.selected,
    allocations: allocations ?? this.allocations,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Loads the plans of the authenticated user and the active plan's projection.
class PlanCubit extends Cubit<PlanState> {
  PlanCubit(this.repository) : super(const PlanState());

  final BudgetPlanRepository repository;

  /// Load every plan and select the active one.
  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final plans = await repository.plans(activeOnly: true);
      if (plans.isEmpty) {
        emit(
          state.copyWith(
            plans: const [],
            selected: null,
            allocations: const [],
            loading: false,
          ),
        );
        return;
      }
      final selected = plans.first;
      final allocations = await repository.allocations(selected.id);
      emit(
        state.copyWith(
          plans: plans,
          selected: selected,
          allocations: allocations,
          loading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(loading: false, error: _message(error)));
    }
  }

  /// Select another plan and load its projection.
  Future<void> select(BudgetPlan plan) async {
    emit(state.copyWith(selected: plan, loading: true, clearError: true));
    try {
      final allocations = await repository.allocations(plan.id);
      emit(
        state.copyWith(
          selected: plan,
          allocations: allocations,
          loading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(loading: false, error: _message(error)));
    }
  }

  String _message(Object error) {
    if (error is FinanceApiException) return error.message;
    final text = error.toString();
    if (text.startsWith('FinanceApiException: ')) {
      return text.replaceFirst('FinanceApiException: ', '');
    }
    return 'Không tải được kế hoạch. Vui lòng thử lại.';
  }
}
