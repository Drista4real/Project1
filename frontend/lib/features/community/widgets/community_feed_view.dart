import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/features/community/data/community_repository.dart';
import 'package:project_one/features/community/models/community_post.dart';
import 'package:project_one/features/community/widgets/community_comments_sheet.dart';
import 'package:project_one/features/community/widgets/spending_post_card.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';
import 'package:project_one/features/profile/user_profile_notifier.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import 'package:project_one/shared/widgets/kakeibo_card.dart';
import 'package:project_one/shared/widgets/user_avatar.dart';
import 'package:share_plus/share_plus.dart';

/// Public social feed showing plans shared by all authenticated users.
class CommunityFeedView extends StatefulWidget {
  const CommunityFeedView({
    super.key,
    this.communityRepository,
    this.planRepository,
    this.profileNotifier,
    this.today,
    this.onShareText,
  });

  final CommunityRepository? communityRepository;
  final BudgetPlanRepository? planRepository;
  final UserProfileNotifier? profileNotifier;
  final DateTime? today;
  final Future<void> Function(String text)? onShareText;

  @override
  State<CommunityFeedView> createState() => _CommunityFeedViewState();
}

class _CommunityFeedViewState extends State<CommunityFeedView> {
  late final CommunityRepository _communityRepository =
      widget.communityRepository ?? BackendCommunityRepository();
  late final BudgetPlanRepository _planRepository =
      widget.planRepository ?? BackendBudgetPlanRepository();

  UserProfileNotifier get _profileNotifier =>
      widget.profileNotifier ?? AppDependencies.userProfile;

