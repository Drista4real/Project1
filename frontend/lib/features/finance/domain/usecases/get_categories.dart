import '../entities/category.dart';
import '../repositories/finance_repository.dart';

class GetCategories {
  final FinanceRepository repository;

  const GetCategories(this.repository);

  Future<List<Category>> call() => repository.getCategories();
}
