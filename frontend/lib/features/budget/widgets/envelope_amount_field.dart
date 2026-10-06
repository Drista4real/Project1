import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import 'envelope_sheet_frame.dart';

int? envelopeAmount(String text) =>
    int.tryParse(text.replaceAll(RegExp(r'[.\s₫]'), ''));
String envelopeAmountText(num amount) => formatVnd(amount).replaceAll(' ₫', '');

class EnvelopeAmountField extends StatelessWidget {
  const EnvelopeAmountField({
    super.key,
    required this.controller,
    this.optional = false,
    this.enabled = true,
    this.fieldKey = 'envelope-limit',
    this.helperText,
  });
  final TextEditingController controller;
  final bool optional, enabled;
  final String fieldKey;
  final String? helperText;
  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey(fieldKey),
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(13),
      _VndInputFormatter(),
    ],
    decoration: envelopeInput('1.000.000').copyWith(
      suffixText: '₫',
      helperText:
          helperText ??
          (optional ? 'Để trống nếu chưa muốn đặt phong bao.' : null),
      helperMaxLines: 2,
    ),
    validator: (value) {
      if (optional && (value ?? '').trim().isEmpty) return null;
      final amount = envelopeAmount(value ?? '');
      return amount == null || amount <= 0 || amount > 9999999999999
          ? 'Nhập hạn mức lớn hơn 0, tối đa 13 chữ số.'
          : null;
    },
  );
}

class _VndInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final text = newValue.text.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    final before = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    var digits = 0, offset = 0;
    while (offset < text.length && digits < before) {
      if (text[offset] != '.') digits++;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
