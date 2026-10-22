import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/settings/cubit/settings_cubit.dart';

void main() {
  final now = DateTime(2026, 10, 22);
  final data = SettingsData(
    profile: {},
    tags: [
      {'id': 1, 'name': 'Du lịch'},
      {'id': 2, 'name': 'Gia đình'},
    ],
    transactions: [
      {
        'id': 10,
        'clean_description': 'Khách sạn',
        'transaction_date': '2026-10-10',
        'amount': '1200000',
      },
      {
        'id': 11,
        'clean_description': 'Vé máy bay',
        'transaction_date': '2026-10-11',
        'amount': '800000',
      },
      {
        'id': 12,
        'clean_description': 'Du lịch chưa gắn thẻ',
        'transaction_date': '2026-10-12',
        'amount': '50000',
      },
    ],
    transactionTags: [
      {'transaction_id': 10, 'tag_id': 1},
      {'transaction_id': 11, 'tag_id': 1},
      {'transaction_id': 11, 'tag_id': 2},
    ],
  );
  test('hashtags match attached tags without accents or spaces', () {
    for (final query in ['#dulich', '#Du lịch', '#du lich']) {
      expect(
        SettingsState(
          data: data,
          query: query,
        ).filteredTransactions(now).map((r) => r['id']),
        [10, 11],
      );
    }
  });
  test('tag search intersects selected chips and date range', () {
    expect(
      SettingsState(
        data: data,
        query: '#dulich',
        tags: {'Gia đình'},
      ).filteredTransactions(now).map((r) => r['id']),
      [11],
    );
    expect(
      SettingsState(
        data: data,
        query: '#dulich',
        range: 'Hôm nay',
      ).filteredTransactions(now),
      isEmpty,
    );
  });
  test('plain search still matches notes without accents', () {
    expect(
      SettingsState(
        data: data,
        query: 'khach san',
      ).filteredTransactions(now).map((r) => r['id']),
      [10],
    );
  });
}
