String financeApiErrorMessage(int status, String path, Object? detail) {
  final walletIncome = RegExp(
    r'^/manage/accounts/[^/]+/initial-income$',
  ).hasMatch(path);
  if (walletIncome &&
      ((status == 404 && (detail == null || detail == 'Not Found')) ||
          status == 405)) {
    return 'Backend đang chạy chưa có chức năng thu nhập ví. Build và khởi động lại API sau khi chạy migration.';
  }
  if (path.startsWith('/manage/') &&
      {403, 409, 422, 503}.contains(status) &&
      detail is String &&
      detail.length <= 2000) {
    return detail;
  }
  // The chat API answers with an actionable Vietnamese message, so the
  // detail is more useful than the generic status text. A 429 is the
  // provider's daily allowance, which the user must be told about.
  if (path.startsWith('/chat') &&
      {400, 404, 422, 429, 503}.contains(status) &&
      detail is String &&
      detail.trim().isNotEmpty &&
      detail.length <= 2000) {
    return detail;
  }
  // The plan preview explains in Vietnamese why the answers do not make a
  // plan (the money does not cover the fixed costs and the saving).
  if (path == '/budget-plans/preview' &&
      status == 422 &&
      detail is String &&
      detail.trim().isNotEmpty &&
      detail.length <= 2000) {
    return detail;
  }
  return switch (status) {
    401 => 'Phiên đã hết hạn. Vui lòng đăng nhập lại.',
    403 => 'Bạn không có quyền thực hiện thao tác này.',
    404 => 'Dữ liệu không còn tồn tại. Vui lòng tải lại.',
    409 =>
      'Dữ liệu đang được sử dụng, bị trùng hoặc đã thay đổi. Vui lòng kiểm tra lại.',
    422 => 'Kiểm tra giá trị và dữ liệu liên quan trong biểu mẫu.',
    429 =>
      'Bạn đã gọi quá nhiều lần. Vui lòng chờ một lúc rồi thử lại.',
    503 => 'Máy chủ chưa sẵn sàng. Vui lòng thử lại sau.',
    _ => 'Không thể xử lý yêu cầu. Vui lòng thử lại.',
  };
}
