import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/features/onboarding/cubit/monthly_setup_cubit.dart';
import 'package:project_one/features/onboarding/widgets/setup_steps.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';

/// The six-step monthly setup: from the money a user has to a daily allowance.
///
/// It opens by itself once after the first sign-in and from the home screen
/// any time later. Skipping it never blocks the rest of the app.
class MonthlySetupScreen extends StatefulWidget {
  const MonthlySetupScreen({super.key, this.repository, this.today});

  final BudgetPlanRepository? repository;

  /// The day the plan starts; tests pin it, the app uses the clock.
  final DateTime? today;

  @override
  State<MonthlySetupScreen> createState() => _MonthlySetupScreenState();
}

class _MonthlySetupScreenState extends State<MonthlySetupScreen> {
  late final MonthlySetupCubit _cubit = MonthlySetupCubit(
    widget.repository ?? BackendBudgetPlanRepository(),
    today: widget.today ?? DateTime.now(),
  )..start();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<MonthlySetupCubit, MonthlySetupState>(
        listenWhen: (previous, current) =>
            previous.created == null && current.created != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã tạo kế hoạch tháng của bạn.')),
          );
          context.go(AppRoutes.plan);
        },
        builder: (context, state) => PopScope(
          canPop: state.step == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _cubit.back();
          },
          child: Scaffold(
            body: SafeArea(
              child: state.loadingDefaults
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        _SetupTopBar(
                          step: state.step,
                          onBack: state.step == 0 ? _leave : _cubit.back,
                          onSkip: _leave,
                        ),
                        Expanded(child: _buildStep(context, state)),
                        _SetupFooter(
                          state: state,
                          onBack: _cubit.back,
                          onNext: _cubit.next,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, MonthlySetupState state) {
    final theme = Theme.of(context);
    final copy = setupStepCopy(state);
    return SingleChildScrollView(
      key: ValueKey('setup-step-${state.step}'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BƯỚC ${state.step + 1}/$monthlySetupSteps',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              copy.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (copy.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              copy.subtitle!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          setupStepBody(state),
        ],
      ),
    );
  }
}

class _SetupTopBar extends StatelessWidget {
  const _SetupTopBar({
    required this.step,
    required this.onBack,
    required this.onSkip,
  });

  final int step;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: step == 0 ? 'Đóng' : 'Quay lại',
            onPressed: onBack,
            icon: Icon(step == 0 ? Icons.close : Icons.arrow_back),
          ),
          Expanded(
            child: Semantics(
              label: 'Bước ${step + 1} trên $monthlySetupSteps',
              child: Row(
                children: [
                  for (var index = 0; index < monthlySetupSteps; index++) ...[
                    if (index > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 6,
                        decoration: BoxDecoration(
                          color: index <= step
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          TextButton(onPressed: onSkip, child: const Text('Bỏ qua')),
        ],
      ),
    );
  }
}

class _SetupFooter extends StatelessWidget {
  const _SetupFooter({
    required this.state,
    required this.onBack,
    required this.onNext,
  });

  final MonthlySetupState state;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (state.step > 0) ...[
            OutlinedButton(onPressed: onBack, child: const Text('Quay lại')),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('setup-next'),
              onPressed: state.canContinue ? onNext : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: state.submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(state.isLastStep ? Icons.check : Icons.arrow_forward),
              label: Text(state.isLastStep ? 'Bắt đầu kế hoạch' : 'Tiếp tục'),
            ),
          ),
        ],
      ),
    );
  }
}
