import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/supabase_config.dart';
import '../models/category_model.dart';
import '../models/financial_overview_model.dart';
import '../models/transaction_model.dart';

class FinanceRemoteDataSource {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<FinancialOverviewModel> getOverview() async {
    const fallback = FinancialOverviewModel(
      currentBalance: 18450000,
      monthlyIncome: 24500000,
      monthlyExpense: 6050000,
    );
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) {
        return fallback;
      }
      var balance = fallback.currentBalance;
      var income = fallback.monthlyIncome;
      var expense = fallback.monthlyExpense;
      final profile = await _client
          .from('profiles')
          .select('current_balance')
          .eq('id', user.id)
          .maybeSingle();
      if (profile?['current_balance'] != null) {
        balance = (profile!['current_balance'] as num).toDouble();
      }
      final rows = await _client
          .from('transactions')
          .select('amount, transaction_type')
          .eq('user_id', user.id);
      if (rows.isNotEmpty) {
        income = 0;
        expense = 0;
        for (final row in rows) {
          final amount = (row['amount'] as num).toDouble();
          if (row['transaction_type'] == 'income') {
            income += amount;
          } else {
            expense += amount;
          }
        }
        balance = income - expense;
      }
      return FinancialOverviewModel(
        currentBalance: balance,
        monthlyIncome: income,
        monthlyExpense: expense,
      );
    } catch (_) {
      return fallback;
    }
  }

  Future<List<TransactionModel>> getTransactions() async {
    try {
      final response = await _client
          .from('transactions')
          .select('*, categories(name)')
          .order('transaction_date', ascending: false)
          .limit(30);
      final transactions = (response as List<dynamic>)
          .map(
            (item) => TransactionModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      if (transactions.isNotEmpty) return transactions;
    } catch (_) {}
    final now = DateTime.now();
    return [
      TransactionModel(
        id: 1,
        userId: 'demo',
        amount: 20000000,
        transactionType: 'income',
        rawDescription: 'Lương tháng 10 & Thưởng dự án',
        cleanDescription: 'Lương & Thưởng',
        categoryPredicted: 'Lương & Thưởng',
        transactionDate: now,
        createdAt: now,
        categoryName: 'Lương & Thưởng',
      ),
      TransactionModel(
        id: 2,
        userId: 'demo',
        amount: 45000,
        transactionType: 'expense',
        rawDescription: 'The Coffee House - Cà phê sáng',
        cleanDescription: 'Cà phê sáng',
        categoryPredicted: 'Ăn uống & Cà phê',
        transactionDate: now,
        createdAt: now,
        categoryName: 'Ăn uống & Cà phê',
      ),
      TransactionModel(
        id: 3,
        userId: 'demo',
        amount: 4500000,
        transactionType: 'expense',
        rawDescription: 'Chuyển khoản tiền thuê nhà tháng 10',
        cleanDescription: 'Tiền thuê căn hộ',
        categoryPredicted: 'Nhà ở & Điện nước',
        transactionDate: now.subtract(const Duration(days: 1)),
        createdAt: now,
        categoryName: 'Nhà ở & Tiền điện nước',
      ),
      TransactionModel(
        id: 4,
        userId: 'demo',
        amount: 850000,
        transactionType: 'expense',
        rawDescription: 'Siêu thị WinMart rau củ thịt cá',
        cleanDescription: 'Đi chợ tuần',
        categoryPredicted: 'Ăn uống & Cà phê',
        transactionDate: now.subtract(const Duration(days: 2)),
        createdAt: now,
        categoryName: 'Ăn uống & Cà phê',
      ),
    ];
  }

  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _client
          .from('categories')
          .select()
          .order('id', ascending: true);
      return (response as List<dynamic>)
          .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [
        CategoryModel(
          id: 1,
          name: 'Lương & Thưởng',
          isIncome: true,
          color: '#10B981',
          icon: 'payments',
        ),
        CategoryModel(
          id: 2,
          name: 'Ăn uống & Cà phê',
          color: '#F59E0B',
          icon: 'restaurant',
        ),
        CategoryModel(
          id: 3,
          name: 'Nhà ở & Tiền điện nước',
          color: '#3B82F6',
          icon: 'home',
        ),
        CategoryModel(
          id: 4,
          name: 'Mua sắm & Gia dụng',
          color: '#EC4899',
          icon: 'shopping_bag',
        ),
        CategoryModel(
          id: 5,
          name: 'Di chuyển & Xăng xe',
          color: '#8B5CF6',
          icon: 'directions_car',
        ),
      ];
    }
  }

  Future<void> addTransaction({
    required double amount,
    required String transactionType,
    required String description,
    int? categoryId,
    String? categoryName,
  }) async {
    final user = SupabaseConfig.currentUser;
    if (user != null) {
      await _client.from('transactions').insert({
        'user_id': user.id,
        'amount': amount,
        'transaction_type': transactionType,
        'raw_description': description,
        'clean_description': description.trim(),
        'category_id': categoryId,
        'category_predicted': categoryName,
        'confidence_score': 0.95,
        'transaction_date': DateTime.now().toIso8601String(),
      });
    } else {
      await _client.from('notes').insert({
        'title':
            '${transactionType == "income" ? "+" : "-"}${amount.toInt()}đ: $description',
      });
    }
  }
}
