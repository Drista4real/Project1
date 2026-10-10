import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/budget/models/category_envelope_data.dart';
import 'package:project_one/features/budget/models/envelope_pillar.dart';
import 'package:project_one/features/budget/services/category_envelopes_service.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart'
    show FinanceRecord;

class EnvelopeFormState {
  const EnvelopeFormState({this.busy = false, this.saved = false, this.error});
  final bool busy;
  final bool saved;
  final String? error;
}

class EnvelopeFormCubit extends Cubit<EnvelopeFormState> {
  EnvelopeFormCubit(this.service, this.data) : super(const EnvelopeFormState());
  final CategoryEnvelopesService service;
  final CategoryEnvelopeData data;

  Future<void> saveCategory({
    FinanceRecord? category,
    required String name,
    required EnvelopePillar pillar,
    required String? limit,
  }) => _save(() async {
    final fresh = await service.load(data.month);
    await service.saveCategory(
      data: fresh,
      category: category,
      name: name,
      pillar: pillar,
      limit: limit,
    );
  }, 'Không thể lưu.');

  Future<void> rebalance(int total, List<int> percentages) async {
    if (state.busy || isClosed) return;
    if (percentages.fold(0, (a, b) => a + b) != 100) {
      emit(const EnvelopeFormState(error: 'Tổng phân bổ phải bằng 100%.'));
      return;
    }
    await _save(() async {
      final fresh = await service.load(data.month);
      await service.rebalance(fresh, total, percentages);
    }, 'Chưa lưu xong phân bổ. Vui lòng thử lại.');
  }

  Future<void> _save(Future<void> Function() save, String message) async {
    if (isClosed || state.busy) return;
    emit(const EnvelopeFormState(busy: true));
    try {
      await save();
      if (!isClosed) emit(const EnvelopeFormState(saved: true));
    } catch (error) {
      if (!isClosed) emit(EnvelopeFormState(error: '$message $error'));
    }
  }
}
