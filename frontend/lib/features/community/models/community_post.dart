import 'package:project_one/core/network/json_numbers.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';
import 'package:project_one/features/plan/widgets/plan_widgets.dart';

/// One group allocation summary inside a community spending post.
class CommunityGroupItem {
  const CommunityGroupItem({
    required this.key,
    required this.label,
    required this.dailyAmount,
    required this.totalAmount,
  });

  final String key;
  final String label;
  final num dailyAmount;
  final num totalAmount;

  factory CommunityGroupItem.fromJson(Map<String, dynamic> json) {
    final key = json['group_key'] as String? ?? '';
    return CommunityGroupItem(
      key: key,
      label: planGroupLabels[key] ?? key,
      dailyAmount: readDouble(json['daily_amount']) ?? 0,
      totalAmount: readDouble(json['total_amount']) ?? 0,
    );
  }
}

/// One comment attached to a community post.
class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.content,
    this.isOwnComment = false,
    required this.createdAt,
  });

  final int id;
  final int postId;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final bool isOwnComment;
  final DateTime createdAt;

  factory CommunityComment.fromJson(Map<String, dynamic> json) =>
      CommunityComment(
        id: readInt(json['id']) ?? 0,
        postId: readInt(json['post_id']) ?? 0,
        authorName: json['author_name'] as String? ?? 'Người dùng Kakeibo',
        authorAvatarUrl: json['author_avatar_url'] as String?,
        content: json['content'] as String? ?? '',
        isOwnComment: json['is_own_comment'] as bool? ?? false,
        createdAt:
            DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal() ??
            DateTime.now(),
      );
}

/// Result returned when toggling a like on a post.
class LikeToggleResult {
  const LikeToggleResult({
    required this.postId,
    required this.likedByMe,
    required this.likesCount,
  });

  final int postId;
  final bool likedByMe;
  final int likesCount;

  factory LikeToggleResult.fromJson(Map<String, dynamic> json) =>
      LikeToggleResult(
        postId: readInt(json['post_id']) ?? 0,
        likedByMe: json['liked_by_me'] as bool? ?? false,
        likesCount: readInt(json['likes_count']) ?? 0,
      );
}

/// A social post representing a shared spending & savings plan.
class CommunityPost {
  const CommunityPost({
    required this.id,
    this.planId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.isOwnPost,
    required this.title,
    this.caption,
    required this.totalIncome,
    required this.fixedExpenses,
    required this.savingsTarget,
    required this.spendableBudget,
    required this.dailyAllowance,
    required this.durationDays,
    this.startDate,
    required this.groups,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedByMe = false,
    this.createdAt,
  });

  final int id;
  final int? planId;
  final String authorName;
  final String? authorAvatarUrl;
  final bool isOwnPost;
  final String title;
  final String? caption;
  final num totalIncome;
  final num fixedExpenses;
  final num savingsTarget;
  final num spendableBudget;
  final num dailyAllowance;
  final int durationDays;
  final DateTime? startDate;
  final List<CommunityGroupItem> groups;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final DateTime? createdAt;

  /// Percentage of total income allocated to savings (0-100).
  int get savingsPercent {
    if (totalIncome <= 0) return 0;
    return ((savingsTarget / totalIncome) * 100).round().clamp(0, 100);
  }

  DateTime? get endDate {
    final start = startDate;
    if (start == null || durationDays <= 0) return null;
    return start.add(Duration(days: durationDays - 1));
  }

  CommunityPost copyWith({
    String? authorName,
    String? authorAvatarUrl,
    int? likesCount,
    int? commentsCount,
    bool? likedByMe,
  }) => CommunityPost(
    id: id,
    planId: planId,
    authorName: authorName ?? this.authorName,
    authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    isOwnPost: isOwnPost,
    title: title,
    caption: caption,
    totalIncome: totalIncome,
    fixedExpenses: fixedExpenses,
    savingsTarget: savingsTarget,
    spendableBudget: spendableBudget,
    dailyAllowance: dailyAllowance,
    durationDays: durationDays,
    startDate: startDate,
    groups: groups,
    likesCount: likesCount ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    likedByMe: likedByMe ?? this.likedByMe,
    createdAt: createdAt,
  );

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
    id: readInt(json['id']) ?? 0,
    planId: readInt(json['plan_id']),
    authorName: json['author_name'] as String? ?? 'Người dùng Kakeibo',
    authorAvatarUrl: json['author_avatar_url'] as String?,
    isOwnPost: json['is_own_post'] as bool? ?? false,
    title: json['title'] as String? ?? 'Kế hoạch chi tiêu',
    caption: json['caption'] as String?,
    totalIncome: readDouble(json['total_income']) ?? 0,
    fixedExpenses: readDouble(json['fixed_expenses']) ?? 0,
    savingsTarget: readDouble(json['savings_target']) ?? 0,
    spendableBudget: readDouble(json['spendable_budget']) ?? 0,
    dailyAllowance: readDouble(json['daily_allowance']) ?? 0,
    durationDays: readInt(json['duration_days']) ?? 1,
    startDate: DateTime.tryParse('${json['start_date'] ?? ''}'),
    groups: ((json['groups'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => CommunityGroupItem.fromJson(item.cast<String, dynamic>()),
        )
        .toList(),
    likesCount: readInt(json['likes_count']) ?? 0,
    commentsCount: readInt(json['comments_count']) ?? 0,
    likedByMe: json['liked_by_me'] as bool? ?? false,
    createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
  );

  /// Build a post directly from a local [BudgetPlan] (used in previews/tests).
  factory CommunityPost.fromBudgetPlan(
    BudgetPlan plan, {
    required String authorName,
    String? authorAvatarUrl,
    String? caption,
    int likesCount = 0,
    int commentsCount = 0,
    bool likedByMe = false,
  }) {
    return CommunityPost(
      id: plan.id,
      planId: plan.id,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      isOwnPost: true,
      title: plan.title,
      caption: caption,
      totalIncome: plan.totalIncome,
      fixedExpenses: plan.fixedExpenses,
      savingsTarget: plan.savingsTarget,
      spendableBudget: plan.spendableBudget,
      dailyAllowance: plan.dailyAllowance,
      durationDays: plan.durationDays,
      startDate: plan.startDate,
      groups: plan.groups
          .map(
            (g) => CommunityGroupItem(
              key: g.groupKey,
              label: planGroupLabels[g.groupKey] ?? g.groupKey,
              dailyAmount: g.dailyAmount,
              totalAmount: g.totalAmount,
            ),
          )
          .toList(),
      likesCount: likesCount,
      commentsCount: commentsCount,
      likedByMe: likedByMe,
    );
  }
}
