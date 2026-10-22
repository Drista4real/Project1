/// The first view contains decisions needed for the task; defaults stay editable
/// under advanced options and are still included in the saved payload.
const managementPrimaryFields = <String, Set<String>>{
  'accounts': {'name', 'account_type', 'balance', 'record_initial_income'},
  'categories': {'name', 'is_income', 'pillar'},
  'tags': {'name'},
  'transaction_tags': {'transaction_id', 'tag_id'},
  'budgets': {'category_id', 'pillar', 'month_year', 'limit_amount'},
  'saving_goals': {'name', 'target_amount', 'current_amount', 'target_date'},
  'debts_loans': {'type', 'person_name', 'amount', 'paid_amount', 'due_date'},
  'recurring_transactions': {
    'description',
    'amount',
    'transaction_type',
    'account_id',
    'category_id',
    'frequency',
    'start_date',
    'next_execution_date',
  },
  'profile': {'full_name', 'payroll_day', 'monthly_savings_target'},
};

String? managementFieldHint(String resource, String field) => switch ((
  resource,
  field,
)) {
  ('accounts', 'name') => 'Ví tiền mặt, tài khoản ngân hàng…',
  ('tags', 'name') => 'Du lịch hè, gia đình, công việc…',
  ('saving_goals', 'name') => 'Quỹ dự phòng, chuyến đi, mua xe…',
  ('debts_loans', 'person_name') => 'Tên người hoặc tổ chức',
  ('recurring_transactions', 'description') => 'Tiền nhà, lương hằng tháng…',
  (_, 'payroll_day') => 'Ngày trong tháng, từ 1 đến 31',
  _ => null,
};
