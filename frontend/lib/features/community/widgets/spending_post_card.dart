import 'package:flutter/material.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/community/models/community_post.dart';
import 'package:project_one/features/plan/widgets/plan_widgets.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import 'package:project_one/shared/widgets/kakeibo_card.dart';
import 'package:project_one/shared/widgets/user_avatar.dart';

/// Social feed card highlighting Savings Goal & Monthly Spending Schedule.
class SpendingPostCard extends StatelessWidget {
  const SpendingPostCard({
    super.key,
    required this.post,
    required this.onToggleLike,
    required this.onOpenComments,
    required this.onShare,
    this.onOpenPlan,
    this.onDelete,
    this.today,
  });

  final CommunityPost post;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenComments;
  final VoidCallback onShare;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onDelete;
  final DateTime? today;

  String _formatShortDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  String _dateRangeLabel() {
    final start = post.startDate;
    final end = post.endDate;
    if (start != null && end != null) {
      return '${_formatShortDate(start)} – ${_formatShortDate(end)}';
    }
    return '${post.durationDays} ngày';
  }

  String? _relativeTimeLabel() {
    final created = post.createdAt;
    if (created == null) return null;
    final now = today ?? DateTime.now();
    final diff = now.difference(created);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return _formatShortDate(created);
  }

  int _elapsedDays() {
    final start = post.startDate;
    if (start == null || post.durationDays <= 0) return 0;
    final now = today ?? DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final startOnly = DateTime(start.year, start.month, start.day);
    final diff = todayOnly.difference(startOnly).inDays + 1;
    return diff.clamp(0, post.durationDays);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final elapsed = _elapsedDays();
    final progress = post.durationDays > 0
        ? (elapsed / post.durationDays).clamp(0.0, 1.0)
        : 0.0;
    final relativeTime = _relativeTimeLabel();

    return KakeiboCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header: author avatar, name, schedule range & optional delete menu
          Row(
            children: [
              UserAvatar(
                radius: 21,
                avatarUrl: post.authorAvatarUrl,
                displayName: post.authorName,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (post.isOwnPost) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Của bạn',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        post.title,
                        _dateRangeLabel(),
                        ?relativeTime,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.isOwnPost && onDelete != null)
                PopupMenuButton<String>(
                  key: ValueKey('post-menu-${post.id}'),
                  tooltip: 'Tùy chọn bài đăng',
                  onSelected: (value) {
                    if (value == 'delete') onDelete!();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Gỡ khỏi cộng đồng'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (post.caption != null && post.caption!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.caption!.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
          const SizedBox(height: 14),

          // HIGHLIGHT 1: Savings goal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryForestGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.savings_rounded,
                      size: 16,
                      color: Color(0xFFA7F3D0),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'MỤC TIÊU TIẾT KIỆM',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFA7F3D0),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const Spacer(),
                    if (post.totalIncome > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${post.savingsPercent}% thu nhập',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatVnd(post.savingsTarget),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Thu nhập: ${formatVnd(post.totalIncome)}  •  Chi cố định: ${formatVnd(post.fixedExpenses)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // HIGHLIGHT 2: Monthly / Period Spending Schedule
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'LỊCH TRÌNH CHI TIÊU (${post.durationDays} NGÀY)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (post.isOwnPost && onOpenPlan != null)
                      InkWell(
                        onTap: onOpenPlan,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Xem lịch',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: scheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatVnd(post.dailyAllowance),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ ngày',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Khả chi: ${formatVnd(post.spendableBudget)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (post.groups.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < post.groups.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _GroupScheduleTile(group: post.groups[i]),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: scheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            scheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Ngày $elapsed/${post.durationDays}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // Social Action Bar: Like, Comment, Share
          Row(
            children: [
              _PostActionButton(
                key: ValueKey('post-like-${post.id}'),
                icon: post.likedByMe
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: post.likesCount > 0
                    ? 'Thích (${post.likesCount})'
                    : 'Thích',
                color: post.likedByMe ? const Color(0xFFE11D48) : null,
                onTap: onToggleLike,
              ),
              const SizedBox(width: 6),
              _PostActionButton(
                key: ValueKey('post-comment-${post.id}'),
                icon: Icons.chat_bubble_outline_rounded,
                label: post.commentsCount > 0
                    ? 'Bình luận (${post.commentsCount})'
                    : 'Bình luận',
                onTap: onOpenComments,
              ),
              const Spacer(),
              _PostActionButton(
                key: ValueKey('post-share-${post.id}'),
                icon: Icons.share_outlined,
                label: 'Chia sẻ',
                onTap: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupScheduleTile extends StatelessWidget {
  const _GroupScheduleTile({required this.group});

  final CommunityGroupItem group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = planGroupIcons[group.key] ?? Icons.category_outlined;
    final accent = planPillarOf(group.key).color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  group.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatVnd(group.dailyAmount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostActionButton extends StatelessWidget {
  const _PostActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effective = color ?? theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: effective),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: effective,
                fontWeight: color != null ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
