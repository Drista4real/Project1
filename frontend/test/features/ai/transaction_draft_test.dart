import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/ai/models/transaction_draft.dart';
import 'package:project_one/features/finance/domain/entities/account.dart';
import 'package:project_one/features/finance/domain/entities/category.dart';

TransactionDraft draft({
  String text = 'bún bò 65k',
  String? category = 'Ăn uống',
}) => TransactionDraft(
  text: text,
  normalizedText: text,
  amount: 65000,
  type: 'expense',
  category: category,
  confidence: 0.9,
  source: 'LOCAL',
);

void main() {
  const cash = Account(id: 1, name: 'Tiền mặt');
  const bank = Account(id: 2, name: 'Vietcombank');
  test('spoken wallet matches a prefixed wallet name', () {
    final result = ReviewTransaction.fromDraft(1, draft(text: 'cơm 30k momo'), [
      cash,
      const Account(id: 4, name: 'Ví MoMo'),
    ], []);
    expect(result.accountId, 4);
  });
  test('missing named wallet never silently spends from cash', () {
    final result = ReviewTransaction.fromDraft(1, draft(text: 'cơm 30k momo'), [
      cash,
    ], []);
    expect(result.accountId, isNull);
  });
  test(
    'unique broader category maps to the actual user category and envelope',
    () {
      final result = ReviewTransaction.fromDraft(
        1,
        draft(),
        [cash],
        [const Category(id: 3, name: 'Ăn uống gia đình', pillar: 'needs')],
      );
      expect(result.categoryId, 3);
      expect(result.accountId, 1);
    },
  );
  test('ambiguous categories remain unselected', () {
    final result = ReviewTransaction.fromDraft(
      1,
      draft(),
      [cash],
      [
        const Category(id: 3, name: 'Ăn uống gia đình'),
        const Category(id: 4, name: 'Ăn uống công sở'),
      ],
    );
    expect(result.categoryId, isNull);
  });
  test('bank payment never defaults to cash when banks are ambiguous', () {
    final result = ReviewTransaction.fromDraft(
      1,
      draft(text: 'trà sữa 35k chuyển khoản'),
      [cash, bank, const Account(id: 5, name: 'MB')],
      [],
    );
    expect(result.accountId, isNull);
    expect(result.canSave, isFalse);
  });
  test('explicit wallet and valid transaction time are preserved', () {
    final result = ReviewTransaction.fromDraft(
      1,
      draft(text: 'trà sữa 35k Vietcombank lúc 12h30'),
      [cash, bank],
      [],
    );
    expect(result.accountId, 2);
    expect(result.date.hour, 12);
    expect(result.date.minute, 30);
  });
}
