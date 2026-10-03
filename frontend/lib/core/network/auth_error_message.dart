import 'package:supabase_flutter/supabase_flutter.dart';

String authErrorMessage(AuthException error) {
  if (error.statusCode == '404') {
    return 'Không tìm thấy dịch vụ đăng nhập. Kiểm tra URL Supabase trong cấu hình ứng dụng.';
  }
  if (error.code == 'over_email_send_rate_limit') {
    return 'Dịch vụ đã đạt giới hạn gửi email xác nhận. Vui lòng thử lại sau.';
  }
  if (error.statusCode == '429' || error.code == 'over_request_rate_limit') {
    return 'Dịch vụ đang giới hạn số yêu cầu. Vui lòng chờ rồi thử lại.';
  }
  return switch (error.code) {
    'email_not_confirmed' =>
      'Vui lòng mở email xác nhận tài khoản trước khi đăng nhập.',
    'signup_disabled' => 'Dự án hiện chưa cho phép đăng ký tài khoản mới.',
    'email_provider_disabled' =>
      'Đăng nhập bằng email chưa được bật cho dự án này.',
    'weak_password' =>
      'Mật khẩu chưa đủ mạnh. Hãy dùng mật khẩu dài hơn, có chữ, số và ký tự đặc biệt.',
    'email_address_invalid' =>
      'Địa chỉ email không hợp lệ. Vui lòng kiểm tra lại.',
    'email_address_not_authorized' =>
      'Dịch vụ gửi email hiện chưa hỗ trợ địa chỉ này. Vui lòng liên hệ quản trị viên.',
    'captcha_failed' =>
      'Xác minh chống spam chưa thành công. Vui lòng thử lại hoặc liên hệ hỗ trợ.',
    'user_already_exists' => 'Tài khoản đã tồn tại. Hãy đăng nhập.',
    'invalid_credentials' => 'Email hoặc mật khẩu không đúng.',
    _ =>
      error.statusCode != null &&
              int.tryParse(error.statusCode!) != null &&
              int.parse(error.statusCode!) >= 500
          ? 'Máy chủ chưa thể tạo hoặc xác thực tài khoản. Vui lòng thử lại sau.'
          : 'Không thể xác thực tài khoản. Kiểm tra email, mật khẩu và thử lại.',
  };
}
