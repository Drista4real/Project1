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
  return switch (status) {
    401 => 'Phiên đã hết hạn. Vui lòng đăng nhập lại.',
    403 => 'Bạn không có quyền thực hiện thao tác này.',
    404 => 'Dữ liệu không còn tồn tại. Vui lòng tải lại.',
    409 =>
      'Dữ liệu đang được sử dụng, bị trùng hoặc đã thay đổi. Vui lòng kiểm tra lại.',
    422 => 'Kiểm tra giá trị và dữ liệu liên quan trong biểu mẫu.',
    503 => 'Máy chủ chưa sẵn sàng. Vui lòng thử lại sau.',
    _ => 'Không thể xử lý yêu cầu. Vui lòng thử lại.',
  };
}
