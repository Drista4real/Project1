class CategoryModel {
  final int id;
  final String? userId;
  final String name;
  final String? icon;
  final String color;
  final bool isIncome;

  CategoryModel({
    required this.id,
    this.userId,
    required this.name,
    this.icon,
    this.color = '#3ECF8E',
    this.isIncome = false,
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

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon': icon,
      'color': color,
      'is_income': isIncome,
      if (userId != null) 'user_id': userId,
    };
  }
}
