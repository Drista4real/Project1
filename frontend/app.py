"""Streamlit demo connecting directly to the four local/cloud AI adapters."""

from __future__ import annotations

import asyncio
import logging
import sys
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from time import perf_counter
from typing import TYPE_CHECKING, Any

import plotly.graph_objects as go
import streamlit as st

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

if TYPE_CHECKING:
    from app.domain.interfaces.classifier_interface import ITransactionClassifier
    from app.infrastructure.ai.edge_asr.normalizer import (
        VietnameseFinancialSlangNormalizer,
    )
    from app.infrastructure.ai.edge_asr.recognizer import SherpaOnnxRecognizer
    from app.infrastructure.ai.forecaster.fixed_income import FixedIncomeForecaster

logger = logging.getLogger(__name__)
HANDLED_ERRORS = (ImportError, OSError, ValueError, RuntimeError)


class QwenNotConfiguredError(RuntimeError):
    """Uploaded images require a configured real Qwen client."""


@dataclass(frozen=True)
class Controls:
    """One immutable dashboard scenario, used to invalidate stale output."""

    profile: str
    balance: float
    as_of: date
    payday: date | None
    daily_expense: float
    use_history: bool


def money(value: float | int | None) -> str:
    """Format an existing VND amount without changing model calculations."""
    return "Chưa xác định" if value is None else f"{value:,.0f} ₫".replace(",", ".")


@st.cache_resource(show_spinner=False)
def classifier() -> ITransactionClassifier:
    """Load PhoBERT and the classifier once, only when classification is requested."""
    from app.infrastructure.config.settings import get_settings

    settings = get_settings()
    if settings.classifier_backend == "lora":
        from app.infrastructure.ai.classifier.lora import LoRAClassifier

        return LoRAClassifier(
            settings.classifier_lora_dir,
            device=settings.classifier_device,
            cache_dir=settings.classifier_lora_cache_dir,
            local_files_only=True,
        )
    from app.infrastructure.ai.classifier.lgbm_inference import (
        LightGBMTransactionClassifier,
    )

    return LightGBMTransactionClassifier()


def predict_category(
    model: ITransactionClassifier, text: str
) -> tuple[str, float, str]:
    """Use the common classifier contract for both direct local adapters."""
    result = model.classify(text)
    source = "LOCAL" if result.confidence >= 0.8 else "CLOUD_FALLBACK"
    return result.label, result.confidence, source


@st.cache_resource(show_spinner=False)
def normalizer() -> VietnameseFinancialSlangNormalizer:
    """Reuse the offline money normalizer."""
    from app.infrastructure.ai.edge_asr.normalizer import (
        VietnameseFinancialSlangNormalizer,
    )

    return VietnameseFinancialSlangNormalizer()


@st.cache_resource(show_spinner=False)
def recognizer(mock_mode: bool = False) -> SherpaOnnxRecognizer:
    """Reuse the offline recognizer and expose missing-model mock status."""
    from app.infrastructure.ai.edge_asr.recognizer import SherpaOnnxRecognizer

    return SherpaOnnxRecognizer(mock_mode=mock_mode)


@st.cache_resource(show_spinner=False)
def fixed_forecaster() -> FixedIncomeForecaster:
    """Load the delta checkpoint once; history is read by the adapter on demand."""
    from app.infrastructure.ai.forecaster.fixed_income import FixedIncomeForecaster

    return FixedIncomeForecaster()


