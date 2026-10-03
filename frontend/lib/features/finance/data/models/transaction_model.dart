import '../../domain/entities/transaction.dart';

class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.userId,
    super.categoryId,
    required super.amount,
    required super.transactionType,
    super.rawDescription,
    super.cleanDescription,
    super.categoryPredicted,
    super.confidenceScore,
    required super.transactionDate,
    required super.createdAt,
    super.categoryName,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final category = json['categories'] as Map<String, dynamic>?;
    return TransactionModel(
      id: json['id'] as int,
      userId: json['user_id'] as String? ?? '',
      categoryId: json['category_id'] as int?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      transactionType: json['transaction_type'] as String? ?? 'expense',
      rawDescription: json['raw_description'] as String?,
      cleanDescription: json['clean_description'] as String?,
      categoryPredicted: json['category_predicted'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 1,
      transactionDate:
          DateTime.tryParse('${json['transaction_date']}') ?? DateTime.now(),
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      categoryName: category?['name'] as String?,
    );
  }
}
