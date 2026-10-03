class Transaction {
  final int id;
  final String userId;
  final int? categoryId;
  final int? accountId;
  final int? toAccountId;
  final double amount;
  final String transactionType;
  final String? rawDescription;
  final String? cleanDescription;
  final String? categoryPredicted;
  final double confidenceScore;
  final DateTime transactionDate;
  final DateTime createdAt;
  final String? categoryName;

  const Transaction({
    required this.id,
    required this.userId,
    this.categoryId,
    this.accountId,
    this.toAccountId,
    required this.amount,
    required this.transactionType,
    this.rawDescription,
    this.cleanDescription,
    this.categoryPredicted,
    this.confidenceScore = 1.0,
    required this.transactionDate,
    required this.createdAt,
    this.categoryName,
  });

  bool get isIncome => transactionType == 'income';
}
