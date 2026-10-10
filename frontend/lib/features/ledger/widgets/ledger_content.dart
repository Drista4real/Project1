part of '../screens/ledger_screen.dart';

// These extensions split one State implementation without changing its private state.
// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

extension LedgerContent on _LedgerScreenState {
  Widget _buildLedgerContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryForestGreen),
      );
    }
    final today = DateTime.now();
    final todayExpense = _transactions
        .where(
          (tx) =>
              tx.transactionType == 'expense' &&
              tx.transactionDate.year == today.year &&
              tx.transactionDate.month == today.month &&
              tx.transactionDate.day == today.day,
        )
        .fold<double>(0, (sum, tx) => sum + tx.amount);

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppTheme.primaryForestGreen,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Sổ thu chi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryForestGreen,
                  ),
                ),
              ),
              SizedBox(width: 210, child: _buildLedgerModeToggle()),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadError != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_loadError!),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _signIn,
                          child: const Text('Đăng nhập'),
                        ),
                        TextButton(
                          onPressed: _loadAllData,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          _buildHeroBalanceCard(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final module in [
                (
                  'accounts',
                  Icons.account_balance_wallet_outlined,
                  'Ví / Tài khoản',
                ),
                ('categories', Icons.category_outlined, 'Danh mục'),
                (
                  'recurring_transactions',
                  Icons.event_repeat,
                  'Thu chi định kỳ',
                ),
                ('debts_loans', Icons.handshake_outlined, 'Sổ nợ'),
              ])
                OutlinedButton.icon(
                  onPressed: () => _manageFinance(module.$1),
                  icon: Icon(module.$2, size: 18),
                  label: Text(module.$3),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_showCalendar) _buildMonthCalendarCard(),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryForestGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Giao dịch Tháng ${_displayedMonth.month}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryForestGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Chi: -${_formatVND(todayExpense)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.expenseCoral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTransactionList(),
          const SizedBox(height: 8),
          _buildLedgerQuote(),
          const SizedBox(height: 72),
        ],
      ),
    );
  }

  Widget _buildLedgerModeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.lightMintBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildLedgerModeButton(
              label: 'Tháng này',
              icon: Icons.format_list_bulleted,
              selected: !_showCalendar,
              onTap: () => _cubit.showCalendar(false),
            ),
          ),
          Expanded(
            child: _buildLedgerModeButton(
              label: 'Lịch',
              icon: Icons.calendar_month,
              selected: _showCalendar,
              onTap: () => _cubit.showCalendar(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerModeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryForestGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBalanceCard() {
    final now = _displayedMonth;
    final monthly = _transactions.where(
      (tx) =>
          tx.transactionDate.year == now.year &&
          tx.transactionDate.month == now.month,
    );
    final income = monthly
        .where((tx) => tx.isIncome)
        .fold<double>(0, (sum, tx) => sum + tx.amount);
    final expense = monthly
        .where((tx) => tx.transactionType == 'expense')
        .fold<double>(0, (sum, tx) => sum + tx.amount);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryForestGreen.withAlpha(10),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month,
                size: 17,
                color: AppTheme.primaryForestGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tổng quan Tháng ${now.month}, ${now.year}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppTheme.borderLight),
          ),
          const Text(
            'CÒN DƯ KHẢ DỤNG',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_overview.currentBalance < 0 ? '-' : '+'}${_formatVND(_overview.currentBalance)}',
            key: const ValueKey('availableBalance'),
            style: const TextStyle(
              color: AppTheme.primaryForestGreen,
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSummaryPill(
                  label: 'Tổng thu',
                  amount: income,
                  icon: Icons.arrow_downward,
                  income: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryPill(
                  label: 'Tổng chi',
                  amount: expense,
                  icon: Icons.arrow_upward,
                  income: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill({
    required String label,
    required double amount,
    required IconData icon,
    required bool income,
  }) {
    final color = income ? AppTheme.incomeEmerald : AppTheme.expenseCoral;
    final surface = income ? const Color(0xFFEAF5EF) : const Color(0xFFFFF2EE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
                Text(
                  '${income ? '+' : '-'}${_formatVND(amount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendarCard() {
    final month = _displayedMonth;
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingDays = firstDay.weekday - 1;
    final totalCells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryForestGreen.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _cubit.moveMonth(-1),
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      size: 17,
                      color: AppTheme.primaryForestGreen,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Tháng ${month.month}, ${month.year}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryForestGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _cubit.moveMonth(1),
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const Divider(height: 10, color: AppTheme.borderLight),
          Row(
            children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: day == 'CN'
                              ? AppTheme.expenseCoral
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < totalCells ~/ 7; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: _buildCalendarDay(
                        row * 7 + column - leadingDays + 1,
                        daysInMonth,
                        month,
                        column == 6,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarDay(
    int day,
    int daysInMonth,
    DateTime now,
    bool sunday,
  ) {
    final inMonth = day >= 1 && day <= daysInMonth;
    final isToday =
        inMonth &&
        day == DateTime.now().day &&
        now.month == DateTime.now().month &&
        now.year == DateTime.now().year;
    final dayTransactions = inMonth
        ? _transactions.where(
            (tx) =>
                tx.transactionDate.year == now.year &&
                tx.transactionDate.month == now.month &&
                tx.transactionDate.day == day,
          )
        : const <Transaction>[];
    final dailyTotal = dayTransactions.fold<double>(
      0,
      (sum, tx) =>
          sum +
          (tx.transactionType == 'transfer'
              ? 0
              : tx.isIncome
              ? tx.amount
              : -tx.amount),
    );
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isToday ? AppTheme.primaryForestGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            inMonth ? '$day' : '',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              color: isToday
                  ? Colors.white
                  : (sunday ? AppTheme.expenseCoral : AppTheme.textCharcoal),
            ),
          ),
          if (dayTransactions.isNotEmpty)
            Text(
              '${dailyTotal < 0 ? '-' : '+'}${(dailyTotal.abs() / 1000).round()}k',
              style: TextStyle(
                fontSize: 7,
                color: isToday
                    ? Colors.white70
                    : (dailyTotal < 0
                          ? AppTheme.expenseCoral
                          : AppTheme.incomeEmerald),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLedgerQuote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightMintBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.spa_outlined,
            color: AppTheme.primaryForestGreen,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '“Mỗi ngày ghi chép là một bước hướng tới tự do và an tâm tài chính.”',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    final today = _displayedMonth;
    final todayTransactions = _transactions.where(
      (tx) =>
          tx.transactionDate.year == today.year &&
          tx.transactionDate.month == today.month,
    );
    if (todayTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Text('Tháng này chưa có giao dịch nào.'),
      );
    }

    return Column(
      children: todayTransactions.map((tx) {
        final isIncome = tx.isIncome;
        return GestureDetector(
          onTap: () => _openTransaction(tx),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isIncome
                        ? AppTheme.lightMintBg
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isIncome
                        ? Icons.payments_outlined
                        : Icons.restaurant_outlined,
                    color: isIncome
                        ? AppTheme.incomeEmerald
                        : AppTheme.expenseCoral,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.rawDescription ?? tx.cleanDescription ?? 'Giao dịch',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textCharcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${tx.categoryName ?? 'Chưa phân loại'} • ${tx.transactionDate.hour}:${tx.transactionDate.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${tx.transactionType == 'transfer'
                      ? '↔'
                      : isIncome
                      ? '+'
                      : '-'}${_formatVND(tx.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isIncome
                        ? AppTheme.incomeEmerald
                        : AppTheme.expenseCoral,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
