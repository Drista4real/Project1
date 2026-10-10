import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';

class SettingsData {
  SettingsData({
    required FinanceRecord profile,
    required List<FinanceRecord> tags,
    required List<FinanceRecord> transactions,
    required List<FinanceRecord> transactionTags,
  }) : profile = Map.unmodifiable(profile),
       tags = List.unmodifiable(
         tags.map((r) => Map<String, dynamic>.unmodifiable(r)),
       ),
       transactions = List.unmodifiable(
         transactions.map((r) => Map<String, dynamic>.unmodifiable(r)),
       ),
       transactionTags = List.unmodifiable(
         transactionTags.map((r) => Map<String, dynamic>.unmodifiable(r)),
       );
  final FinanceRecord profile;
  final List<FinanceRecord> tags;
  final List<FinanceRecord> transactions;
  final List<FinanceRecord> transactionTags;
}

class SettingsState {
  SettingsState({
    this.data,
    this.loading = false,
    this.saving = false,
    this.error,
    this.query = '',
    this.range = 'Tháng này',
    this.customRange,
    Set<String> tags = const {},
  }) : tags = Set.unmodifiable(tags);
  final SettingsData? data;
  final bool loading;
  final bool saving;
  final String? error;
  final String query;
  final String range;
  final DateTimeRange? customRange;
  final Set<String> tags;

  SettingsState copyWith({
    SettingsData? data,
    bool clearData = false,
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
    String? query,
    String? range,
    DateTimeRange? customRange,
    Set<String>? tags,
  }) => SettingsState(
    data: clearData ? null : data ?? this.data,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
    query: query ?? this.query,
    range: range ?? this.range,
    customRange: customRange ?? this.customRange,
    tags: tags ?? this.tags,
  );

  List<FinanceRecord> filteredTransactions(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (range) {
      'Hôm nay' => today,
      'Tuần này' => DateTime(now.year, now.month, now.day - now.weekday + 1),
      'Tùy chọn' => customRange?.start ?? today,
      _ => DateTime(now.year, now.month),
    };
    final end = switch (range) {
      'Hôm nay' => DateTime(now.year, now.month, now.day + 1),
      'Tuần này' => DateTime(now.year, now.month, now.day - now.weekday + 8),
      'Tùy chọn' =>
        customRange == null
            ? DateTime(now.year, now.month, now.day + 1)
            : DateTime(
                customRange!.end.year,
                customRange!.end.month,
                customRange!.end.day + 1,
              ),
      _ => DateTime(now.year, now.month + 1),
    };
    final tagRecords = data?.tags ?? <FinanceRecord>[];
    final links = data?.transactionTags ?? <FinanceRecord>[];
    final tagIds = tagRecords
        .where((tag) => tags.contains(tag['name']))
        .map((tag) => tag['id'])
        .toSet();
    final taggedIds = links
        .where((item) => tagIds.contains(item['tag_id']))
        .map((item) => item['transaction_id'])
        .toSet();
    final search = query.trim().toLowerCase().replaceFirst('#', '');
    return (data?.transactions ?? <FinanceRecord>[]).where((item) {
      final date = financeDate(item['transaction_date']);
      if (date == null || date.isBefore(start) || !date.isBefore(end)) {
        return false;
      }
      if (tags.isNotEmpty && !taggedIds.contains(item['id'])) return false;
      final category = item['categories'];
      final relatedNames = links
          .where((link) => link['transaction_id'] == item['id'])
          .map(
            (link) => tagRecords
                .where((tag) => tag['id'] == link['tag_id'])
                .map((tag) => tag['name'])
                .join(' '),
          )
          .join(' ');
      final text =
          '${item['clean_description'] ?? ''} ${item['raw_description'] ?? ''} ${item['amount']} ${category is Map ? category['name'] : ''} $relatedNames'
              .toLowerCase();
      return search.isEmpty || text.contains(search);
    }).toList();
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this.repository) : super(SettingsState());
  final ManagementRepository repository;
  int _generation = 0;

  void search(String query) => emit(state.copyWith(query: query));
  void selectRange(String range, {DateTimeRange? customRange}) =>
      emit(state.copyWith(range: range, customRange: customRange));
  void selectTag(String tag, bool selected) => emit(
    state.copyWith(
      tags: selected ? {...state.tags, tag} : ({...state.tags}..remove(tag)),
    ),
  );

  Future<void> refresh() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final values = await Future.wait<Object>([
        repository.get('profile', 'me'),
        repository.references('tags'),
        repository.references('transactions'),
        repository.references('transaction_tags'),
      ]);
      if (isClosed || generation != _generation) return;
      final data = SettingsData(
        profile: values[0] as FinanceRecord,
        tags: values[1] as List<FinanceRecord>,
        transactions: values[2] as List<FinanceRecord>,
        transactionTags: values[3] as List<FinanceRecord>,
      );
      emit(
        state.copyWith(
          data: data,
          loading: false,
          tags: state.tags
              .where((name) => data.tags.any((tag) => tag['name'] == name))
              .toSet(),
        ),
      );
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(loading: false, error: '$error', clearData: true));
      }
    }
  }

  Future<void> savePreference(String field, dynamic value) async {
    if (isClosed || state.saving || state.data == null) return;
    emit(state.copyWith(saving: true));
    try {
      await repository.save('profile', {field: value}, key: 'me');
      if (!isClosed) await refresh();
    } finally {
      if (!isClosed) emit(state.copyWith(saving: false));
    }
  }
}