def friendly_error(context: str, exc: Exception) -> None:
    """Display actionable errors without exposing stack traces or credentials."""
    logger.warning("%s failed (%s)", context, type(exc).__name__)
    provider = "Qwen" if context == "Đọc hóa đơn" else "Gemini"
    cloud_errors = {
        "timeout": "Gemini phản hồi quá chậm. Hãy thử lại hoặc dùng ảnh nhỏ hơn.",
        "auth": "Gemini từ chối API key hoặc quyền truy cập. Kiểm tra key đã cấu hình.",
        "quota": (
            "Gemini đã hết quota hoặc đang giới hạn lượt gọi. "
            "Kiểm tra hạn mức API rồi thử lại."
        ),
        "network": "Không kết nối được Gemini. Kiểm tra mạng rồi thử lại.",
        "unavailable": (
            "Gemini đang tạm quá tải hoặc chưa phục vụ được. Hãy thử lại sau."
        ),
        "request": (
            "Gemini từ chối định dạng yêu cầu. Cần kiểm tra cấu hình trích xuất."
        ),
        "model": "Model Gemini được cấu hình chưa khả dụng với API key này.",
        "validation": (
            "Gemini trả dữ liệu hóa đơn chưa hợp lệ về cấu trúc hoặc giá trị. "
            "Hãy thử đọc lại; nếu lỗi vẫn còn, cần kiểm tra phản hồi của model."
        ),
        "truncated": "Gemini trả phản hồi bị cắt trước khi hoàn thành hóa đơn.",
    }
    reason = getattr(exc, "reason", None)
    if reason in cloud_errors:
        st.error(f"{context}: {cloud_errors[reason].replace('Gemini', provider)}")
        details = getattr(exc, "validation_details", ())
        if details:
            st.caption("Chi tiết: " + "; ".join(details))
        return
    if isinstance(exc, ImportError):
        st.error(
            f"{context}: thiếu thư viện. "
            "Cài frontend/requirements-demo.txt rồi chạy lại."
        )
    elif isinstance(exc, FileNotFoundError):
        st.error(
            f"{context}: chưa có dữ liệu hoặc trọng số cần thiết. "
            "Sinh dữ liệu và huấn luyện model trước khi thử."
        )
    elif isinstance(exc, ValueError):
        st.error(
            f"{context}: dữ liệu chưa hợp lệ. "
            "Kiểm tra nội dung, định dạng file và ngày dự báo."
        )
    else:
        st.error(
            f"{context}: model chưa sẵn sàng hoặc dịch vụ phản hồi lỗi. "
            "Thử lại sau hoặc dùng mẫu Mock."
        )


def classify_text(text: str) -> dict[str, Any]:
    """Measure normalization and warmed local inference, preserving routing hints."""
    model = classifier()
    parser = normalizer()
    start = perf_counter()
    normalized, amount = parser.normalize(text)
    category, confidence, source = predict_category(model, normalized)
    return dict(
        text=normalized,
        amount=amount,
        category=category,
        confidence=confidence,
        source=source,
        latency=(perf_counter() - start) * 1000,
    )


def show_classification(result: dict[str, Any]) -> None:
    """Render metrics and distinguish a cloud routing hint from an actual call."""
    from app.infrastructure.config.settings import get_settings

    settings = get_settings()
    model_name = (
        "PhoBERT + LoRA"
        if settings.classifier_backend == "lora"
        else "PhoBERT + LightGBM"
    )
    device = (
        settings.classifier_device if settings.classifier_backend == "lora" else "cpu"
    )
    st.caption(f"{model_name} · {device}")
    st.write("**Văn bản chuẩn hóa:**", result["text"])
    columns = st.columns(4)
    columns[0].metric("Số tiền", money(result["amount"]))
    columns[1].metric("Danh mục", result["category"])
    columns[2].metric("Tin cậy P", f"{result['confidence']:.1%}")
    columns[3].metric("Latency", f"{result['latency']:.1f} ms")
    if result["source"] == "LOCAL":
        st.success("LOCAL · P ≥ 0,8")
    else:
        st.warning("CLOUD_FALLBACK · P < 0,8 — danh mục tạm thời, cần xác nhận.")
        st.caption(
            "Đây là tín hiệu định tuyến; chưa có lời gọi cloud phân loại trong demo."
        )
    if result["amount"] is None:
        st.info("Chưa nhận diện được số tiền. Bổ sung đơn vị như k, cành hoặc triệu.")
    if result.get("mock"):
        st.warning(
            "MOCK ASR · phiên âm giả lập, không phải kết quả nhận diện file audio."
        )
    st.caption(
        "Latency đo xử lý sau khi model đã nạp; không gồm thời gian nạp trọng số."
    )


