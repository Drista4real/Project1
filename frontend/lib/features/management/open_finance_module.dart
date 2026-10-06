import 'package:flutter/material.dart';

import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/features/management/screens/record_form_screen.dart';
import 'package:project_one/features/management/screens/resource_list_screen.dart';
import 'package:project_one/features/budget/screens/category_envelopes_screen.dart';

/// Reuse the authenticated CRUD forms from the existing feature screens.
Future<void> openFinanceModule(
  BuildContext context,
  String name, {
  bool create = false,
  Map<String, dynamic>? record,
  Map<String, dynamic> defaults = const {},
  ManagementRepository? repository,
}) async {
  final source = repository ?? AppDependencies.managementRepository;
  if ((name == 'categories' || name == 'budgets') &&
      !create &&
      record == null) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryEnvelopesScreen(
          repository: source,
          month: DateTime.tryParse('${defaults['month_year']}'),
        ),
      ),
    );
    return;
  }
  try {
    final resources = await source.resources();
    final resource = resources.firstWhere((item) => item['name'] == name);
    Map<String, dynamic>? fresh;
    if (record != null || name == 'profile') {
      fresh = await source.get(
        name,
        name == 'profile' ? 'me' : source.key(name, record!),
      );
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => create || fresh != null
            ? RecordFormScreen(
                resource: resource,
                repository: source,
                record: fresh,
                initialValues: defaults,
              )
            : ResourceListScreen(resource: resource, repository: source),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}
