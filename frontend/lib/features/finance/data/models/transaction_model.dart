import '../../domain/entities/transaction.dart';

class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.userId,
    super.categoryId,
    super.accountId,
    super.toAccountId,
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
      accountId: json['account_id'] as int?,
      toAccountId: json['to_account_id'] as int?,
      amount: double.parse('${json['amount']}'),
      transactionType: json['transaction_type'] as String? ?? 'expense',
      rawDescription: json['raw_description'] as String?,
      cleanDescription: json['clean_description'] as String?,
      categoryPredicted: json['category_predicted'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 1,
      transactionDate: DateTime.parse('${json['transaction_date']}').toLocal(),
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      categoryName: category?['name'] as String?,
    );
  }
}
