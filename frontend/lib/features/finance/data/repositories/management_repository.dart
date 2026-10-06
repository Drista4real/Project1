import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';

/// All operations use the signed-in user's backend session.
class BackendManagementRepository implements ManagementRepository {
  BackendManagementRepository({BackendClient? client})
    : _client = client ?? BackendClient();
  final BackendClient _client;

  @override
  Future<List<Map<String, dynamic>>> resources() async =>
      (await _client.request('GET', '/manage/resources') as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  @override
  Future<Map<String, dynamic>> page(String resource, {int offset = 0}) async =>
      Map<String, dynamic>.from(
        await _client.request(
              'GET',
              '/manage/$resource?limit=30&offset=$offset',
            )
            as Map,
      );

  @override
  Future<List<Map<String, dynamic>>> references(String resource) async {
    final items = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final path = resource == 'transactions'
          ? '/transactions'
          : '/manage/$resource';
      final page =
          await _client.request('GET', '$path?limit=100&offset=$offset') as Map;
      final batch = (page['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      items.addAll(batch);
      offset += batch.length;
      if (batch.isEmpty || offset >= (page['total'] as num).toInt()) break;
    }
    return items;
  }

  @override
  String key(String resource, Map<String, dynamic> record) =>
      resource == 'profile'
      ? 'me'
      : resource == 'transaction_tags'
      ? '${record['transaction_id']}:${record['tag_id']}'
      : '${record['id']}';

  @override
  Future<Map<String, dynamic>> get(String resource, String key) async =>
      Map<String, dynamic>.from(
        await _client.request('GET', '/manage/$resource/$key') as Map,
      );

  @override
  Future<void> save(
    String resource,
    Map<String, dynamic> values, {
    String? key,
  }) async {
    await _client.request(
      key == null ? 'POST' : 'PATCH',
      '/manage/$resource${key == null ? '' : '/$key'}',
      body: values,
    );
  }

  @override
  Future<Map<String, dynamic>> create(
    String resource,
    Map<String, dynamic> values,
  ) async => Map<String, dynamic>.from(
    await _client.request('POST', '/manage/$resource', body: values) as Map,
  );

  @override
  Future<void> delete(String resource, String key) async {
    await _client.request('DELETE', '/manage/$resource/$key');
  }
}