async def extract_image(
    image: bytes, mime_type: str, mock: bool = False, api_key: str | None = None
) -> dict[str, Any]:
    """Own the async cloud client within one event loop and always close it."""
    from app.infrastructure.ai.cloud_vlm.qwen_client import QwenVLMReceiptExtractor

    extractor = QwenVLMReceiptExtractor(
        api_key=api_key,
        test_mode=True if mock else None,
        timeout_seconds=45.0,
    )
    start = perf_counter()
    try:
        if extractor.is_mock and not mock:
            raise QwenNotConfiguredError(
                "Chưa cấu hình Qwen để đọc ảnh thật. "
                "Nhập API key của nhà cung cấp trong mục Kết nối Qwen ở thanh bên."
            )
        result = await extractor.extract_receipt(image, mime_type)
        return dict(
            receipt=result.model_dump(),
            mock=extractor.is_mock,
            latency=(perf_counter() - start) * 1000,
        )
    finally:
        await extractor.aclose()


def ingestion_screen() -> None:
    """Render text, WAV/M4A/MP3 voice, and image receipt workflows with persistent results."""
    st.subheader("Ghi chép nhanh, xem AI hiểu gì")
    text_tab, voice_tab, receipt_tab = st.tabs(["Văn bản", "Giọng nói", "Hóa đơn"])
    with text_tab:
        text = st.text_input(
            "Nội dung giao dịch", placeholder="cơm sườn 35k", key="transaction_text"
        )
        st.caption("Thử: highland 55 cành · tiền trọ 3 củ rưỡi · mua áo 2 loét")
        if st.button("Phân tích Text", type="primary", key="analyze_text"):
            st.session_state.pop("text_result", None)
            if not text.strip():
                st.info("Nhập nội dung giao dịch để phân tích.")
            else:
                try:
                    with st.spinner("Đang phân tích giao dịch…"):
                        st.session_state["text_result"] = classify_text(text)
                        st.session_state["text_result"]["raw_input"] = text
                except HANDLED_ERRORS as exc:
                    friendly_error("Phân tích văn bản", exc)
        if (
            "text_result" in st.session_state
            and st.session_state["text_result"].get("raw_input") == text
        ):
            show_classification(st.session_state["text_result"])
    with voice_tab:
        audio = st.file_uploader(
            "Tải âm thanh (WAV, M4A, MP3)",
            type=["wav", "m4a", "mp3"],
            key="voice_file",
        )
        if audio is not None:
            st.audio(audio.getvalue(), format=audio.type or "audio/wav")
        analyze, quick = st.columns(2)
        run_audio = analyze.button("Phân tích Voice", key="analyze_voice")
        run_mock = quick.button("Test phiên âm mẫu (MOCK)", key="quick_voice")
        if st.button("Nạp lại model ASR", key="reload_asr"):
            recognizer.clear()
            st.session_state.pop("voice_result", None)
            st.info("Đã xóa cache ASR. Bấm Phân tích Voice để kiểm tra model mới.")
        if run_audio or run_mock:
            st.session_state.pop("voice_result", None)
            try:
                with st.spinner("Đang phiên âm và phân loại…"):
                    engine = recognizer(mock_mode=run_mock)
                    if run_audio and audio is None:
                        st.info("Chọn file âm thanh trước khi phân tích.")
                    elif run_audio and engine.is_mock:
                        st.error(
                            "Chưa có model ASR để nhận diện file âm thanh đã tải lên. "
                            "Cần encoder.onnx, decoder.onnx và tokens.txt trong "
                            "weights/onnx/phowhisper-tiny/ "
                            "(hoặc encoder.int8.onnx và decoder.int8.onnx). "
                            "Sau khi thêm model, bấm Nạp lại model ASR."
                        )
                    else:
                        model = classifier()
                        start = perf_counter()
                        normalized, amount = engine.transcribe_and_normalize(
                            audio.getvalue()
                            if run_audio and audio is not None
                            else b"mock-audio"
                        )
                        category, confidence, source = predict_category(
                            model, normalized
                        )
                        st.session_state["voice_result"] = dict(
                            text=normalized,
                            amount=amount,
                            category=category,
                            confidence=confidence,
                            source=source,
                            mock=engine.is_mock,
                            latency=(perf_counter() - start) * 1000,
                        )
            except HANDLED_ERRORS as exc:
                friendly_error("Phân tích giọng nói", exc)
        if "voice_result" in st.session_state:
            show_classification(st.session_state["voice_result"])
    with receipt_tab:
        image = st.file_uploader(
            "Tải ảnh hóa đơn", type=["jpg", "jpeg", "png"], key="receipt_file"
        )
        if image is not None:
            try:
                st.image(image.getvalue(), width=360)
            except (OSError, ValueError):
                st.warning("Ảnh chưa đọc được; hãy chọn ảnh JPEG hoặc PNG hợp lệ.")
        analyze, quick = st.columns(2)
        run_image = analyze.button("Đọc hóa đơn", key="analyze_receipt")
        run_mock = quick.button("Test hóa đơn mẫu (MOCK)", key="quick_receipt")
        if run_image or run_mock:
            st.session_state.pop("receipt_result", None)
            if run_image and image is None:
                st.info("Chọn ảnh hóa đơn trước khi phân tích.")
            else:
                try:
                    with st.spinner("Đang đọc hóa đơn…"):
                        mime = (
                            "image/png"
                            if image is not None and image.name.lower().endswith(".png")
                            else "image/jpeg"
                        )
                        st.session_state["receipt_result"] = asyncio.run(
                            extract_image(
                                image.getvalue()
                                if run_image and image is not None
                                else b"mock-receipt",
                                mime,
                                mock=run_mock,
                                api_key=st.session_state.get("qwen_api_key") or None,
                            )
                        )
                except QwenNotConfiguredError as exc:
                    st.error(str(exc))
                except HANDLED_ERRORS as exc:
                    friendly_error("Đọc hóa đơn", exc)
        if "receipt_result" in st.session_state:
            result = st.session_state["receipt_result"]
            receipt = result["receipt"]
            columns = st.columns(3)
            columns[0].metric("Tổng hóa đơn", money(receipt["total_amount"]))
            columns[1].metric("Tin cậy", f"{receipt['confidence_score']:.0%}")
            columns[2].metric("Latency", f"{result['latency']:.0f} ms")
            st.write("**Cửa hàng:**", receipt["merchant_name"])
            st.write("**Danh mục:**", receipt["category"])
            st.write(
                "**Ngày giao dịch:**", receipt["transaction_date"] or "Chưa đọc được"
            )
            st.badge("Powered by Qwen2.5-VL (Document VLM)", color="blue")
            st.dataframe(receipt["items"], hide_index=True, width="stretch")
            if receipt["is_arithmetic_valid"]:
                st.success("Tổng các món khớp hóa đơn trong ngưỡng sai lệch 5%.")
            else:
                st.warning(
                    "Tổng tiền lệch hoặc thiếu chi tiết món. Cần người dùng xác nhận."
                )
            if result["mock"]:
                st.warning(
                    "MOCK VLM · hóa đơn mẫu, "
                    "không phải dữ liệu trích xuất từ ảnh tải lên."
                )
            else:
                st.caption("CLOUD · Qwen Structured Output")


