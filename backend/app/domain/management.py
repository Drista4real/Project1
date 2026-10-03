"""Allowlisted contracts for the financial management modules."""

from datetime import date, time
from decimal import Decimal
from typing import Annotated, Literal, Protocol

from pydantic import BaseModel, ConfigDict, Field, model_validator

Money = Annotated[Decimal, Field(max_digits=15, decimal_places=2)]
PositiveMoney = Annotated[Money, Field(gt=0)]
NonnegativeMoney = Annotated[Money, Field(ge=0)]
Identifier = Annotated[int, Field(gt=0, le=9223372036854775807)]
Text = Annotated[str, Field(min_length=1, max_length=500)]
Color = Annotated[str, Field(pattern=r"^#[0-9a-fA-F]{6}$")]
Pillar = Literal["needs", "wants", "culture", "unexpected", "income"]
ExpensePillar = Literal["needs", "wants", "culture", "unexpected"]
Day = Annotated[int, Field(ge=1, le=31)]


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class AccountInput(Input):
    name: Text
    account_type: Literal[
        "cash", "bank", "e_wallet", "credit_card", "investment", "savings"
    ]
    balance: Money = Decimal(0)
    currency: Annotated[str, Field(pattern=r"^[A-Z]{3}$")] = "VND"
    icon: Text = "account_balance_wallet"
    color: Color = "#10B981"
    account_number: Text | None = None
    institution_name: Text | None = None
    credit_limit: NonnegativeMoney = Decimal(0)
    statement_day: Day | None = None
    payment_due_day: Day | None = None
    is_included_in_total: bool = True
    is_archived: bool = False


class CategoryInput(Input):
    name: Text
    parent_id: Identifier | None = None
    icon: Text = "category"
    color: Color = "#3ECF8E"
    is_income: bool = False
    pillar: Pillar | None = None
    display_order: Annotated[int, Field(ge=0)] = 0

    @model_validator(mode="after")
    def matching_pillar(self):
        if self.pillar and ((self.pillar == "income") != self.is_income):
            raise ValueError("Trụ cột phải khớp loại thu nhập hoặc chi tiêu.")
        return self


class TagInput(Input):
    name: Text
    color: Color = "#64748B"


class TransactionTagInput(Input):
    transaction_id: Identifier
    tag_id: Identifier


class BudgetInput(Input):
    category_id: Identifier | None = None
    pillar: ExpensePillar | None = None
    month_year: date
    limit_amount: PositiveMoney
    alert_threshold_percent: Annotated[int, Field(ge=1, le=100)] = 80

    @model_validator(mode="after")
    def target(self):
        if self.month_year.day != 1:
            raise ValueError("Ngân sách phải chọn ngày đầu tháng.")
        if self.category_id and self.pillar:
            raise ValueError("Chỉ chọn danh mục hoặc trụ cột cho ngân sách.")
        return self


class GoalInput(Input):
    name: Text
    account_id: Identifier | None = None
    target_amount: PositiveMoney
    current_amount: NonnegativeMoney = Decimal(0)
    target_date: date | None = None
    color: Color = "#10B981"
    icon: Text = "savings"
    status: Literal["in_progress", "completed", "cancelled"] = "in_progress"
    notes: Annotated[str, Field(max_length=10000)] | None = None


class DebtInput(Input):
    type: Literal["debt", "loan"]
    person_name: Text
    phone_number: Text | None = None
    amount: PositiveMoney
    paid_amount: NonnegativeMoney = Decimal(0)
    due_date: date | None = None
    interest_rate: Annotated[
        Decimal, Field(ge=0, le=Decimal("999.99"), max_digits=5, decimal_places=2)
    ] = Decimal(0)
    status: Literal["pending", "partial", "paid", "overdue"] = "pending"
    notes: Annotated[str, Field(max_length=10000)] | None = None

    @model_validator(mode="after")
    def paid_limit(self):
        if self.paid_amount > self.amount:
            raise ValueError("Số tiền đã thanh toán vượt quá khoản nợ.")
        return self


