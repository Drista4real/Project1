class TransactionModel {
  final int id;
  final String userId;
  final int? categoryId;
  final double amount;
  final String transactionType; // 'income' hoặc 'expense'
  final String? rawDescription;
  final String? cleanDescription;
  final String? categoryPredicted;
  final double confidenceScore;
  final DateTime transactionDate;
  final DateTime createdAt;
  final String? categoryName;

  TransactionModel({
    required this.id,
    required this.userId,
    this.categoryId,
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

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int,
      userId: json['user_id'] as String? ?? '',
      categoryId: json['category_id'] as int?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      transactionType: json['transaction_type'] as String? ?? 'expense',
      rawDescription: json['raw_description'] as String?,
      cleanDescription: json['clean_description'] as String?,
      categoryPredicted: json['category_predicted'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 1.0,
      transactionDate: json['transaction_date'] != null
          ? DateTime.parse(json['transaction_date'].toString())
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      categoryName: json['categories'] != null
          ? (json['categories'] as Map<String, dynamic>)['name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'category_id': categoryId,
      'amount': amount,
      'transaction_type': transactionType,
      'raw_description': rawDescription,
      'clean_description': cleanDescription,
      'category_predicted': categoryPredicted,
      'confidence_score': confidenceScore,
      'transaction_date': transactionDate.toIso8601String(),
    };
  }
}
