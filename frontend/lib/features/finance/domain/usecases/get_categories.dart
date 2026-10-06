import 'package:project_one/features/finance/domain/entities/category.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';

class GetCategories {
  final FinanceRepository repository;

  const GetCategories(this.repository);

  Future<List<Category>> call() => repository.getCategories();
}