def sidebar_controls() -> Controls:
    """Collect a scenario using actual available history dates and explicit inputs."""
    with st.sidebar:
        with st.expander("Kết nối Qwen"):
            st.text_input(
                "Qwen API key (FPT Cloud / OpenRouter / DashScope)",
                type="password",
                key="qwen_api_key",
                help="Dùng cho đọc hóa đơn; để trống để dùng cấu hình cục bộ.",
            )
            st.caption("Key nhập tại đây chỉ dùng trong phiên làm việc hiện tại.")
        with st.expander("Kết nối Gemini"):
            st.text_input(
                "GEMINI_API_KEY",
                type="password",
                key="gemini_api_key",
                help=(
                    "Dùng cho AI Advisor và Fallback NLP; "
                    "để trống để dùng biến môi trường."
                ),
            )
            st.caption("Key nhập tại đây chỉ dùng trong phiên làm việc hiện tại.")
        st.header("Kịch bản dòng tiền")
        profile = st.radio(
            "Hồ sơ", ["Thu nhập cố định", "Thu nhập linh hoạt"], key="income_profile"
        )
        balance = st.number_input(
            "Số dư hiện tại (VND)", value=10_000_000.0, step=500_000.0, format="%.0f"
        )
        today = datetime.now(timezone(timedelta(hours=7))).date()
        first, last = today, today
        try:
            from app.infrastructure.ai.forecaster.features import load_daily_cashflows

            path = (
                ROOT
                / "data/processed"
                / (
                    "balance_fixed.csv"
                    if profile == "Thu nhập cố định"
                    else "balance_flexible.csv"
                )
            )
            rows = load_daily_cashflows(path)
            first = (
                rows[7].day
                if profile == "Thu nhập cố định" and len(rows) >= 8
                else rows[0].day
            )
            last = rows[-1].day
            st.caption(f"Lịch sử mô phỏng: {rows[0].day:%d/%m/%Y} – {last:%d/%m/%Y}")
        except HANDLED_ERRORS:
            st.caption("Chưa có lịch sử phù hợp. Sinh dữ liệu trước khi dự báo.")
        as_of = st.date_input(
            "Ngày bắt đầu dự báo",
            value=last,
            min_value=first,
            max_value=last,
            key=f"as_of_{profile}",
        )
        payday = None
        daily_expense = 200_000.0
        use_history = False
        if profile == "Thu nhập cố định":
            next_month = as_of.replace(day=28) + timedelta(days=4)
            default_payday = (
                as_of.replace(day=5) if as_of.day < 5 else next_month.replace(day=5)
            )
            payday = st.date_input(
                "Ngày nhận lương tiếp theo",
                value=default_payday,
                min_value=as_of + timedelta(days=1),
                max_value=as_of + timedelta(days=31),
                key=f"payday_{as_of}",
            )
            st.caption(
                "Dự báo dùng ngày lương được chọn; "
                "lương mô phỏng 15 triệu, tiền trọ ngày 30."
            )
        else:
            use_history = st.checkbox("Dùng chi tiêu từ lịch sử", value=False)
            daily_expense = st.number_input(
                "Chi tiêu trung bình/ngày (VND)",
                min_value=0.0,
                value=200_000.0,
                step=50_000.0,
                format="%.0f",
                disabled=use_history,
            )
            st.caption(
                "Nhập tay mô phỏng chi không đổi; "
                "lịch sử dùng các khoản chi thực tế trong CSV."
            )
    return Controls(
        profile, float(balance), as_of, payday, float(daily_expense), use_history
    )


