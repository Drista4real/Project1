import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/features/profile/user_profile_notifier.dart';
import 'package:project_one/features/profile/screens/edit_profile_screen.dart';
import 'package:project_one/features/profile/widgets/edit_profile_sheet.dart';
import 'package:project_one/shared/widgets/user_avatar.dart';

class _FakeManagementRepository implements ManagementRepository {
  Map<String, dynamic> profileRecord = {
    'full_name': 'Minh Anh',
    'email': 'minhanh@example.com',
    'avatar_url': null,
  };
  Map<String, dynamic>? lastSavedPatch;

  @override
  Future<Map<String, dynamic>> get(String resource, String key) async {
    return Map<String, dynamic>.from(profileRecord);
  }

  @override
  Future<void> save(
    String resource,
    Map<String, dynamic> values, {
    String? key,
  }) async {
    lastSavedPatch = Map<String, dynamic>.from(values);
    profileRecord = {...profileRecord, ...values};
  }

  @override
  Future<Map<String, dynamic>> create(
    String resource,
    Map<String, dynamic> values,
  ) => throw UnimplementedError();

  @override
  Future<void> delete(String resource, String key) =>
      throw UnimplementedError();

  @override
  String key(String resource, Map<String, dynamic> record) => 'me';

  @override
  Future<Map<String, dynamic>> page(String resource, {int offset = 0}) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> references(String resource) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> resources() => throw UnimplementedError();
}

void main() {
  group('UserProfileNotifier', () {
    test('loads profile and computes displayName and initials', () async {
      final repo = _FakeManagementRepository();
      final notifier = UserProfileNotifier(repo);

      await notifier.syncForUser('user-1');

      expect(notifier.loaded, isTrue);
      expect(notifier.displayName, 'Minh Anh');
      expect(avatarInitials(notifier.displayName), 'MA');
    });

    test('updates profile and notifies listeners', () async {
      final repo = _FakeManagementRepository();
      final notifier = UserProfileNotifier(repo);
      await notifier.syncForUser('user-1');

      var notified = 0;
      notifier.addListener(() => notified++);

      await notifier.updateProfile(
        fullName: 'Đạt Nguyễn',
        avatarUrl: 'preset:leaf',
      );

      expect(repo.lastSavedPatch, {
        'full_name': 'Đạt Nguyễn',
        'avatar_url': 'preset:leaf',
      });
      expect(notifier.displayName, 'Đạt Nguyễn');
      expect(notifier.avatarUrl, 'preset:leaf');
      expect(notified, 1);
    });
  });

  group('UserAvatar & EditProfileSheet', () {
    testWidgets('renders initials fallback and preset icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                UserAvatar(displayName: 'Minh Anh'),
                UserAvatar(avatarUrl: 'preset:leaf'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('MA'), findsOneWidget);
      expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
    });

    testWidgets('edits display name and selects preset avatar', (tester) async {
      final repo = _FakeManagementRepository();
      final notifier = UserProfileNotifier(repo);
      await notifier.syncForUser('user-1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showEditProfileSheet(context, notifier: notifier),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('profile-name-field')),
        'Lan Phương',
      );
      await tester.tap(find.text('Ví tiền'));
      await tester.pump();

      final saveButton = find.byKey(const ValueKey('profile-save-button'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(notifier.displayName, 'Lan Phương');
      expect(notifier.avatarUrl, 'preset:wallet');
    });

    testWidgets('EditProfileScreen saves name, preset avatar, payroll and savings', (
      tester,
    ) async {
      final repo = _FakeManagementRepository()
        ..profileRecord = {
          'full_name': 'daotiendat',
          'email': 'dat@example.com',
          'avatar_url': 'preset:star',
          'payroll_day': 5,
          'monthly_savings_target': 0,
          'currency': 'VND',
        };
      final notifier = UserProfileNotifier(repo);

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            repository: repo,
            initialProfile: repo.profileRecord,
            profileNotifier: notifier,
          ),
        ),
      );

      final nameField = find.byKey(const ValueKey('profile-name-field'));
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Đạt Đào');

      final leafChip = find.text('Lá xanh');
      await tester.ensureVisible(leafChip);
      await tester.tap(leafChip);
      await tester.pump();

      final payrollField = find.byKey(const ValueKey('profile-payroll-field'));
      await tester.ensureVisible(payrollField);
      await tester.enterText(payrollField, '10');

      final savingsField = find.byKey(const ValueKey('profile-savings-field'));
      await tester.ensureVisible(savingsField);
      await tester.enterText(savingsField, '500000');

      await tester.tap(find.byKey(const ValueKey('profile-save-button')));
      await tester.pumpAndSettle();

      expect(repo.lastSavedPatch, {
        'full_name': 'Đạt Đào',
        'avatar_url': 'preset:leaf',
        'payroll_day': 10,
        'monthly_savings_target': 500000,
        'currency': 'VND',
      });
      expect(notifier.displayName, 'Đạt Đào');
      expect(notifier.avatarUrl, 'preset:leaf');
    });
  });
}