class RecurringInput(Input):
    account_id: Identifier | None = None
    category_id: Identifier | None = None
    amount: PositiveMoney
    transaction_type: Literal["income", "expense"]
    description: Text
    frequency: Literal["daily", "weekly", "biweekly", "monthly", "quarterly", "yearly"]
    start_date: date
    end_date: date | None = None
    next_execution_date: date
    auto_create: bool = True
    is_active: bool = True

    @model_validator(mode="after")
    def dates(self):
        if self.next_execution_date < self.start_date:
            raise ValueError("Ngày thực hiện tiếp theo phải từ ngày bắt đầu.")
        if self.end_date and self.end_date < self.next_execution_date:
            raise ValueError("Ngày kết thúc phải từ ngày thực hiện tiếp theo.")
        return self


class ForecastInput(Input):
    forecast_date: date
    predicted_balance: Money
    predicted_income: NonnegativeMoney = Decimal(0)
    predicted_expense: NonnegativeMoney = Decimal(0)
    lower_bound: Money | None = None
    upper_bound: Money | None = None
    risk_level: Literal["safe", "warning", "danger"] = "safe"
    model_name: Text = "DLinear-v1"

    @model_validator(mode="after")
    def bounds(self):
        if self.lower_bound is not None and self.upper_bound is not None:
            if self.lower_bound > self.upper_bound:
                raise ValueError("Cận dưới không được vượt cận trên.")
        return self


class AlertInput(Input):
    alert_type: Literal[
        "deficit_risk", "budget_exceeded", "unusual_expense", "low_balance", "bill_due"
    ]
    severity: Literal["info", "warning", "critical"] = "warning"
    title: Text
    message: Annotated[str, Field(min_length=1, max_length=10000)]
    predicted_deficit_date: date | None = None
    predicted_deficit_amount: NonnegativeMoney | None = None
    suggested_action: Annotated[str, Field(max_length=10000)] | None = None
    is_read: bool = False
    is_resolved: bool = False


class ConsultationInput(Input):
    user_query: Annotated[str, Field(min_length=1, max_length=10000)]
    context_summary: dict | None = None
    ai_recommendation: Annotated[str, Field(min_length=1, max_length=10000)]


class SessionInput(Input):
    title: Text = "Cuộc trò chuyện tư vấn"


class MessageInput(Input):
    session_id: Identifier
    sender: Literal["user", "assistant", "system"]
    content: Annotated[str, Field(min_length=1, max_length=10000)]
    context_snapshot: dict | None = None


class ProfileInput(Input):
    full_name: Text | None = None
    avatar_url: Annotated[str, Field(max_length=2000)] | None = None
    currency: Annotated[str, Field(pattern=r"^[A-Z]{3}$")] = "VND"
    payroll_day: Day | None = 5
    monthly_savings_target: NonnegativeMoney | None = Decimal(0)
    reminder_time: time | None = time(20, 30)
    biometrics_enabled: bool = True
    dark_mode_enabled: bool = False


RESOURCES: dict[str, tuple[str, type[Input]]] = {
    "accounts": ("Ví và tài khoản", AccountInput),
    "categories": ("Danh mục", CategoryInput),
    "tags": ("Thẻ", TagInput),
    "transaction_tags": ("Thẻ giao dịch", TransactionTagInput),
    "budgets": ("Ngân sách", BudgetInput),
    "saving_goals": ("Mục tiêu tiết kiệm", GoalInput),
    "debts_loans": ("Sổ nợ và cho vay", DebtInput),
    "recurring_transactions": ("Giao dịch định kỳ", RecurringInput),
    "cashflow_forecasts": ("Dự báo dòng tiền", ForecastInput),
    "cashflow_alerts": ("Cảnh báo", AlertInput),
    "ai_consultations": ("Lịch sử tư vấn", ConsultationInput),
    "ai_chat_sessions": ("Cuộc trò chuyện", SessionInput),
    "ai_chat_messages": ("Tin nhắn tư vấn", MessageInput),
    "profile": ("Hồ sơ cá nhân", ProfileInput),
}


class ManagementRepository(Protocol):
    user_id: str

    def list(self, resource: str, limit: int, offset: int) -> dict: ...
    def get(self, resource: str, key: str) -> dict: ...
    def create(self, resource: str, data: dict) -> dict: ...
    def update(self, resource: str, key: str, data: dict) -> dict: ...
    def delete(self, resource: str, key: str) -> None: ...
    def referenced(self, table: str, column: str, value: int) -> bool: ...