async def advice(
    controls: Controls, result: dict[str, Any], api_key: str | None = None
) -> dict[str, Any]:
    """Generate persona advice from adapter metrics and close the per-task client."""
    from app.infrastructure.ai.cloud_vlm._gemini import configured_model_name
    from app.infrastructure.ai.cloud_vlm.advisor import PersonaFinancialAdvisor

    advisor = PersonaFinancialAdvisor(
        api_key=api_key, model_name=configured_model_name()
    )
    try:
        if controls.profile == "Thu nhập cố định":
            alert = await advisor.generate_fixed_income_alert(
                controls.balance,
                result["countdown_to_payday"],
                result["trajectory"],
                result["alert_flag"],
            )
        else:
            alert = await advisor.generate_flexible_income_alert(
                controls.balance,
                result["runway_days"],
                result["safe_to_spend"],
                result["alert_flag"],
            )
        return dict(alert=alert.model_dump(), mock=advisor.is_mock)
    finally:
        await advisor.aclose()


def calculate_dashboard(controls: Controls) -> dict[str, Any]:
    """Delegate all financial projections to Model 2 and prose to Model 4."""
    start = perf_counter()
    if controls.profile == "Thu nhập cố định":
        result = dict(
            fixed_forecaster().forecast_30_days(
                controls.balance, controls.as_of, payday_date=controls.payday
            )
        )
    else:
        from app.infrastructure.ai.forecaster.flexible_income import (
            FlexibleIncomeForecaster,
        )

        forecaster = FlexibleIncomeForecaster()
        expenses = (
            forecaster.load_expenses(controls.as_of)
            if controls.use_history
            else [controls.daily_expense] * 30
        )
        result = dict(forecaster.calculate_runway(controls.balance, expenses))
        result["trajectory"] = [
            dict(date=(controls.as_of + timedelta(days=i)).isoformat(), balance=b)
            for i, b in enumerate(result["trajectory_30d"], 1)
        ]
    result["model_latency"] = (perf_counter() - start) * 1000
    result.update(
        asyncio.run(
            advice(
                controls, result, api_key=st.session_state.get("gemini_api_key") or None
            )
        )
    )
    return result


