import 'package:flutter/material.dart';

import 'package:project_one/core/theme/app_theme.dart';

bool validateFinanceForm(GlobalKey<FormState> form) {
  final invalid = form.currentState!.validateGranularly();
  if (invalid.isEmpty) return true;
  final first = invalid.first;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (first.mounted) {
      Scrollable.ensureVisible(
        first.context,
        duration: const Duration(milliseconds: 250),
        alignment: 0.15,
      );
    }
  });
  return false;
}

InputDecoration financeInputDecoration(
  String label, {
  String? hint,
  String? helper,
  IconData? icon,
  Widget? suffix,
  String? suffixText,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  helperText: helper,
  helperMaxLines: 3,
  errorMaxLines: 3,
  prefixIcon: icon == null ? null : Icon(icon, size: 20),
  suffixIcon: suffix,
  suffixText: suffixText,
  filled: true,
  fillColor: AppTheme.bgCanvas,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppTheme.borderLight),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(
      color: AppTheme.primaryForestGreen,
      width: 1.5,
    ),
  ),
);

class FinanceFormSection extends StatelessWidget {
  const FinanceFormSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.borderLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class FinanceSaveBar extends StatelessWidget {
  const FinanceSaveBar({
    super.key,
    required this.onSave,
    this.busy = false,
    this.label = 'Lưu thay đổi',
  });

  final VoidCallback? onSave;
  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppTheme.borderLight)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: busy ? null : onSave,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(busy ? 'Đang lưu...' : label),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
