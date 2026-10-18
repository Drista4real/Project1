import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/features/management/config/management_metadata.dart';
import 'package:project_one/features/management/open_finance_module.dart';
import 'package:project_one/features/management/widgets/management_error_panel.dart';
import 'package:project_one/features/management/widgets/management_module_tile.dart';
import 'package:project_one/features/management/widgets/management_theme.dart';
import 'package:project_one/shared/state/async_data_cubit.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key, this.repository});
  final ManagementRepository? repository;
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  late final _repository =
      widget.repository ?? AppDependencies.managementRepository;
  late final _cubit = AsyncDataCubit<List<Map<String, dynamic>>>(
    _repository.resources,
  )..refresh();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _cubit.close();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> item) => managementSearchText(
    '${managementTitle(item)} ${managementDescriptions[item['name']] ?? ''}',
  ).contains(managementSearchText(_search.text));

  @override
  Widget build(BuildContext context) => ManagementTheme(
    builder: (context) => Scaffold(
      appBar: AppBar(title: const Text('Quản lý tài chính')),
      body:
          BlocBuilder<
            AsyncDataCubit<List<Map<String, dynamic>>>,
            AsyncDataState<List<Map<String, dynamic>>>
          >(
            bloc: _cubit,
            builder: (context, state) {
              if (state.status == DataStatus.failure) {
                return ManagementErrorPanel(
                  error: state.error!,
                  retry: _cubit.refresh,
                );
              }
              if (state.status != DataStatus.success) {
                return const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Đang tải các mục quản lý',
                  ),
                );
              }
              final resources = state.data!;
              final filtered = resources.where(_matches).toList();
              final editable = filtered
                  .where((r) => !generatedFinanceResources.contains(r['name']))
                  .toList();
              final history = filtered
                  .where((r) => generatedFinanceResources.contains(r['name']))
                  .toList();
              Widget tile(Map<String, dynamic> item) => ManagementModuleTile(
                resource: item,
                onTap: () => openFinanceModule(
                  context,
                  item['name'] as String,
                  repository: _repository,
                ),
              );
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      Text(
                        'Sắp xếp tài chính cá nhân',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chọn một mục để xem và sắp xếp thông tin. Bạn có thể bắt đầu từ ví đang sử dụng.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (resources.any((r) => r['name'] == 'accounts')) ...[
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: () => openFinanceModule(
                              context,
                              'accounts',
                              create: true,
                              repository: _repository,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm ví'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Tìm mục quản lý',
                          hintText: 'Ví, ngân sách, lịch thu chi…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Xóa tìm kiếm',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(_search.clear),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      if (filtered.isEmpty) ...[
                        const SizedBox(height: 32),
                        const Icon(Icons.search_off, size: 36),
                        const SizedBox(height: 12),
                        const Text(
                          'Không tìm thấy mục phù hợp.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () => setState(_search.clear),
                          child: const Text('Xem tất cả mục'),
                        ),
                      ],
                      for (final group in managementModuleGroups.entries)
                        if (editable.any(
                          (r) => group.value.contains(r['name']),
                        )) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 24, bottom: 8),
                            child: Text(
                              group.key,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Card(
                            margin: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (final name in group.value)
                                  for (final item in editable.where(
                                    (r) => r['name'] == name,
                                  ))
                                    tile(item),
                              ],
                            ),
                          ),
                        ],
                      for (final item in editable.where(
                        (r) => !managementModuleGroups.values.any(
                          (group) => group.contains(r['name']),
                        ),
                      ))
                        tile(item),
                      if (history.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Card(
                          margin: EdgeInsets.zero,
                          child: ExpansionTile(
                            key: ValueKey('history-${_search.text.isNotEmpty}'),
                            initiallyExpanded: _search.text.isNotEmpty,
                            leading: const Icon(Icons.history),
                            title: const Text('Lịch sử dự báo & tư vấn'),
                            subtitle: const Text('Dữ liệu đã lưu · Chỉ xem'),
                            children: history.map(tile).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
    ),
  );
}
