import 'package:project_one/app/widgets/app_exit_button.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/core/config/supabase_config.dart';
import 'package:project_one/features/finance/domain/entities/account.dart';
import 'package:project_one/features/finance/domain/entities/category.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/features/transactions/screens/quick_add_transaction_screen.dart';
import '../data/ai_input_repository.dart';
import '../models/transaction_draft.dart';
import '../services/input_preferences.dart';
import '../services/voice_input.dart';
import '../services/voice_activity.dart';
import '../services/voice_input_factory.dart';
import '../services/receipt_input.dart';
import '../widgets/draft_edit_sheet.dart';
import '../widgets/input_budget_impact.dart';
import '../widgets/natural_input_card.dart';
import '../widgets/transaction_review_card.dart';

class AiQuickInputScreen extends StatefulWidget {
  const AiQuickInputScreen({
    super.key,
    this.inputRepository,
    this.financeRepository,
    this.insights,
    this.voiceInput,
    this.receiptInput,
    this.preferences,
    this.initialPrompt,
  });
  final AiInputRepository? inputRepository;
  final FinanceRepository? financeRepository;
  final FinanceInsights? insights;
  final VoiceInput? voiceInput;
  final ReceiptInput? receiptInput;
  final InputPreferences? preferences;

  /// A hint shown when the screen is opened from the conversational canvas.
  final String? initialPrompt;

  @override
  State<AiQuickInputScreen> createState() => _AiQuickInputScreenState();
}

