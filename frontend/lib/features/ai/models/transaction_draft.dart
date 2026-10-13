import 'package:project_one/features/finance/domain/entities/account.dart';
import 'package:project_one/features/finance/domain/entities/category.dart';

class TransactionDraft {
  const TransactionDraft({
    required this.text,
    required this.normalizedText,
    required this.amount,
    required this.type,
    required this.category,
    required this.confidence,
    required this.source,
    this.warnings = const [],
  });

  final String text, normalizedText, type, source;
  final String? category;
  final int? amount;
  final double confidence;
  final List<String> warnings;

  factory TransactionDraft.fromJson(Map<String, dynamic> json) =>
      TransactionDraft(
        text: json['text'] as String,
        normalizedText: json['normalized_text'] as String,
        amount: json['amount'] as int?,
        type: json['transaction_type'] as String,
        category: json['category'] as String?,
        confidence: (json['confidence'] as num).toDouble(),
        source: json['source'] as String,
        warnings: (json['warnings'] as List).cast<String>(),
      );
}

class ReviewTransaction {
  ReviewTransaction({
    required this.id,
    required this.draft,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    this.accountId,
    this.categoryId,
  });

  final int id;
  final TransactionDraft draft;
  final String description, type;
  final double? amount;
  final int? accountId, categoryId;
  final DateTime date;

  bool get canSave =>
      amount != null &&
      amount!.isFinite &&
      amount! > 0 &&
      amount! <= 9999999999999 &&
      accountId != null &&
      categoryId != null &&
      type != 'transfer';

  factory ReviewTransaction.fromDraft(
    int id,
    TransactionDraft draft,
    List<Account> accounts,
    List<Category> categories,
  ) {
    final matches = categories
        .where(
          (category) =>
              category.isIncome == (draft.type == 'income') &&
              (category.name.toLowerCase() == draft.category?.toLowerCase() ||
                  (draft.category != null &&
                      category.name.toLowerCase().startsWith(
                        '${draft.category!.toLowerCase()} ',
                      ))),
        )
        .toList();
    String walletKey(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'^(?:ví|tài khoản|ngân hàng)\s+'), '')
        .replaceAll(RegExp(r'\s+'), '');
    final inputKey = walletKey(draft.text);
    final wallets = accounts
        .where(
          (account) =>
              walletKey(account.name).isNotEmpty &&
              inputKey.contains(walletKey(account.name)),
        )
        .toList();
    final bankMention = RegExp(
      r'chuyển khoản|ngân hàng|thẻ',
    ).hasMatch(draft.text.toLowerCase());
    final namedPayment = RegExp(
      r'momo|mo mo|zalopay|zalo pay|tiền mặt|vietcombank|techcombank|mbbank|mb bank|bidv|vietinbank',
    ).hasMatch(draft.text.toLowerCase());
    final banks = accounts
        .where((account) => !account.name.toLowerCase().contains('tiền mặt'))
        .toList();
    final now = DateTime.now();
    var date = now;
    final time = RegExp(r'\b(\d{1,2})(?:h|:)(\d{2})\b').firstMatch(draft.text);
    if (time != null) {
      final hour = int.parse(time[1]!);
      final minute = int.parse(time[2]!);
      if (hour < 24 && minute < 60) {
        date = DateTime(now.year, now.month, now.day, hour, minute);
      }
    }
    return ReviewTransaction(
      id: id,
      draft: draft,
      description: draft.text,
      amount: draft.amount?.toDouble(),
      type: draft.type,
      date: date,
      accountId: wallets.length == 1
          ? wallets.single.id
          : namedPayment
          ? null
          : bankMention
          ? (banks.length == 1 ? banks.single.id : null)
          : (accounts.isEmpty ? null : accounts.first.id),
      categoryId: matches.length == 1 ? matches.single.id : null,
    );
  }

  ReviewTransaction edited({
    required String description,
    required double amount,
    required String type,
    required int accountId,
    required int? categoryId,
    required DateTime date,
  }) => ReviewTransaction(
    id: id,
    draft: draft,
    description: description,
    amount: amount,
    type: type,
    accountId: accountId,
    categoryId: categoryId,
    date: date,
  );
}
