import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/finance/domain/entities/category.dart';
import '../models/transaction_draft.dart';
import '../services/receipt_input.dart';

abstract interface class AiInputRepository {
  Future<List<TransactionDraft>> analyze(String text);
  Future<List<TransactionDraft>> analyzeReceipt(ReceiptImage image);
}

class BackendAiInputRepository implements AiInputRepository {
  BackendAiInputRepository({BackendClient? client, this.categories})
    : client = client ?? BackendClient();

  final BackendClient client;
  final List<Category> Function()? categories;

  @override
  Future<List<TransactionDraft>> analyzeReceipt(ReceiptImage image) async {
    final response =
        await client.request(
              'POST',
              '/ingestion/receipt',
              bytes: image.bytes,
              contentType: image.mimeType,
            )
            as Map<String, dynamic>;
    return (response['drafts'] as List)
        .map((row) => TransactionDraft.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<TransactionDraft>> analyze(String text) async {
    final response =
        await client.request(
              'POST',
              '/ingestion/text',
              body: {
                'text': text,
                'categories': [
                  for (final category in (categories?.call() ?? <Category>[]))
                    {'name': category.name, 'is_income': category.isIncome},
                ],
              },
            )
            as Map<String, dynamic>;
    return (response['drafts'] as List)
        .map((row) => TransactionDraft.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
