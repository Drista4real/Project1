import 'package:project_one/features/finance/domain/entities/category.dart';

class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    super.userId,
    required super.name,
    super.icon,
    super.color,
    super.isIncome,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      userId: json['user_id'] as String?,
      name: json['name'] as String? ?? 'Chưa phân loại',
      icon: json['icon'] as String?,
      color: json['color'] as String? ?? '#3ECF8E',
      isIncome: json['is_income'] as bool? ?? false,
    );
  }
}
