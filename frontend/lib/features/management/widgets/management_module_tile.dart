import 'package:flutter/material.dart';
import 'package:project_one/features/management/config/management_metadata.dart';

/// A task entry keeps the explanation next to its navigation action.
class ManagementModuleTile extends StatelessWidget {
  const ManagementModuleTile({
    super.key,
    required this.resource,
    required this.onTap,
  });
  final Map<String, dynamic> resource;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = resource['name'] as String;
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          managementModuleIcons[name] ?? Icons.folder_outlined,
          color: colors.primary,
          size: 22,
        ),
      ),
      title: Text(
        managementTitle(resource),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          managementDescriptions[name] ?? 'Xem và quản lý thông tin đã lưu',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
