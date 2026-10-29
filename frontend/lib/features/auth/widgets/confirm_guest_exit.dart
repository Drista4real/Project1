import 'package:flutter/material.dart';

Future<bool> confirmGuestExit(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời chế độ khách?'),
        content: const Text(
          'Bạn chưa liên kết email nên không thể khôi phục quyền truy cập dữ liệu '
          'khách sau khi đăng xuất. Hãy ở lại và liên kết email để giữ sổ tài chính.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rời chế độ khách'),
          ),
        ],
      ),
    ) ??
    false;
