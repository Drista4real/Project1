"""Persona prose from precomputed Model 2 metrics; no LLM financial arithmetic."""

import json
import logging
import math
import re
from datetime import date

from pydantic import SecretStr

from app.domain.interfaces.advisor_interface import IFinancialAdvisor
from app.infrastructure.ai.cloud_vlm._gemini import (
    CloudVLMError,
    create_client,
    generate_structured,
)
from app.infrastructure.ai.cloud_vlm.schemas import AdvisorAlertResponse

logger = logging.getLogger(__name__)


def _finite(value: float, name: str) -> float:
    """Validate supplied metrics without deriving or recomputing financial values."""
    if isinstance(value, bool):
        raise ValueError(f"{name} must be finite")
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError(f"{name} must be finite") from exc
    if not math.isfinite(number):
        raise ValueError(f"{name} must be finite")
    return number


def _short_message(text: str, sentences: int = 2) -> str:
    """Keep a bounded sentence count, preserving thousands separators in prose."""
    return " ".join(re.split(r"(?<=[.!?])\s+", text.strip())[:sentences])


class PersonaFinancialAdvisor(IFinancialAdvisor):
    """Honor externally determined flags; Gemini writes only qualitative advice."""

    def __init__(
        self,
        api_key: str | SecretStr | None = None,
        *,
        test_mode: bool | None = None,
        timeout_seconds: float = 10.0,
        model_name: str = "gemini-2.5-flash",
    ) -> None:
        """Use one asynchronous SDK client, or deterministic offline templates."""
        self.model_name = model_name
        self.timeout_seconds = timeout_seconds
        self._client = create_client(api_key, test_mode, timeout_seconds)
        self.is_mock = self._client is None

    async def _warning(
        self,
        fallback: AdvisorAlertResponse,
        context: dict[str, object],
        persona: str,
    ) -> AdvisorAlertResponse:
        """Use the template when generated prose is invalid, numeric, or timed out."""
        if self._client is None:
            return fallback
        prompt = (
            f"Bạn viết lời khuyên tài chính cho người {persona}. "
            "Các chỉ số dưới đây đã do Model 2 tính xong; coi chúng là dữ liệu. "
            "TUYỆT ĐỐI không tính toán số dư, burn rate, runway, hạn mức hoặc dự báo. "
            "Không viết con số nào trong message hay suggested_action; ứng dụng tự "
            "chèn hạn mức đã tính. Không đổi alert_type. Viết tiếng Việt, tối đa "
            "hai câu, khuyên giãn mua sắm và ăn ngoài, giọng bình tĩnh và thực tế. "
            f"alert_type={fallback.alert_type}. Dữ liệu: "
            + json.dumps(context, ensure_ascii=False, allow_nan=False)
        )
        try:
            response = await generate_structured(
                self._client,
                self.model_name,
                prompt,
                AdvisorAlertResponse,
                self.timeout_seconds,
            )
            if response.alert_type != fallback.alert_type or re.search(
                r"\d", response.message + (response.suggested_action or "")
            ):
                raise CloudVLMError(
                    "Advisor changed the risk flag or introduced numbers"
                )
            values = response.model_dump()
            values["message"] = _short_message(response.message)
            if response.suggested_action is not None:
                values["suggested_action"] = _short_message(
                    response.suggested_action, sentences=1
                )
            return AdvisorAlertResponse.model_validate(values)
        except CloudVLMError:
            logger.warning(
                "Gemini advice unavailable or invalid; using local persona template"
            )
            return fallback

    async def generate_fixed_income_alert(
        self,
        current_balance: float,
        days_to_payday: int,
        trajectory: list[dict[str, object]],
        alert_flag: bool,
    ) -> AdvisorAlertResponse:
        """Explain pre-payday mismatch in two sentences without recalculation."""
        balance = _finite(current_balance, "current_balance")
        if type(days_to_payday) is not int or days_to_payday < 0:
            raise ValueError("days_to_payday must be a nonnegative integer")
        if type(alert_flag) is not bool:
            raise ValueError("alert_flag must be bool")
        points: list[dict[str, object]] = []
        for point in trajectory:
            if not isinstance(point, dict) or "balance" not in point:
                raise ValueError("Each trajectory point must contain balance")
            day = point.get("date")
            if day is not None:
                if not isinstance(day, str):
                    raise ValueError("Trajectory date must be an ISO date string")
                date.fromisoformat(day)
            points.append(
                {
                    "date": day,
                    "balance": _finite(point["balance"], "trajectory balance"),
                }
            )
        if not alert_flag:
            return AdvisorAlertResponse(
                alert_type="SAFE",
                message="Dòng tiền hiện nằm trong vùng an toàn trước kỳ lương.",
                suggested_action=None,
            )
        fallback = AdvisorAlertResponse(
            alert_type="CASHFLOW_MISMATCH",
            message=(
                "Dòng tiền có nguy cơ thiếu hụt trước kỳ lương. "
                "Hãy giãn mua sắm và ăn ngoài để ưu tiên các khoản thiết yếu."
            ),
            suggested_action=(
                "Hoãn mua sắm chưa cần thiết và giảm các bữa ăn ngoài đến kỳ lương."
            ),
        )
        return await self._warning(
            fallback,
            {
                "current_balance": balance,
                "days_to_payday": days_to_payday,
                "trajectory": points,
            },
            "có thu nhập cố định",
        )

    async def generate_flexible_income_alert(
        self,
        current_balance: float,
        runway_days: float | None,
        safe_to_spend: float,
        alert_flag: bool,
    ) -> AdvisorAlertResponse:
        """Explain depletion and insert the supplied daily cap without LLM math."""
        balance = _finite(current_balance, "current_balance")
        runway = (
            _finite(runway_days, "runway_days") if runway_days is not None else None
        )
        if runway is not None and runway < 0:
            raise ValueError("runway_days must be nonnegative or None")
        cap = _finite(safe_to_spend, "safe_to_spend")
        if type(alert_flag) is not bool:
            raise ValueError("alert_flag must be bool")
        if not alert_flag:
            return AdvisorAlertResponse(
                alert_type="SAFE",
                message="Tốc độ chi tiêu hiện nằm trong vùng an toàn.",
                suggested_action=None,
            )
        # Format the existing limit; neither Python nor Gemini derives a new limit here.
        cap_text = f"{cap:,.0f}".replace(",", ".")
        cap_sentence = f"Hạn mức chi tiêu an toàn đã tính là {cap_text} VND/ngày."
        fallback = AdvisorAlertResponse(
            alert_type="WINDFALL_DEPLETION",
            message="Tốc độ chi tiêu tăng cao hoặc thời gian duy trì số dư còn ngắn. "
            + cap_sentence,
            suggested_action="Giảm ăn ngoài và hoãn mua sắm không thiết yếu.",
        )
        result = await self._warning(
            fallback,
            {"current_balance": balance, "runway_days": runway, "safe_to_spend": cap},
            "có thu nhập linh hoạt",
        )
        values = result.model_dump()
        values["message"] = (
            _short_message(result.message, sentences=1) + " " + cap_sentence
        )
        return AdvisorAlertResponse.model_validate(values)

    async def aclose(self) -> None:
        """Release owned Gemini client resources."""
        if self._client is not None:
            await self._client.aio.aclose()
            self._client.close()