  List<CommunityPost> _posts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_profileNotifier.loaded && !_profileNotifier.loading) {
        _profileNotifier.load();
      }
    });
  }

  Future<void> _loadFeed({bool refreshProfile = false}) async {
    if (mounted) {
      setState(() {
        if (_posts.isEmpty) _loading = true;
        _error = null;
      });
    }
    try {
      final postsFuture = _communityRepository.listPosts();
      if (refreshProfile) {
        await _profileNotifier.load(force: true);
      }
      final posts = await postsFuture;
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$err';
      });
    }
  }

  Future<void> _toggleLike(CommunityPost post) async {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index < 0) return;

    final optimistic = post.copyWith(
      likedByMe: !post.likedByMe,
      likesCount: (post.likedByMe ? post.likesCount - 1 : post.likesCount + 1)
          .clamp(0, 999999),
    );
    setState(() {
      final updated = List<CommunityPost>.of(_posts);
      updated[index] = optimistic;
      _posts = updated;
    });

    try {
      final result = await _communityRepository.toggleLike(post.id);
      if (!mounted) return;
      final currentIdx = _posts.indexWhere((p) => p.id == post.id);
      if (currentIdx >= 0) {
        setState(() {
          final updated = List<CommunityPost>.of(_posts);
          updated[currentIdx] = updated[currentIdx].copyWith(
            likedByMe: result.likedByMe,
            likesCount: result.likesCount,
          );
          _posts = updated;
        });
      }
    } catch (err) {
      if (!mounted) return;
      final revertIdx = _posts.indexWhere((p) => p.id == post.id);
      if (revertIdx >= 0) {
        setState(() {
          final updated = List<CommunityPost>.of(_posts);
          updated[revertIdx] = post;
          _posts = updated;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không cập nhật được lượt thích: $err')),
      );
    }
  }

  Future<void> _openComments(CommunityPost post) async {
    await showCommunityCommentsSheet(
      context,
      post: post,
      onLoadComments: () => _communityRepository.listComments(post.id),
      onAddComment: (content) async {
        final created = await _communityRepository.addComment(post.id, content);
        if (mounted) {
          final idx = _posts.indexWhere((p) => p.id == post.id);
          if (idx >= 0) {
            setState(() {
              final updated = List<CommunityPost>.of(_posts);
              updated[idx] = updated[idx].copyWith(
                commentsCount: updated[idx].commentsCount + 1,
              );
              _posts = updated;
            });
          }
        }
        return created;
      },
    );
  }

  Future<void> _deletePost(CommunityPost post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gỡ bài đăng?'),
        content: const Text(
          'Bài đăng sẽ được gỡ khỏi bảng tin Cộng đồng. Kế hoạch chi tiêu cá nhân của bạn vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Gỡ bài'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _communityRepository.deletePost(post.id);
      if (!mounted) return;
      setState(() {
        _posts = _posts.where((p) => p.id != post.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gỡ bài đăng khỏi Cộng đồng.')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không gỡ được bài đăng: $err')),
      );
    }
  }

  Future<void> _openPublishSheet() async {
    List<BudgetPlan> plans = const [];
    try {
      plans = await _planRepository.plans(activeOnly: true);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được danh sách kế hoạch: $err')),
      );
      return;
    }
    if (!mounted) return;
    if (plans.isEmpty) {
      context.push(AppRoutes.monthlySetup);
      return;
    }

    final published = await showModalBottomSheet<CommunityPost>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _PublishPlanSheet(
        plans: plans,
        onPublish: (planId, caption) =>
            _communityRepository.publishPlan(planId, caption: caption),
      ),
    );
    if (published != null && mounted) {
      setState(() {
        _posts = [
          published,
          ..._posts.where((p) => p.id != published.id),
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã chia sẻ kế hoạch lên Cộng đồng!')),
      );
    }
  }

  Future<void> _sharePost(CommunityPost post) async {
    final buffer = StringBuffer()
      ..writeln('🗓️ ${post.title} (${post.durationDays} ngày)')
      ..writeln('👤 ${post.authorName}')
      ..writeln('🎯 Mục tiêu tiết kiệm: ${formatVnd(post.savingsTarget)}')
      ..writeln('💰 Hạn mức mỗi ngày: ${formatVnd(post.dailyAllowance)}');
    for (final group in post.groups) {
      buffer.writeln('  • ${group.label}: ${formatVnd(group.dailyAmount)}/ngày');
    }
    buffer.write('\n✨ Quản lý chi tiêu cùng Kakeibo Zen!');
    final text = buffer.toString();

    if (widget.onShareText != null) {
      await widget.onShareText!(text);
      return;
    }
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _profileNotifier,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _posts.isEmpty) {
      return _buildStatusCard(
        context,
        title: 'Không tải được bảng tin cộng đồng',
        message: _error!,
        actionLabel: 'Thử lại',
        actionIcon: Icons.refresh_rounded,
        onAction: () => _loadFeed(refreshProfile: true),
      );
    }

    final authorName = _profileNotifier.displayName;
    final avatarUrl = _profileNotifier.avatarUrl;

    return RefreshIndicator(
      onRefresh: () => _loadFeed(refreshProfile: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _CommunityComposerHeader(
            authorName: authorName,
            avatarUrl: avatarUrl,
            onPublishTap: _openPublishSheet,
          ),
          const SizedBox(height: 14),
          if (_posts.isEmpty)
            _EmptyCommunityFeedCard(onPublishTap: _openPublishSheet)
          else
            for (var i = 0; i < _posts.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              SpendingPostCard(
                post: _posts[i],
                today: widget.today,
                onToggleLike: () => _toggleLike(_posts[i]),
                onOpenComments: () => _openComments(_posts[i]),
                onShare: () => _sharePost(_posts[i]),
                onOpenPlan: _posts[i].isOwnPost
                    ? () => context.push(AppRoutes.plan)
                    : null,
                onDelete: _posts[i].isOwnPost
                    ? () => _deletePost(_posts[i])
                    : null,
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        KakeiboCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityComposerHeader extends StatelessWidget {
  const _CommunityComposerHeader({
    required this.authorName,
    required this.avatarUrl,
    required this.onPublishTap,
  });

  final String authorName;
  final String? avatarUrl;
  final VoidCallback onPublishTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return KakeiboCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          UserAvatar(
            radius: 20,
            avatarUrl: avatarUrl,
            displayName: authorName,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cộng đồng Kakeibo',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chia sẻ mục tiêu tiết kiệm & lịch chi tiêu',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            key: const ValueKey('community-publish-button'),
            onPressed: onPublishTap,
            icon: const Icon(Icons.campaign_outlined, size: 18),
            label: const Text('Đăng bài'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCommunityFeedCard extends StatelessWidget {
  const _EmptyCommunityFeedCard({required this.onPublishTap});

  final VoidCallback onPublishTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return KakeiboCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.people_outline_rounded,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chưa có bài đăng nào trong Cộng đồng',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hãy là người đầu tiên chia sẻ mục tiêu tiết kiệm và lịch trình '
            'chi tiêu của bạn để mọi người cùng theo dõi và cổ vũ!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPublishTap,
            icon: const Icon(Icons.publish_rounded, size: 18),
            label: const Text('Chia sẻ kế hoạch của tôi'),
          ),
        ],
      ),
    );
  }
}

class _PublishPlanSheet extends StatefulWidget {
  const _PublishPlanSheet({
    required this.plans,
    required this.onPublish,
  });

  final List<BudgetPlan> plans;
  final Future<CommunityPost> Function(int planId, String? caption) onPublish;

  @override
  State<_PublishPlanSheet> createState() => _PublishPlanSheetState();
}

class _PublishPlanSheetState extends State<_PublishPlanSheet> {
  late int _selectedPlanId = widget.plans.first.id;
  final _captionController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final post = await widget.onPublish(
        _selectedPlanId,
        _captionController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(post);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '$err';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chia sẻ kế hoạch lên Cộng đồng',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mọi người dùng đã đăng nhập đều có thể xem mục tiêu tiết kiệm và lịch chi tiêu của bài đăng này.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chọn kế hoạch',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final plan in widget.plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: _submitting
                      ? null
                      : () => setState(() => _selectedPlanId = plan.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedPlanId == plan.id
                          ? scheme.primaryContainer.withValues(alpha: 0.4)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedPlanId == plan.id
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: _selectedPlanId == plan.id ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedPlanId == plan.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: _selectedPlanId == plan.id
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${plan.title} (${plan.durationDays} ngày)',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tiết kiệm: ${formatVnd(plan.savingsTarget)} • Chi/ngày: ${formatVnd(plan.dailyAllowance)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('publish-caption-field'),
              controller: _captionController,
              enabled: !_submitting,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Lời nhắn (tùy chọn)',
                hintText: 'Ví dụ: Quyết tâm để dành 10% tháng này!',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: const ValueKey('publish-submit-button'),
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.campaign_outlined),
                label: const Text('Đăng lên Cộng đồng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
