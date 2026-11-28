import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/features/profile/user_profile_notifier.dart';
import 'package:project_one/shared/widgets/user_avatar.dart';

/// The top-right avatar every main screen shows; it is the way into settings.
class AppProfileButton extends StatelessWidget {
  const AppProfileButton({super.key, this.profileNotifier});

  final UserProfileNotifier? profileNotifier;

  void _open(BuildContext context) {
    // Already on settings: do not stack another copy.
    if (GoRouterState.of(context).matchedLocation == AppRoutes.settings) return;
    context.push(AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = profileNotifier ?? AppDependencies.userProfile;
    return Semantics(
      container: true,
      identifier: 'nav-settings',
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ListenableBuilder(
          listenable: notifier,
          builder: (context, _) {
            final profile = notifier.profile;
            return IconButton(
              tooltip: 'Cài đặt',
              onPressed: () => _open(context),
              icon: UserAvatar(
                radius: 16,
                avatarUrl: profile?.avatarUrl,
                displayName: profile?.fullName ?? profile?.email,
              ),
            );
          },
        ),
      ),
    );
  }
}
