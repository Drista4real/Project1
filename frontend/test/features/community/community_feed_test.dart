import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/community/data/community_repository.dart';
import 'package:project_one/features/community/models/community_post.dart';
import 'package:project_one/features/community/widgets/community_feed_view.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';
import 'package:project_one/features/profile/user_profile_notifier.dart';

class _FakeManagementRepository implements ManagementRepository {
  @override
  Future<Map<String, dynamic>> get(String resource, String key) async => {
    'full_name': 'Đạt Đào',
    'email': 'dat@example.com',
    'avatar_url': 'preset:star',
  };

  @override
  Future<Map<String, dynamic>> create(String r, Map<String, dynamic> v) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String r, String k) => throw UnimplementedError();
  @override
  String key(String r, Map<String, dynamic> record) => 'me';
  @override
  Future<Map<String, dynamic>> page(String r, {int offset = 0}) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> references(String r) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> resources() => throw UnimplementedError();
  @override
  Future<void> save(String r, Map<String, dynamic> v, {String? key}) =>
      throw UnimplementedError();
}

class _FakeBudgetPlanRepository implements BudgetPlanRepository {
  _FakeBudgetPlanRepository(this.activePlans);

  final List<BudgetPlan> activePlans;

  @override
  Future<List<BudgetPlan>> plans({bool activeOnly = false}) async =>
      activePlans;

  @override
  Future<BudgetPlan> plan(int planId) async => activePlans.first;

  @override
  Future<List<DailyAllocation>> allocations(int planId) async => const [];

  @override
  Future<BudgetPlan> create(PlanDraft draft) => throw UnimplementedError();

  @override
  Future<PlanPreview> preview(PlanDraft draft) => throw UnimplementedError();

  @override
  Future<SetupDefaults> setupDefaults() => throw UnimplementedError();

  @override
  Future<PurchaseImpact> purchaseImpact({
    required int planId,
    required int currentDay,
    required num amount,
    String groupKey = 'lifestyle',
    String? category,
  }) => throw UnimplementedError();
}

class _FakeCommunityRepository implements CommunityRepository {
  _FakeCommunityRepository(this.posts);

  final List<CommunityPost> posts;
  final Map<int, List<CommunityComment>> commentsByPost = {};

  @override
  Future<List<CommunityPost>> listPosts({int limit = 20, int offset = 0}) async =>
      List.of(posts);

  @override
  Future<CommunityPost> publishPlan(int planId, {String? caption}) async {
    final newPost = CommunityPost(
      id: 99,
      planId: planId,
      authorName: 'Đạt Đào',
      authorAvatarUrl: 'preset:star',
      isOwnPost: true,
      title: 'Kế hoạch tháng 11',
      caption: caption,
      totalIncome: 3000000,
      fixedExpenses: 1500000,
      savingsTarget: 300000,
      spendableBudget: 1200000,
      dailyAllowance: 40000,
      durationDays: 30,
      startDate: DateTime(2026, 11, 25),
      groups: const [
        CommunityGroupItem(
          key: 'food',
          label: 'Ăn uống',
          dailyAmount: 24000,
          totalAmount: 720000,
        ),
      ],
    );
    posts.insert(0, newPost);
    return newPost;
  }

  @override
  Future<void> deletePost(int postId) async {
    posts.removeWhere((p) => p.id == postId);
  }

  @override
  Future<LikeToggleResult> toggleLike(int postId) async {
    final idx = posts.indexWhere((p) => p.id == postId);
    final current = posts[idx];
    final nextLiked = !current.likedByMe;
    final nextCount = nextLiked
        ? current.likesCount + 1
        : current.likesCount - 1;
    posts[idx] = current.copyWith(likedByMe: nextLiked, likesCount: nextCount);
    return LikeToggleResult(
      postId: postId,
      likedByMe: nextLiked,
      likesCount: nextCount,
    );
  }

  @override
  Future<List<CommunityComment>> listComments(
    int postId, {
    int limit = 50,
    int offset = 0,
  }) async => List.of(commentsByPost[postId] ?? const []);

  @override
  Future<CommunityComment> addComment(int postId, String content) async {
    final comment = CommunityComment(
      id: 1,
      postId: postId,
      authorName: 'Đạt Đào',
      authorAvatarUrl: 'preset:star',
      content: content,
      isOwnComment: true,
      createdAt: DateTime(2026, 11, 28, 10, 0),
    );
    commentsByPost.putIfAbsent(postId, () => []).add(comment);
    return comment;
  }
}

BudgetPlan _samplePlan() => BudgetPlan(
  id: 42,
  title: 'Kế hoạch tháng 11',
  status: 'ACTIVE',
  totalIncome: 3000000,
  durationDays: 30,
  savingsTarget: 300000,
  fixedExpenses: 1500000,
  startDate: DateTime(2026, 11, 25),
  spendableBudget: 1200000,
  dailyAllowance: 40000,
  survivalFloor: 50000,
  planVersion: 1,
  configVersion: 'budget-engine-v1',
  groups: const [
    PlanGroup(
      groupKey: 'food',
      pillar: 'needs',
      dailyAmount: 24000,
      totalAmount: 720000,
    ),
    PlanGroup(
      groupKey: 'transport',
      pillar: 'needs',
      dailyAmount: 6000,
      totalAmount: 180000,
    ),
    PlanGroup(
      groupKey: 'lifestyle',
      pillar: 'wants',
      dailyAmount: 10000,
      totalAmount: 300000,
    ),
  ],
);

