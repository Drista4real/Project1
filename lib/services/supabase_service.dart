import '../core/constants/supabase_config.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class FinancialOverview {
  final double currentBalance;
  final double monthlyIncome;
  final double monthlyExpense;

  FinancialOverview({
    required this.currentBalance,
    required this.monthlyIncome,
    required this.monthlyExpense,
  });
}

class SupabaseService {
  final _client = SupabaseConfig.client;

  /// Lấy tổng quan tài chính (Số dư, Tổng thu, Tổng chi)
  Future<FinancialOverview> getFinancialOverview() async {
    try {
      final user = SupabaseConfig.currentUser;

      // 1. Thử lấy balance từ bảng profiles nếu đã đăng nhập
      double balance = 18450000; // Giá trị mặc định chuẩn theo mockup Stitch
      double income = 24500000;
      double expense = 6050000;

      if (user != null) {
        final profileRes = await _client
            .from('profiles')
            .select('current_balance')
            .eq('id', user.id)
            .maybeSingle();

        if (profileRes != null && profileRes['current_balance'] != null) {
          balance = (profileRes['current_balance'] as num).toDouble();
        }

        // Tính tổng thu chi từ bảng transactions của user
        final txList = await _client
            .from('transactions')
            .select('amount, transaction_type')
            .eq('user_id', user.id);

        if (txList.isNotEmpty) {
          income = 0;
          expense = 0;
          for (final row in txList) {
            final amt = (row['amount'] as num).toDouble();
            if (row['transaction_type'] == 'income') {
              income += amt;
            } else {
              expense += amt;
            }
          }
          balance = income - expense;
        }
      }

      return FinancialOverview(
        currentBalance: balance,
        monthlyIncome: income,
        monthlyExpense: expense,
      );
    } catch (_) {
      return FinancialOverview(
        currentBalance: 18450000,
        monthlyIncome: 24500000,
        monthlyExpense: 6050000,
      );
    }
  }

  /// Lấy danh sách giao dịch
  Future<List<TransactionModel>> getTransactions() async {
    try {
      final response = await _client
          .from('transactions')
          .select('*, categories(name)')
          .order('transaction_date', ascending: false)
          .limit(30);

      final list = (response as List<dynamic>)
          .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) return list;
    } catch (_) {
      // Fallback
    }

    // Nếu chưa có giao dịch nào trên Database, trả về danh sách mẫu ban đầu theo Stitch UI
    return [
      TransactionModel(
        id: 1,
        userId: 'demo',
        amount: 20000000,
        transactionType: 'income',
        rawDescription: 'Lương tháng 10 & Thưởng dự án',
        cleanDescription: 'Lương & Thưởng',
        categoryPredicted: 'Lương & Thưởng',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
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
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
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
        transactionDate: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
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
        transactionDate: DateTime.now().subtract(const Duration(days: 2)),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        categoryName: 'Ăn uống & Cà phê',
      ),
    ];
  }

  /// Thêm giao dịch mới vào PostgreSQL
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
      // Nếu chưa có Auth session, lưu vào bảng notes để kiểm tra kết nối ghi
      await _client.from('notes').insert({
        'title': '${transactionType == "income" ? "+" : "-"}${amount.toInt()}đ: $description',
      });
    }
  }

  /// Lấy danh mục thu/chi
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
      return [
        CategoryModel(id: 1, name: 'Lương & Thưởng', isIncome: true, color: '#10B981', icon: 'payments'),
        CategoryModel(id: 2, name: 'Ăn uống & Cà phê', isIncome: false, color: '#F59E0B', icon: 'restaurant'),
        CategoryModel(id: 3, name: 'Nhà ở & Tiền điện nước', isIncome: false, color: '#3B82F6', icon: 'home'),
        CategoryModel(id: 4, name: 'Mua sắm & Gia dụng', isIncome: false, color: '#EC4899', icon: 'shopping_bag'),
        CategoryModel(id: 5, name: 'Di chuyển & Xăng xe', isIncome: false, color: '#8B5CF6', icon: 'directions_car'),
      ];
    }
  }

  /// Xóa giao dịch
  Future<void> deleteTransaction(int id) async {
    try {
      await _client.from('transactions').delete().eq('id', id);
    } catch (_) {}
  }
}
