import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/app/widgets/app_screen_navigation.dart';
import 'package:project_one/core/config/supabase_config.dart';
import 'package:project_one/core/theme/app_theme.dart';
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
    this.preferences,
  });
  final AiInputRepository? inputRepository;
  final FinanceRepository? financeRepository;
  final FinanceInsights? insights;
  final VoiceInput? voiceInput;
  final InputPreferences? preferences;

  @override
  State<AiQuickInputScreen> createState() => _AiQuickInputScreenState();
}

class _AiQuickInputScreenState extends State<AiQuickInputScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  late final _api =
      widget.inputRepository ??
      BackendAiInputRepository(categories: () => _categories);
  late final _finance =
      widget.financeRepository ?? AppDependencies.financeRepository;
  late final _insights = widget.insights ?? AppDependencies.financeInsights;
  late final _voice = widget.voiceInput ?? createVoiceInput();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text.addListener(_inputChanged);
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
          _error = 'Bạn cần tạo ví trước khi lưu giao dịch.';
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

  Future<void> _analyze() async {
    if (_analyzing ||
        _saving ||
        _loading ||
        _recording ||
        _voiceBusy ||
        _uncertainSave) {
      return;
    }
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Hãy nhập hoặc nói nội dung giao dịch.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final generation = ++_generation;
    setState(() {
      _analyzing = true;
      _error = null;
      _drafts = [];
    });
    try {
      final drafts = await _api.analyze(text);
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
  }

  Future<void> _toggleVoice() async {
    if (_saving || _analyzing || _voiceBusy || _uncertainSave) return;
    if (!_voice.supported) {
      setState(
        () => _error =
            'Nhập giọng nói offline hỗ trợ Android. Bạn có thể nhập văn bản ở đây.',
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
              'Đã dừng ghi âm khi rời ứng dụng. Nhấn Nói nhanh để thử lại.';
        });
      }
    }
  }

  Future<void> _edit(ReviewTransaction item) async {
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
      builder: (_) => DraftEditSheet(
        item: item,
        accounts: _accounts,
        categories: _categories,
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
  }

  Future<void> _save() async {
    if (_saving || _drafts.isEmpty || _uncertainSave) return;
    if (_drafts.any((draft) => !draft.canSave)) {
      setState(
        () => _error =
            'Hãy bổ sung số tiền, ví và danh mục cho từng giao dịch trước khi lưu.',
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
              'Hãy kiểm tra Sổ Thu Chi trước khi nhập lại để tránh lưu trùng.';
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
      context.go(AppRoutes.ledger);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'BeVietnamPro'),
        primaryTextTheme: theme.primaryTextTheme.apply(
          fontFamily: 'BeVietnamPro',
        ),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
            fontFamily: 'BeVietnamPro',
          ),
        ),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) => PopScope<bool>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_saving) _close();
    },
    child: Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(
              Icons.spa_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 29,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kakeibo Zen',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Sổ Thu Chi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: CircleAvatar(
              backgroundColor: Color(0xFFE7EDE7),
              child: Icon(Icons.person_outline),
            ),
          ),
        ],
      ),
      bottomNavigationBar: IgnorePointer(
        ignoring: _saving,
        child: const AppScreenNavigation(selectedIndex: 0),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: _saving ? null : _close,
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Nhập Nhanh AI',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tự động nhận diện & gán phong bao',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hướng dẫn',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Nhập thu chi bằng lời nói'),
                        content: const Text(
                          'Nhập hoặc nói một khoản thu chi, ví dụ: “ăn trưa 65k tiền mặt”. '
                          'Dùng dấu phẩy hoặc xuống dòng để tách nhiều khoản. '
                          'Kiểm tra số tiền, ngày, ví và danh mục trước khi xác nhận. Giọng nói chạy offline trên Android.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Đã hiểu'),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.help_outline),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              NaturalInputCard(
                controller: _text,
                isAnalyzing: _analyzing,
                onAnalyze: _analyze,
                onVoice: _toggleVoice,
                recording: _recording,
                voiceBusy: _voiceBusy,
                transcribing: _transcribing,
                voiceLevel: _voiceLevel,
                heardSpeech: _heardSpeech,
                disabled: _saving || _loading || _uncertainSave,
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppTheme.expenseCoral,
                          height: 1.5,
                        ),
                      ),
                      if (_accounts.isEmpty)
                        TextButton(
                          onPressed: _loading ? null : _loadReferences,
                          child: const Text('Tải lại ví và danh mục'),
                        ),
                      if (_uncertainSave)
                        TextButton(
                          onPressed: _close,
                          child: const Text('Về Sổ Thu Chi'),
                        ),
                    ],
                  ),
                ),
              if (_drafts.isEmpty && !_analyzing) ...[
                const SizedBox(height: 20),
                Text(
                  'Nhập câu tự nhiên, sau đó nhấn Phân tích để kiểm tra từng giao dịch.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                TextButton(
                  onPressed: _saving || _recording || _voiceBusy
                      ? null
                      : _manual,
                  child: const Text('Nhập thủ công'),
                ),
              ],
              if (_drafts.isNotEmpty) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    Icon(
                      Icons.chevron_left,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đã tách ${_drafts.length} giao dịch',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_drafts.every(
                      (item) =>
                          item.draft.confidence > 0 &&
                          item.draft.source != 'RULES',
                    ))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(_drafts.map((item) => item.draft.confidence).reduce((a, b) => a < b ? a : b) * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final item in _drafts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TransactionReviewCard(
                      item: item,
                      accountName: _accountName(item),
                      categoryName: _categoryName(item),
                      pillar: _pillar(item),
                      enabled: !_saving && !_uncertainSave,
                      onEdit: () => _edit(item),
                      onDismissed: () => setState(
                        () => _drafts.removeWhere((d) => d.id == item.id),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                InputBudgetImpact(
                  drafts: _drafts,
                  data: _budget,
                  loadFailed: _budgetFailed,
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _remember,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _remember = value ?? false),
                  title: const Text(
                    'Ghi nhớ danh mục cho các lần nhập tương tự',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const ValueKey('confirmAiTransactions'),
                  onPressed: _saving || _uncertainSave ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _saving ? 'Đang lưu…' : 'Xác nhận & Lưu vào Sổ Thu Chi',
                  ),
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Mẹo: Vuốt sang trái để bỏ một giao dịch trước khi lưu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
