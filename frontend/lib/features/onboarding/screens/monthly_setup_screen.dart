import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/app/widgets/app_exit_button.dart';
import 'package:project_one/features/community/data/community_repository.dart';
import 'package:project_one/features/onboarding/cubit/monthly_setup_cubit.dart';
import 'package:project_one/features/onboarding/widgets/setup_steps.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:share_plus/share_plus.dart';

/// The six-step monthly setup: from the money a user has to a daily allowance.
///
/// It opens by itself once after the first sign-in and from the home screen
/// any time later. Skipping it never blocks the rest of the app.
class MonthlySetupScreen extends StatefulWidget {
  const MonthlySetupScreen({
    super.key,
    this.repository,
    this.communityRepository,
    this.today,
    this.syncBalance,
  });

  final BudgetPlanRepository? repository;
  final CommunityRepository? communityRepository;

  /// Writes the stated balance to the ledger; tests replace the backend.
  final BalanceSync? syncBalance;

  /// The day the plan starts; tests pin it, the app uses the clock.
  final DateTime? today;

  @override
  State<MonthlySetupScreen> createState() => _MonthlySetupScreenState();
}

class _MonthlySetupScreenState extends State<MonthlySetupScreen> {
  late final MonthlySetupCubit _cubit = MonthlySetupCubit(
    widget.repository ?? BackendBudgetPlanRepository(),
    today: widget.today ?? DateTime.now(),
    syncBalance: widget.syncBalance,
  )..start();

  bool _shareOnFinish = false;

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _leave() {
    if (_cubit.state.submitting) return;
    popOrGo(context);
  }

  void _back() {
    if (_cubit.state.submitting) return;
    if (_cubit.state.step == 0) {
      _leave();
    } else {
      _cubit.back();
    }
  }

  /// Chia sẻ bản tóm tắt kế hoạch chi tiêu, đăng lên Cộng đồng rồi bắt đầu kế hoạch.
  Future<void> _shareAndStart(MonthlySetupState state) async {
    final preview = state.preview;
    if (preview == null || state.submitting) return;
    _shareOnFinish = true;

    final days = state.durationDays;
    final daily = preview.dailyAllowance;

    String fmt(num v) => v
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );

    num groupAmount(String key) =>
        preview.groups
            .where((g) => g.groupKey == key)
            .map((g) => g.dailyAmount)
            .fold<num>(0, (a, b) => a + b);

    final food = groupAmount('food');
    final transport = groupAmount('transport');
    final lifestyle = groupAmount('lifestyle');

    final text = '🗓️ Kế hoạch chi tiêu của tôi ($days ngày)\n'
        '💰 Mỗi ngày được chi: ${fmt(daily)}đ\n'
        '🍜 Ăn uống: ${fmt(food)}đ/ngày\n'
        '🚌 Đi lại: ${fmt(transport)}đ/ngày\n'
        '🛍️ Chi tiêu linh hoạt: ${fmt(lifestyle)}đ/ngày\n'
        '\n✨ Quản lý tài chính cùng Kakeibo Zen!';

    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      // Ignore native share sheet cancellation/errors and still finish setup.
    }
    if (!mounted) return;
    _cubit.next();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<MonthlySetupCubit, MonthlySetupState>(
        listenWhen: (previous, current) =>
            previous.created == null && current.created != null,
        listener: (context, state) async {
          final created = state.created!;
          final shouldPublish = _shareOnFinish;
          _shareOnFinish = false;

          String? communityError;
          if (shouldPublish) {
            try {
              final repo =
                  widget.communityRepository ?? BackendCommunityRepository();
              await repo.publishPlan(created.id);
            } catch (err) {
              communityError = '$err';
            }
          }
          if (!context.mounted) return;

          final synced = state.balanceSyncError == null;
          final message = shouldPublish
              ? (communityError == null
                    ? 'Đã tạo kế hoạch và đăng lên Cộng đồng!'
                    : 'Đã tạo kế hoạch, nhưng chưa đăng lên Cộng đồng: $communityError')
              : (synced
                    ? 'Đã tạo kế hoạch và cập nhật số dư trong Sổ thu chi.'
                    : 'Đã tạo kế hoạch, nhưng chưa cập nhật được số dư: '
                          '${state.balanceSyncError}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          context.go(shouldPublish ? AppRoutes.community : AppRoutes.plan);
        },
        builder: (context, state) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _SetupTopBar(
                    step: state.step,
                    busy: state.submitting,
                    onBack: _back,
                    onSkip: _leave,
                  ),
                  Expanded(
                    child: state.loadingDefaults
                        ? const Center(child: CircularProgressIndicator())
                        : _buildStep(context, state),
                  ),
                  if (!state.loadingDefaults)
                    _SetupFooter(
                      state: state,
                      onBack: _cubit.back,
                      onNext: _cubit.next,
                      onShare: () => _shareAndStart(state),
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
    required this.busy,
    required this.onBack,
    required this.onSkip,
  });

  final int step;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          AppExitButton(close: step == 0, enabled: !busy, onPressed: onBack),
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
          TextButton(
            onPressed: busy ? null : onSkip,
            child: const Text('Bỏ qua'),
          ),
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
    this.onShare,
  });

  final MonthlySetupState state;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (state.step > 0) ...[
                OutlinedButton(
                  onPressed: state.submitting ? null : onBack,
                  child: const Text('Quay lại'),
                ),
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
          if (state.isLastStep) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                key: const ValueKey('setup-share'),
                onPressed: (state.canContinue && !state.submitting && onShare != null)
                    ? onShare
                    : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: scheme.primary),
                  foregroundColor: scheme.primary,
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Bắt đầu và chia sẻ kế hoạch'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
