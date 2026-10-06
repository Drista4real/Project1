import 'envelope_memory_repository.dart';

EnvelopeMemoryRepository fixture() {
  final repo = EnvelopeMemoryRepository();
  const names = [
    'Ăn uống gia đình',
    'Thuê nhà & dịch vụ',
    'Cà phê & gặp gỡ bạn bè',
    'Mua sắm & thời trang',
    'Sách & khóa học phát triển',
    'Xem phim & hòa nhạc nghệ thuật',
    'Y tế & thuốc men khẩn cấp',
    'Hiếu hỉ, sinh nhật, biếu tặng',
  ];
  const icons = [
    'restaurant',
    'home',
    'local_cafe',
    'shopping_bag',
    'menu_book',
    'school',
    'medical_services',
    'volunteer_activism',
  ];
  const pillars = ['needs', 'wants', 'culture', 'unexpected'];
  const limits = [
    4500000,
    6000000,
    1200000,
    1500000,
    800000,
    500000,
    1000000,
    1500000,
  ];
  for (var i = 0; i < 8; i++) {
    repo.tables['categories']!.add({
      'id': i + 1,
      'user_id': i == 0 ? null : 'owner',
      'name': names[i],
      'pillar': pillars[i ~/ 2],
      'is_income': false,
      'icon': icons[i],
    });
    repo.tables['budgets']!.add({
      'id': 10 + i,
      'user_id': 'owner',
      'category_id': i + 1,
      'pillar': null,
      'limit_amount': '${limits[i]}',
      'month_year': '2026-10-01',
    });
  }
  for (var i = 0; i < 4; i++) {
    repo.tables['budgets']!.add({
      'id': 30 + i,
      'category_id': null,
      'pillar': pillars[i],
      'limit_amount': '${[10000000, 5000000, 3000000, 2000000][i]}',
      'month_year': '2026-10-01',
    });
  }
  return repo;
}
