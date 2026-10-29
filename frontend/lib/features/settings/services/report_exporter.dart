import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';

enum ReportFormat { excel, pdf }

/// Produces actual XLSX/PDF files without sending financial data to a server.
class ReportExporter {
  static const headers = [
    'Ngày',
    'Loại',
    'Mô tả',
    'Danh mục',
    'Ví',
    'Số tiền (VND)',
  ];

  static int _cents(dynamic value) {
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch('$value');
    if (match == null) throw FormatException('Số tiền không hợp lệ: $value');
    final absolute =
        int.parse(match[2]!) * 100 +
        int.parse((match[3] ?? '').padRight(2, '0'));
    return match[1] == '-' ? -absolute : absolute;
  }

  static List<String> _row(FinanceRecord item) => [
    _date(item['transaction_date']),
    switch (item['transaction_type']) {
      'income' => 'Thu nhập',
      'expense' => 'Chi tiêu',
      'transfer' => 'Chuyển ví',
      _ => 'Khác',
    },
    '${item['clean_description'] ?? item['raw_description'] ?? ''}',
    item['categories'] is Map ? '${item['categories']['name'] ?? ''}' : '',
    item['accounts'] is Map ? '${item['accounts']['name'] ?? ''}' : '',
    (_cents(item['amount']) / 100).toStringAsFixed(2),
  ];

  static String _date(dynamic value) {
    final date = financeDate(value);
    return date == null
        ? ''
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static (int, int) _totals(List<FinanceRecord> items) {
    var income = 0, expense = 0;
    for (final item in items) {
      if (item['transaction_type'] == 'income') {
        income += _cents(item['amount']);
      }
      if (item['transaction_type'] == 'expense') {
        expense += _cents(item['amount']);
      }
    }
    return (income, expense);
  }

  Future<Uint8List> buildExcel(List<FinanceRecord> items, String filter) async {
    final book = Excel.createExcel();
    final sheet = book['Thu chi'];
    book.delete('Sheet1');
    sheet.appendRow([TextCellValue('Kakeibo Zen — Báo cáo thu chi')]);
    sheet.appendRow([TextCellValue(filter)]);
    sheet.appendRow([TextCellValue('${items.length} giao dịch · Đơn vị VND')]);
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final item in items) {
      final row = _row(item);
      sheet.appendRow([
        ...row.take(5).map(TextCellValue.new),
        DoubleCellValue(_cents(item['amount']) / 100),
      ]);
    }
    final (income, expense) = _totals(items);
    for (final total in [
      ('Tổng thu', income),
      ('Tổng chi', expense),
      ('Thu - chi', income - expense),
    ]) {
      sheet.appendRow([
        TextCellValue(total.$1),
        DoubleCellValue(total.$2 / 100),
      ]);
    }
    sheet.setColumnWidth(2, 50);
    for (var col = 0; col < headers.length; col++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3))
          .cellStyle = CellStyle(
        bold: true,
      );
    }
    return Uint8List.fromList(book.encode()!);
  }

  Future<Uint8List> buildPdf(List<FinanceRecord> items, String filter) async {
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/BeVietnamPro-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/BeVietnamPro-Bold.ttf'),
    );
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: bold),
    );
    final (income, expense) = _totals(items);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: 1000,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Kakeibo Zen · ${context.pageNumber}/${context.pagesCount}',
          ),
        ),
        build: (_) => [
          pw.Text(
            'Báo cáo thu chi',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(filter),
          pw.Text('${items.length} giao dịch · Đơn vị VND'),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: items.map(_row).toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            columnWidths: {2: const pw.FlexColumnWidth(3)},
          ),
          pw.SizedBox(height: 14),
          pw.Text('Tổng thu: ${(income / 100).toStringAsFixed(2)} VND'),
          pw.Text('Tổng chi: ${(expense / 100).toStringAsFixed(2)} VND'),
          pw.Text(
            'Thu - chi: ${((income - expense) / 100).toStringAsFixed(2)} VND',
          ),
        ],
      ),
    );
    return document.save();
  }

  /// Returns false when the native save/share sheet is dismissed.
  Future<bool> export(
    ReportFormat format,
    List<FinanceRecord> items,
    String filter, {
    Rect? origin,
  }) async {
    final bytes = format == ReportFormat.excel
        ? await buildExcel(items, filter)
        : await buildPdf(items, filter);
    final extension = format == ReportFormat.excel ? 'xlsx' : 'pdf';
    final mime = format == ReportFormat.excel
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : 'application/pdf';
    final filename =
        'kakeibo_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final file = XFile.fromData(bytes, name: filename, mimeType: mime);
    if (kIsWeb) {
      await file.saveTo(filename);
    } else if ({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }.contains(defaultTargetPlatform)) {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [filename],
          sharePositionOrigin: origin,
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    } else {
      final target = await getSaveLocation(
        suggestedName: filename,
        acceptedTypeGroups: [
          XTypeGroup(label: extension.toUpperCase(), extensions: [extension]),
        ],
      );
      if (target == null) return false;
      await file.saveTo(target.path);
    }
    return true;
  }
}
