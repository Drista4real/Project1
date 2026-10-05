import 'package:flutter/material.dart';

import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/shared/widgets/finance_form.dart';
import 'package:project_one/features/management/config/management_metadata.dart';
import 'package:project_one/features/management/widgets/management_error_panel.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/features/management/open_finance_module.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key, this.repository});
  final ManagementRepository? repository;
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  late final _repository =
      widget.repository ?? AppDependencies.managementRepository;
  late Future<List<Map<String, dynamic>>> _resources = _repository.resources();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý tài chính')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _resources,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ManagementErrorPanel(
            error: snapshot.error!,
            retry: () => setState(() {
              _resources = _repository.resources();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Dữ liệu của bạn',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryForestGreen,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chọn nhóm dữ liệu bạn muốn quản lý.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            for (final group in managementModuleGroups.entries)
              if (snapshot.data!.any(
                (resource) => group.value.contains(resource['name']),
              ))
                FinanceFormSection(
                  title: group.key,
                  child: Column(
                    children: [
                      for (final resourceName in group.value)
                        for (final resource in snapshot.data!.where(
                          (r) => r['name'] == resourceName,
                        ))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              managementModuleIcons[resourceName],
                              color: AppTheme.primaryForestGreen,
                            ),
                            title: Text(resource['title'] as String),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => openFinanceModule(
                              context,
                              resourceName,
                              repository: _repository,
                            ),
                          ),
                    ],
                  ),
                ),
            for (final resource in snapshot.data!.where(
              (r) => !managementModuleGroups.values.any(
                (names) => names.contains(r['name']),
              ),
            ))
              Card(
                child: ListTile(
                  title: Text(resource['title'] as String),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openFinanceModule(
                    context,
                    resource['name'] as String,
                    repository: _repository,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
