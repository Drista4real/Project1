class Category {
  final int id;
  final String? userId;
  final String name;
  final String? icon;
  final String color;
  final bool isIncome;

  const Category({
    required this.id,
    this.userId,
    required this.name,
    this.icon,
    this.color = '#3ECF8E',
    this.isIncome = false,
  });
}
