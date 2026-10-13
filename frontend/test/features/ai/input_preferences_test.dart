import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_one/features/ai/services/input_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'remembered categories ignore amount and are scoped to each user',
    () async {
      final alice = LocalInputPreferences(() => 'alice');
      final bob = LocalInputPreferences(() => 'bob');
      await alice.remember('bún bò 65000 đồng tiền mặt', 3);
      expect(await alice.category('bún bò 70000 đồng tiền mặt'), 3);
      expect(await bob.category('bún bò 65000 đồng tiền mặt'), isNull);
      expect(await alice.category('tiền nhà 65000 đồng tiền mặt'), isNull);
    },
  );
}
