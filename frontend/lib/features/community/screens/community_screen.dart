import 'package:flutter/material.dart';
import 'package:project_one/app/widgets/app_profile_button.dart';
import 'package:project_one/app/widgets/app_screen_navigation.dart';
import 'package:project_one/features/community/data/community_repository.dart';
import 'package:project_one/features/community/widgets/community_feed_view.dart';
import 'package:project_one/features/plan/data/budget_plan_repository.dart';
import 'package:project_one/features/profile/user_profile_notifier.dart';
import 'package:project_one/shared/widgets/kakeibo_logo.dart';

/// Community social feed screen shown on tab index 2 (`/community`).
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({
    super.key,
    this.communityRepository,
    this.planRepository,
    this.profileNotifier,
  });

  final CommunityRepository? communityRepository;
  final BudgetPlanRepository? planRepository;
  final UserProfileNotifier? profileNotifier;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: CommunityFeedView(
        communityRepository: communityRepository,
        planRepository: planRepository,
        profileNotifier: profileNotifier,
      ),
      bottomNavigationBar: const AppScreenNavigation(selectedIndex: 2),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const KakeiboLogo(size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kakeibo Zen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: scheme.primary,
                  ),
                ),
                Text(
                  'Cộng đồng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: const [AppProfileButton()],
    );
  }
}