def dashboard_screen(controls: Controls) -> None:
    """Display correct KPIs, a Plotly trajectory, and deterministic risk advice."""
    st.subheader("Nhìn trước dòng tiền 30 ngày")
    st.caption(f"{controls.profile} · Số dư khởi điểm {money(controls.balance)}")
    if st.button("Cập nhật dự báo", type="primary", key="update_forecast"):
        st.session_state.pop("dashboard_result", None)
        try:
            with st.spinner("Đang dự báo và chuẩn bị lời khuyên…"):
                st.session_state["dashboard_result"] = (
                    controls,
                    calculate_dashboard(controls),
                )
        except HANDLED_ERRORS as exc:
            friendly_error("Dự báo dòng tiền", exc)
    saved = st.session_state.get("dashboard_result")
    if saved is None or saved[0] != controls:
        st.info("Chọn kịch bản ở thanh bên và bấm Cập nhật dự báo.")
        return
    result = saved[1]
    columns = st.columns(3)
    if controls.profile == "Thu nhập cố định":
        columns[0].metric("Còn tới kỳ lương", f"{result['countdown_to_payday']} ngày")
        payday_balance = next(
            (
                p["balance"]
                for p in result["trajectory"]
                if p["date"] == controls.payday.isoformat()
            ),
            None,
        )
        columns[1].metric("Số dư ngày nhận lương", money(payday_balance))
        if payday_balance is None:
            columns[1].caption("Ngày lương nằm ngoài chuỗi dự báo 30 ngày.")
    else:
        runway = result["runway_days"]
        columns[0].metric(
            "Runway", "Không giới hạn" if runway is None else f"{runway:.1f} ngày"
        )
        columns[1].metric("Safe-to-spend / ngày", money(result["safe_to_spend"]))
    columns[2].metric("Dự báo Model 2", f"{result['model_latency']:.1f} ms")
    dates = [controls.as_of.isoformat()] + [p["date"] for p in result["trajectory"]]
    balances = [controls.balance] + [p["balance"] for p in result["trajectory"]]
    figure = go.Figure(
        go.Scatter(
            x=dates,
            y=balances,
            mode="lines+markers",
            name="Số dư dự kiến",
            line=dict(color="#24b7a4", width=3),
            marker=dict(size=4),
        )
    )
    figure.add_hline(
        y=0, line_dash="dash", line_color="#ef6b73", annotation_text="0 VND"
    )
    figure.update_layout(
        height=420,
        xaxis_title="Ngày",
        yaxis_title="Số dư (VND)",
        hovermode="x unified",
        margin=dict(l=20, r=20, t=30, b=20),
    )
    st.plotly_chart(figure, width="stretch", key="forecast_chart")
    st.subheader("AI Advisor")
    st.badge("Powered by Gemini 2.5 Flash (Financial Advisor)", color="violet")
    alert = result["alert"]
    if result["alert_flag"]:
        st.warning(alert["message"])
    else:
        st.success(alert["message"])
    if alert["suggested_action"]:
        st.write("**Gợi ý hành động:**", alert["suggested_action"])
    if result["mock"]:
        st.caption(
            "Advisor dùng mẫu lời khuyên cục bộ (MOCK); số liệu do Model 2 tính."
        )
    with st.expander("Xem bảng dự báo"):
        st.dataframe(result["trajectory"], hide_index=True, width="stretch")


def main() -> None:
    """Compose the standalone Streamlit demo without importing the FastAPI app."""
    st.set_page_config(page_title="Kakeibo · AI Lab", page_icon="💸", layout="wide")
    st.title("Kakeibo · AI Lab")
    st.caption("Ghi chép đa phương thức và dự báo dòng tiền cá nhân")
    controls = sidebar_controls()
    ingestion, dashboard = st.tabs(
        ["01 · Ghi chép & phân loại", "02 · Dự báo & Advisor"]
    )
    with ingestion:
        ingestion_screen()
    with dashboard:
        dashboard_screen(controls)


if __name__ == "__main__":
    main()
