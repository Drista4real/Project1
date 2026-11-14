import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/ai/data/ai_input_repository.dart';
import 'package:project_one/features/ai/services/receipt_input.dart';
import 'package:project_one/features/finance/domain/entities/category.dart';

class CapturingApi extends BackendClient {
  Map<String, dynamic>? payload;
  List<int>? uploaded;
  String? mime;
  String? endpoint;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bytes,
    String contentType = 'application/json',
  }) async {
    expect(method, 'POST');
    endpoint = path;
    uploaded = bytes;
    mime = contentType;
    payload = body;
    return {
      'drafts': [
        {
          'text': 'Ăn trưa 65k',
          'normalized_text': 'Ăn trưa 65000',
          'amount': 65000,
          'transaction_type': 'expense',
          'category': 'Ăn uống gia đình',
          'confidence': 0.95,
          'source': 'GEMINI',
          'warnings': <String>[],
          'occurred_on': '2026-11-10',
        },
      ],
    };
  }
}

void main() {
  test('receipt sends raw image bytes and preserves its date', () async {
    final api = CapturingApi();
    final image = ReceiptImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/png',
    );
    final drafts = await BackendAiInputRepository(
      client: api,
    ).analyzeReceipt(image);
    expect(api.endpoint, '/ingestion/receipt');
    expect(api.uploaded, [1, 2, 3]);
    expect(api.mime, 'image/png');
    expect(api.payload, isNull);
    expect(drafts.single.occurredOn, DateTime(2026, 11, 10));
  });
  test(
    'analysis sends current category names and roles and reads drafts',
    () async {
      final api = CapturingApi();
      final repository = BackendAiInputRepository(
        client: api,
        categories: () => const [
          Category(id: 1, name: 'Ăn uống gia đình'),
          Category(id: 2, name: 'Lương', isIncome: true),
        ],
      );

      final drafts = await repository.analyze('Ăn trưa 65k');
      expect(api.endpoint, '/ingestion/text');

      expect(api.payload, {
        'text': 'Ăn trưa 65k',
        'categories': [
          {'name': 'Ăn uống gia đình', 'is_income': false},
          {'name': 'Lương', 'is_income': true},
        ],
      });
      expect(drafts.single.amount, 65000);
      expect(drafts.single.category, 'Ăn uống gia đình');
      expect(drafts.single.source, 'GEMINI');
    },
  );
}
