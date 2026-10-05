String formatVnd(num amount) {
  final formatted = amount
      .abs()
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
  return '$formatted ₫';
}
