part of 'dashboard_screen.dart';

// These extensions split one State implementation without changing its private state.
// ignore_for_file: library_private_types_in_public_api

extension Settingstab on _DashboardScreenState {
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryMint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cloud_done,
                      color: AppTheme.primaryForestGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đồng bộ Supabase Cloud',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          SupabaseConfig.supabaseUrl,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.borderLight),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.currency_exchange,
                  color: AppTheme.primaryForestGreen,
                ),
                title: const Text('Đơn vị tiền tệ'),
                trailing: const Text(
                  'VND (₫)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.security,
                  color: AppTheme.primaryForestGreen,
                ),
                title: const Text('Bảo mật dữ liệu (PostgreSQL RLS)'),
                trailing: const Icon(
                  Icons.check_circle,
                  color: AppTheme.incomeEmerald,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
