abstract class ManagementRepository {
  Future<List<Map<String, dynamic>>> resources();
  Future<Map<String, dynamic>> page(String resource, {int offset = 0});
  Future<List<Map<String, dynamic>>> references(String resource);
  String key(String resource, Map<String, dynamic> record);
  Future<Map<String, dynamic>> get(String resource, String key);
  Future<void> save(
    String resource,
    Map<String, dynamic> values, {
    String? key,
  });
  Future<void> delete(String resource, String key);
}
