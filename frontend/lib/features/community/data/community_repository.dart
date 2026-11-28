import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/community/models/community_post.dart';

/// Contract for the multi-user public community feed.
abstract interface class CommunityRepository {
  Future<List<CommunityPost>> listPosts({int limit = 20, int offset = 0});

  Future<CommunityPost> publishPlan(int planId, {String? caption});

  Future<void> deletePost(int postId);

  Future<LikeToggleResult> toggleLike(int postId);

  Future<List<CommunityComment>> listComments(
    int postId, {
    int limit = 50,
    int offset = 0,
  });

  Future<CommunityComment> addComment(int postId, String content);
}

class BackendCommunityRepository implements CommunityRepository {
  BackendCommunityRepository({BackendClient? client})
    : client = client ?? BackendClient();

  final BackendClient client;

  @override
  Future<List<CommunityPost>> listPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await client.request(
      'GET',
      '/community/posts?limit=$limit&offset=$offset',
    );
    final items = (data as Map)['items'] as List? ?? const [];
    return items
        .whereType<Map>()
        .map((item) => CommunityPost.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<CommunityPost> publishPlan(int planId, {String? caption}) async {
    final trimmed = caption?.trim();
    final data = await client.request(
      'POST',
      '/community/posts',
      body: {
        'plan_id': planId,
        if (trimmed != null && trimmed.isNotEmpty) 'caption': trimmed,
      },
    );
    final post = (data as Map)['post'] as Map;
    return CommunityPost.fromJson(post.cast<String, dynamic>());
  }

  @override
  Future<void> deletePost(int postId) async {
    await client.request('DELETE', '/community/posts/$postId');
  }

  @override
  Future<LikeToggleResult> toggleLike(int postId) async {
    final data = await client.request('POST', '/community/posts/$postId/like');
    return LikeToggleResult.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<List<CommunityComment>> listComments(
    int postId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await client.request(
      'GET',
      '/community/posts/$postId/comments?limit=$limit&offset=$offset',
    );
    final items = (data as Map)['items'] as List? ?? const [];
    return items
        .whereType<Map>()
        .map((item) => CommunityComment.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<CommunityComment> addComment(int postId, String content) async {
    final data = await client.request(
      'POST',
      '/community/posts/$postId/comments',
      body: {'content': content},
    );
    final comment = (data as Map)['comment'] as Map;
    return CommunityComment.fromJson(comment.cast<String, dynamic>());
  }
}