class _AiQuickInputScreenState extends State<AiQuickInputScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _reviewAnchor = GlobalKey();
  late final _api =
      widget.inputRepository ??
      BackendAiInputRepository(categories: () => _categories);
  late final _finance =
      widget.financeRepository ?? AppDependencies.financeRepository;
  late final _insights = widget.insights ?? AppDependencies.financeInsights;
  late final _voice = widget.voiceInput ?? createVoiceInput();
  late final _receipt = widget.receiptInput ?? FileReceiptInput();
  late final _preferences =
      widget.preferences ??
      LocalInputPreferences(
        () => SupabaseConfig.client.auth.currentUser?.id ?? 'guest',
      );
  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<ReviewTransaction> _drafts = [];
  BudgetData? _budget;
  String? _error;
  bool _loading = true, _analyzing = false, _saving = false;
  bool _recording = false, _voiceBusy = false, _remember = true;
  bool _budgetFailed = false, _uncertainSave = false;
  int _generation = 0, _voiceGeneration = 0, _nextId = 0, _savedCount = 0;
  Timer? _recordingLimit;
  StreamSubscription<VoiceActivity>? _voiceActivity;
  double _voiceLevel = 0;
  bool _heardSpeech = false, _transcribing = false;
  bool _receiptBusy = false, _analyzingReceipt = false;
  bool _reviewOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text.addListener(_inputChanged);
    final prompt = widget.initialPrompt;
    if (prompt != null && prompt.isNotEmpty) _text.text = prompt;
    _loadReferences();
    _loadBudget();
    final voice = _voice;
    if (voice is VoiceActivityInput) {
      _voiceActivity = (voice as VoiceActivityInput).activity.listen((event) {
        if (!mounted || !_recording) return;
        setState(() {
          _voiceLevel = event.level;
          _heardSpeech = event.hasSpeech;
        });
        if (event.shouldFinish) unawaited(_finishVoice());
      });
    }
  }

  void _inputChanged() {
    if (_saving) return;
    ++_generation;
    setState(() {
      _drafts = [];
      _error = null;
    });
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _finance.getAccounts(),
        _finance.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _accounts = results[0] as List<Account>;
        _categories = results[1] as List<Category>;
        _loading = false;
        if (_accounts.isEmpty) {
          _error =
              'Chưa có số dư. Hãy đặt số dư ở Thiết lập kế hoạch tháng trên Trang chủ.';
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _loadBudget() async {
    try {
      final budget = await _insights.budgets();
      if (mounted) {
        setState(() {
          _budget = budget;
          _budgetFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _budgetFailed = true);
    }
  }

  Future<void> _analyze({ReceiptImage? receipt}) async {
    if (_analyzing ||
        _saving ||
        _loading ||
        _recording ||
        _voiceBusy ||
        _receiptBusy ||
        _uncertainSave) {
      return;
    }
    final text = _text.text.trim();
    if (text.isEmpty && receipt == null) {
      setState(() => _error = 'Hãy nhập hoặc nói nội dung giao dịch.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final generation = ++_generation;
    setState(() {
      _analyzing = true;
      _analyzingReceipt = receipt != null;
      _error = null;
      _drafts = [];
    });
    try {
      final drafts = receipt == null
          ? await _api.analyze(text)
          : await _api.analyzeReceipt(receipt);
      final reviewed = <ReviewTransaction>[];
      for (final draft in drafts) {
        var item = ReviewTransaction.fromDraft(
          ++_nextId,
          draft,
          _accounts,
          _categories,
        );
        try {
          final remembered = await _preferences.category(draft.normalizedText);
          final valid = _categories.where(
            (category) =>
                category.id == remembered &&
                category.isIncome == (item.type == 'income'),
          );
          if (valid.length == 1 &&
              item.amount != null &&
              item.accountId != null) {
            item = item.edited(
              description: item.description,
              amount: item.amount!,
              type: item.type,
              accountId: item.accountId!,
              categoryId: remembered,
              date: item.date,
            );
          }
        } catch (_) {
          // Local preferences must not prevent reviewing a transaction.
        }
        reviewed.add(item);
      }
      if (mounted && generation == _generation) {
        setState(() => _drafts = reviewed);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
    await _presentReview(generation);
  }

  Future<void> _presentReview(int generation) async {
    if (!mounted || generation != _generation || _drafts.isEmpty) return;
    // Wait for the new cards to be laid out before opening or scrolling.
    await WidgetsBinding.instance.endOfFrame;
    bool isCurrent() =>
        mounted &&
        generation == _generation &&
        _drafts.isNotEmpty &&
        ModalRoute.of(context)?.isCurrent == true;
    if (!isCurrent()) return;
    if (_drafts.length == 1) {
      await _edit(_drafts.single);
      if (!isCurrent()) return;
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!isCurrent()) return;
    final target = _reviewAnchor.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _toggleVoice() async {
    if (_saving || _analyzing || _voiceBusy || _receiptBusy || _uncertainSave) {
      return;
    }
    if (!_voice.supported) {
      setState(
        () => _error =
            'Ghi âm hiện chỉ dùng được trên Android. Bạn có thể gõ nội dung vào ô bên dưới.',
      );
      return;
    }
    if (_recording) {
      await _finishVoice();
      return;
    }
    final generation = ++_voiceGeneration;
    setState(() {
      _voiceBusy = true;
      _transcribing = false;
      _voiceLevel = 0;
      _heardSpeech = false;
      _error = null;
    });
    try {
      await _voice.start();
      if (!mounted || generation != _voiceGeneration) return;
      setState(() => _recording = true);
      _recordingLimit = Timer(const Duration(seconds: 20), _finishVoice);
    } catch (error) {
      if (mounted && generation == _voiceGeneration) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted && generation == _voiceGeneration) {
        setState(() => _voiceBusy = false);
      }
    }
  }

  Future<void> _finishVoice() async {
    if (!_recording || _voiceBusy) return;
    final generation = _voiceGeneration;
    var analyzeTranscript = false;
    _recordingLimit?.cancel();
    setState(() {
      _recording = false;
      _voiceBusy = true;
      _transcribing = true;
    });
    try {
      final transcript = await _voice.stop();
      if (!mounted || generation != _voiceGeneration) return;
      if (transcript.isNotEmpty) {
        _text.text = transcript.substring(0, transcript.length.clamp(0, 2000));
        analyzeTranscript = true;
      } else {
        setState(
          () =>
              _error = 'Chưa nhận được lời nói. Hãy kiểm tra micro và thử lại.',
        );
      }
    } catch (error) {
      if (mounted && generation == _voiceGeneration) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted && generation == _voiceGeneration) {
        setState(() => _voiceBusy = false);
      }
    }
    if (analyzeTranscript && mounted && generation == _voiceGeneration) {
      await _analyze();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android's permission dialog causes inactive, without leaving the app.
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) &&
        (_recording || _voiceBusy)) {
      ++_voiceGeneration;
      _recordingLimit?.cancel();
      unawaited(_voice.cancel().catchError((Object _) {}));
      if (mounted) {
        setState(() {
          _recording = false;
          _voiceBusy = false;
          _error =
              'Đã dừng ghi âm khi bạn rời ứng dụng. Nhấn Ghi âm để thử lại.';
        });
      }
    }
  }

  Future<void> _pickReceipt() async {
    if (_receiptBusy ||
        _loading ||
        _saving ||
        _analyzing ||
        _recording ||
        _voiceBusy ||
        _uncertainSave) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _receiptBusy = true;
      _error = null;
    });
    ReceiptImage? image;
    try {
      image = await _receipt.pick();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _receiptBusy = false);
    }
    if (mounted && image != null) await _analyze(receipt: image);
  }

  Future<void> _edit(ReviewTransaction item) async {
    if (_reviewOpen || _saving) return;
    _reviewOpen = true;
    try {
      if (item.type == 'transfer') {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Chuyển giữa các ví'),
            content: const Text(
              'Màn hình này ghi các khoản thu và chi. '
              'Chuyển tiền giữa các ví cần cả ví nguồn và ví nhận, nên khoản này chưa được lưu tại đây.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        );
        return;
      }
      final edited = await showModalBottomSheet<ReviewTransaction>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => Theme(
          data: _inputTheme(context),
          child: DraftEditSheet(
            item: item,
            accounts: _accounts,
            categories: _categories,
          ),
        ),
      );
      if (edited != null && mounted) {
        setState(() {
          _drafts = [
            for (final draft in _drafts)
              if (draft.id == edited.id) edited else draft,
          ];
        });
      }
    } finally {
      _reviewOpen = false;
    }
  }

  Future<void> _save() async {
    if (_saving ||
        _receiptBusy ||
        _recording ||
        _voiceBusy ||
        _analyzing ||
        _drafts.isEmpty ||
        _uncertainSave) {
      return;
    }
    if (_drafts.any((draft) => !draft.canSave)) {
      setState(
        () => _error =
            'Hãy bổ sung số tiền và danh mục cho từng giao dịch trước khi lưu.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final snapshot = List<ReviewTransaction>.of(_drafts);
    try {
      for (final draft in snapshot) {
        await _finance.addTransaction(
          amount: draft.amount!,
          transactionType: draft.type,
          description: draft.description,
          accountId: draft.accountId,
          categoryId: draft.categoryId,
          transactionDate: draft.date,
        );
        ++_savedCount;
        if (mounted) {
          setState(() => _drafts.removeWhere((item) => item.id == draft.id));
        }
        if (_remember && draft.categoryId != null) {
          try {
            await _preferences.remember(
              draft.draft.normalizedText,
              draft.categoryId!,
            );
          } catch (_) {
            // The transaction is already saved; preference failure is nonfatal.
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã lưu ${snapshot.length} giao dịch.')),
        );
        _close();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _uncertainSave = true;
          _error =
              'Đã xác nhận lưu $_savedCount giao dịch. Yêu cầu vừa gửi chưa xác nhận được kết quả. '
              'Hãy kiểm tra Sổ thu chi trước khi nhập lại để tránh lưu trùng.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(_savedCount > 0);
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _manual() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickAddTransactionScreen(
          repository: _finance,
          initialDescription: _text.text.trim(),
        ),
      ),
    );
    if (saved == true && mounted) {
      ++_savedCount;
      _close();
    }
  }

  String _categoryName(ReviewTransaction item) =>
      _categories
          .where((c) => c.id == item.categoryId)
          .map((c) => c.name)
          .firstOrNull ??
      (item.draft.category == null
          ? 'Chọn danh mục'
          : 'Gợi ý: ${item.draft.category}');
  String _accountName(ReviewTransaction item) =>
      _accounts
          .where((a) => a.id == item.accountId)
          .map((a) => a.name)
          .firstOrNull ??
      'Chọn ví';
  String _pillar(ReviewTransaction item) => item.type == 'income'
      ? 'Thu nhập'
      : pillarNames[_categories
                    .where((category) => category.id == item.categoryId)
                    .map((category) => category.pillar)
                    .firstOrNull ??
                _budget?.spending.categories[item.categoryId]?['pillar']] ??
            'Chọn phong bao';

  @override
  void dispose() {
    ++_generation;
    ++_voiceGeneration;
    WidgetsBinding.instance.removeObserver(this);
    _recordingLimit?.cancel();
    unawaited(_voiceActivity?.cancel());
    _text.removeListener(_inputChanged);
    _text.dispose();
    unawaited(_voice.dispose().catchError((Object _) {}));
    super.dispose();
  }

  ThemeData _inputTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'BeVietnamPro'),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamily: 'BeVietnamPro',
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'BeVietnamPro',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _inputTheme(context),
    child: Builder(builder: _buildContent),
  );

  void _showHelp() => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Cách nhập nhanh'),
      content: const Text(
        'Gõ một câu như “Ăn trưa 65k tiền mặt”. Với nhiều khoản, dùng dấu phẩy hoặc xuống dòng.\n\n'
        'Bạn cũng có thể ghi âm hoặc chọn ảnh hóa đơn. Ảnh cần rõ nét, định dạng JPEG, PNG hoặc WebP và không quá 8 MB.\n\n'
        'Kiểm tra lại số tiền, ngày và danh mục. Giao dịch chỉ được lưu khi bạn nhấn Lưu.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );

  Widget _buildContent(BuildContext context) => PopScope<bool>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_saving) _close();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: AppExitButton(
          close: true,
          enabled: !_saving,
          onPressed: _close,
        ),
        title: const Text(
          'Nhập nhanh AI',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Hướng dẫn',
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Gõ một câu, ghi âm hoặc chọn ảnh hóa đơn.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  NaturalInputCard(
                    controller: _text,
                    isAnalyzing: _analyzing,
                    onAnalyze: () => _analyze(),
                    onVoice: _toggleVoice,
                    onReceipt: _pickReceipt,
                    analyzingReceipt: _analyzingReceipt,
                    recording: _recording,
                    voiceBusy: _voiceBusy,
                    transcribing: _transcribing,
                    voiceLevel: _voiceLevel,
                    heardSpeech: _heardSpeech,
                    disabled:
                        _saving || _loading || _uncertainSave || _receiptBusy,
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          if (_accounts.isEmpty)
                            TextButton(
                              onPressed: _loading ? null : _loadReferences,
                              child: const Text('Thử tải lại'),
                            ),
                          if (_uncertainSave)
                            TextButton(
                              onPressed: _close,
                              child: const Text('Đóng để kiểm tra'),
                            ),
                        ],
                      ),
                    ),
                  if (_drafts.isEmpty && !_analyzing) ...[
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed:
                          _saving || _recording || _voiceBusy || _receiptBusy
                          ? null
                          : _manual,
                      child: const Text('Chuyển sang biểu mẫu'),
                    ),
                  ],
                  if (_drafts.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Row(
                      key: _reviewAnchor,
                      children: [
                        Expanded(
                          child: Text(
                            '${_drafts.length} giao dịch',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Chưa lưu',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kiểm tra số tiền và danh mục trước khi lưu.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final item in _drafts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TransactionReviewCard(
                          item: item,
                          accountName: _accountName(item),
                          categoryName: _categoryName(item),
                          pillar: _pillar(item),
                          enabled:
                              !_saving &&
                              !_uncertainSave &&
                              !_receiptBusy &&
                              !_recording &&
                              !_voiceBusy,
                          onEdit: () => _edit(item),
                          onDismissed: () => setState(
                            () => _drafts.removeWhere((d) => d.id == item.id),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    InputBudgetImpact(
                      drafts: _drafts,
                      data: _budget,
                      loadFailed: _budgetFailed,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _remember,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _remember = value ?? false),
                      title: const Text(
                        'Nhớ danh mục cho lần sau',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('confirmAiTransactions'),
                      onPressed:
                          _saving ||
                              _uncertainSave ||
                              _receiptBusy ||
                              _recording ||
                              _voiceBusy
                          ? null
                          : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        _saving
                            ? 'Đang lưu…'
                            : 'Lưu ${_drafts.length} giao dịch',
                      ),
                      style: FilledButton.styleFrom(
                        textStyle: const TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vuốt sang trái để bỏ một khoản.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
