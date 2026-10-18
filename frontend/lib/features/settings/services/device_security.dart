import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Device authentication is separate from the user's Supabase session.
class DeviceSecurity {
  final LocalAuthentication _auth = LocalAuthentication();

  bool get supported =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);

  Future<bool> authenticate() async {
    if (!supported || !await _auth.isDeviceSupported()) {
      throw StateError(
        'Thiết bị chưa hỗ trợ khóa. Hãy thiết lập Face ID, vân tay hoặc mã khóa trong cài đặt thiết bị.',
      );
    }
    // Device credentials are a recovery option if biometrics are locked out.
    return _auth.authenticate(
      localizedReason: 'Xác thực để mở sổ tài chính Kakeibo Zen',
      persistAcrossBackgrounding: true,
    );
  }
}
