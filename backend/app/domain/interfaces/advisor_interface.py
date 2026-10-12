"""Pure-domain asynchronous persona advice port; no model or framework imports."""

from typing import Literal, Protocol

AlertType = Literal["CASHFLOW_MISMATCH", "WINDFALL_DEPLETION", "SAFE"]


class IAdvisorAlert(Protocol):
    """Read-only advice fields shared by infrastructure schemas and consumers."""

    @property
    def alert_type(self) -> AlertType:
        """Return the deterministic risk classification."""
        ...

    @property
    def message(self) -> str:
        """Return a short explanation, not a numerical forecast."""
        ...

    @property
    def suggested_action(self) -> str | None:
        """Return an optional practical action."""
        ...


class IFinancialAdvisor(Protocol):
    """Generate prose from metrics and flags already calculated by Model 2."""

    async def generate_fixed_income_alert(
        self,
        current_balance: float,
        days_to_payday: int,
        trajectory: list[dict[str, object]],
        alert_flag: bool,
    ) -> IAdvisorAlert:
        """Explain fixed-income cashflow mismatch without recalculating it."""
        ...

    async def generate_flexible_income_alert(
        self,
        current_balance: float,
        runway_days: float | None,
        safe_to_spend: float,
        alert_flag: bool,
    ) -> IAdvisorAlert:
        """Explain flexible-income depletion using the supplied daily limit."""
        ...
