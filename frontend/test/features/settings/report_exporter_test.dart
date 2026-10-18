import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/settings/services/report_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final exporter = ReportExporter();
  final items =
      List.generate(
        15,
        (index) => <String, dynamic>{
          'transaction_date': '2026-10-18T10:00:00+07:00',
          'transaction_type': 'expense',
          'amount': '0.10',
          'clean_description': index == 0 ? '=SUM(A1:A2)' : 'Cà phê số $index',
          'categories': {'name': 'Ăn uống'},
          'accounts': {'name': 'Tiền mặt'},
        },
      )..addAll([
        {
          'transaction_date': '2026-10-18',
          'transaction_type': 'income',
          'amount': '5.35',
        },
        {
          'transaction_date': '2026-10-18',
          'transaction_type': 'transfer',
          'amount': '10000.00',
        },
      ]);
  test(
    'XLSX includes all rows, numeric amounts, exact totals and safe descriptions',
    () async {
      final bytes = await exporter.buildExcel(items, 'Tháng này · #dulich');
      final sheet = Excel.decodeBytes(bytes).tables['Thu chi']!;
      expect(sheet.maxRows, 24);
      expect(sheet.rows[4][2]!.value, TextCellValue('=SUM(A1:A2)'));
      expect(sheet.rows[18][2]!.value, TextCellValue('Cà phê số 14'));
      expect(sheet.rows[4][5]!.value, DoubleCellValue(0.1));
      expect(sheet.rows[21][1]!.value, DoubleCellValue(5.35));
      expect(sheet.rows[22][1]!.value, DoubleCellValue(1.5));
      expect(sheet.rows[23][1]!.value, DoubleCellValue(3.85));
      expect(sheet.rows[1][0]!.value, TextCellValue('Tháng này · #dulich'));
    },
  );
  test(
    'PDF supports Vietnamese text and reports spanning multiple pages',
    () async {
      final bytes = await exporter.buildPdf(
        List.generate(
          120,
          (i) => {
            ...items[i % items.length],
            'clean_description': 'Giao dịch tiếng Việt số $i',
          },
        ),
        'Tháng này',
      );
      final content = latin1.decode(bytes);
      expect(content, startsWith('%PDF-'));
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(content).length,
        greaterThan(1),
      );
      expect(content.trimRight(), endsWith('%%EOF'));
    },
  );
}
