import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_routes.dart';

/// The top-right avatar every main screen shows; it is the way into settings.
class AppProfileButton extends StatelessWidget {
  const AppProfileButton({super.key});

  void _open(BuildContext context) {
    // Already on settings: do not stack another copy.
    if (GoRouterState.of(context).matchedLocation == AppRoutes.settings) return;
    context.push(AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      identifier: 'nav-settings',
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
          tooltip: 'Cài đặt',
          onPressed: () => _open(context),
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: colors.primaryContainer,
            child: Icon(Icons.person, color: colors.primary, size: 19),
          ),
        ),
      ),
    );
  }
}