void main() {
  testWidgets(
    'CommunityFeedView shows posts from other users and supports like, comment, share & publish',
    (tester) async {
      final profileNotifier = UserProfileNotifier(_FakeManagementRepository());
      await profileNotifier.syncForUser('u1');
      final planRepo = _FakeBudgetPlanRepository([_samplePlan()]);
      final communityRepo = _FakeCommunityRepository([
        CommunityPost(
          id: 7,
          planId: 10,
          authorName: 'Minh Anh',
          authorAvatarUrl: 'preset:leaf',
          isOwnPost: false,
          title: 'Kế hoạch tiết kiệm',
          caption: 'Mục tiêu để dành 20% tháng này!',
          totalIncome: 5000000,
          fixedExpenses: 1500000,
          savingsTarget: 1000000,
          spendableBudget: 2500000,
          dailyAllowance: 83333,
          durationDays: 30,
          startDate: DateTime(2026, 11, 25),
          groups: const [
            CommunityGroupItem(
              key: 'food',
              label: 'Ăn uống',
              dailyAmount: 50000,
              totalAmount: 1500000,
            ),
            CommunityGroupItem(
              key: 'transport',
              label: 'Đi lại',
              dailyAmount: 13333,
              totalAmount: 400000,
            ),
            CommunityGroupItem(
              key: 'lifestyle',
              label: 'Chi tiêu linh hoạt',
              dailyAmount: 20000,
              totalAmount: 600000,
            ),
          ],
          likesCount: 2,
          commentsCount: 0,
          likedByMe: false,
          createdAt: DateTime(2026, 11, 27, 10, 0),
        ),
      ]);
      String? sharedText;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityFeedView(
              communityRepository: communityRepo,
              planRepository: planRepo,
              profileNotifier: profileNotifier,
              today: DateTime(2026, 11, 27, 12, 0),
              onShareText: (text) async => sharedText = text,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Another user's post is visible
      expect(find.text('Minh Anh'), findsOneWidget);
      expect(find.text('Mục tiêu để dành 20% tháng này!'), findsOneWidget);
      expect(find.text('MỤC TIÊU TIẾT KIỆM'), findsOneWidget);
      expect(find.text('20% thu nhập'), findsOneWidget);
      expect(find.text('LỊCH TRÌNH CHI TIÊU (30 NGÀY)'), findsOneWidget);
      expect(find.text('Ngày 3/30'), findsOneWidget);
      // Not own post -> no "Của bạn" badge or delete menu
      expect(find.text('Của bạn'), findsNothing);

      // Like
      final likeBtn = find.byKey(const ValueKey('post-like-7'));
      await tester.ensureVisible(likeBtn);
      await tester.tap(likeBtn);
      await tester.pumpAndSettle();
      expect(find.text('Thích (3)'), findsOneWidget);

      // Comment
      await tester.tap(find.byKey(const ValueKey('post-comment-7')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('community-comment-input')),
        'Tuyệt vời quá!',
      );
      await tester.tap(find.byKey(const ValueKey('community-comment-send')));
      await tester.pumpAndSettle();
      expect(find.text('Tuyệt vời quá!'), findsOneWidget);
      expect(find.text('Bình luận (1)'), findsWidgets);

      Navigator.of(
        tester.element(find.byKey(const ValueKey('community-comment-input'))),
      ).pop();
      await tester.pumpAndSettle();

      // Share
      await tester.tap(find.byKey(const ValueKey('post-share-7')));
      await tester.pump();
      expect(sharedText, contains('Minh Anh'));

      // Publish own plan
      final publishBtn = find.byKey(const ValueKey('community-publish-button'));
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('publish-caption-field')),
        'Kế hoạch mới của Đạt',
      );
      final submitBtn = find.byKey(const ValueKey('publish-submit-button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Kế hoạch mới của Đạt'), findsOneWidget);
      expect(find.text('Của bạn'), findsOneWidget);
    },
  );

  testWidgets('CommunityFeedView shows empty prompt when feed has no posts', (
    tester,
  ) async {
    final profileNotifier = UserProfileNotifier(_FakeManagementRepository());
    await profileNotifier.syncForUser('u1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityFeedView(
            communityRepository: _FakeCommunityRepository([]),
            planRepository: _FakeBudgetPlanRepository(const []),
            profileNotifier: profileNotifier,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có bài đăng nào trong Cộng đồng'), findsOneWidget);
    expect(find.text('Chia sẻ kế hoạch của tôi'), findsOneWidget);
  });
}
