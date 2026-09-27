import '../../features/finance/data/datasources/finance_remote_data_source.dart';
import '../../features/finance/data/repositories/supabase_finance_repository.dart';
import '../../features/finance/domain/repositories/finance_repository.dart';
import '../../features/finance/domain/usecases/add_transaction.dart';
import '../../features/finance/domain/usecases/get_categories.dart';
import '../../features/finance/domain/usecases/get_financial_overview.dart';
import '../../features/finance/domain/usecases/get_transactions.dart';

class AppDependencies {
  static final FinanceRepository financeRepository = SupabaseFinanceRepository(
    FinanceRemoteDataSource(),
  );
  static final getOverview = GetFinancialOverview(financeRepository);
  static final getTransactions = GetTransactions(financeRepository);
  static final getCategories = GetCategories(financeRepository);
  static final addTransaction = AddTransaction(financeRepository);
}
