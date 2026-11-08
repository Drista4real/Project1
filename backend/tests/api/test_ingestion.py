"""Authenticated analysis returns editable drafts and never writes transactions."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import UserContext, get_user_context
from app.domain.interfaces.classifier_interface import ClassificationResult
from app.infrastructure.ai import transaction_parser as parser_module
from app.main import app


@pytest.fixture
def ingestion(monkeypatch):
    """Use local doubles without Supabase writes or live cloud calls."""
    classifier = SimpleNamespace(
        classify=lambda text: ClassificationResult("Ăn uống", 0.92)
    )
    monkeypatch.setattr(parser_module, "local_classifier", lambda: classifier)
    cloud = AsyncMock(return_value=None)
    monkeypatch.setattr(
        parser_module.NaturalTransactionParser, "_cloud_category", cloud
    )
    app.dependency_overrides[get_user_context] = lambda: UserContext(
        client=SimpleNamespace(), user_id="test-user"
    )
    try:
        yield TestClient(app), cloud
    finally:
        app.dependency_overrides.pop(get_user_context, None)


@pytest.mark.parametrize(
    ("text", "amount"),
    [
        ("bún bò 40 cành tiền mặt", 40000),
        ("tiền nhà 3 củ rưỡi", 3500000),
        ("cà phê 12,5k", 12500),
        ("cơm sườn ba lăm k", 35000),
        ("ăn trưa 50.000 đồng", 50000),
    ],
)
def test_extracts_vnd_locally(ingestion, text, amount):
    """Supported typed and spoken money reaches a draft without cloud math."""
    api, cloud = ingestion
    response = api.post("/api/v1/ingestion/text", json={"text": text})
    assert response.status_code == 200
    draft = response.json()["drafts"][0]
    assert draft["amount"] == amount
    assert draft["category"] == "Ăn uống"
    assert draft["source"] == "LOCAL"
    cloud.assert_not_called()


def test_explicit_clauses_become_separate_drafts(ingestion):
    """The reference UI's two expenses are not merged into a single amount."""
    api, _ = ingestion
    response = api.post(
        "/api/v1/ingestion/text",
        json={"text": "Ăn trưa bún bò 65k, uống trà sữa 35k chuyển khoản lúc 12h30"},
    )
    assert [draft["amount"] for draft in response.json()["drafts"]] == [65000, 35000]


@pytest.mark.parametrize(
    "text", ["cà phê", "cà phê 0k", "chi -50k", "chi - 50000 đồng"]
)
def test_unknown_or_invalid_money_needs_review(ingestion, text):
    """Never create a default monetary amount for an incomplete utterance."""
    api, cloud = ingestion
    draft = api.post("/api/v1/ingestion/text", json={"text": text}).json()["drafts"][0]
    assert draft["amount"] is None
    assert draft["warnings"]
    cloud.assert_not_called()


def test_ambiguous_amounts_are_not_added(ingestion):
    """Without a clear boundary, one draft requests explicit correction."""
    api, _ = ingestion
    drafts = api.post(
        "/api/v1/ingestion/text", json={"text": "cà phê 40k giảm còn 20k"}
    ).json()["drafts"]
    assert len(drafts) == 1
    assert drafts[0]["amount"] is None


def test_low_confidence_uses_category_fallback_only(ingestion, monkeypatch):
    """Cloud suggestions never replace deterministic amounts."""
    api, cloud = ingestion
    classify = Mock(return_value=ClassificationResult("Khác", 0.4))
    monkeypatch.setattr(
        parser_module,
        "local_classifier",
        lambda: SimpleNamespace(classify=classify),
    )
    cloud.return_value = parser_module.CategorySuggestion(
        category="Đi lại", confidence=0.9
    )
    draft = api.post("/api/v1/ingestion/text", json={"text": "đổ xăng 50k"}).json()[
        "drafts"
    ][0]
    assert draft["amount"] == 50000
    assert draft["category"] == "Đi lại"
    assert draft["source"] == "GEMINI"
    cloud.assert_awaited_once()
    classify.assert_called_once()
    assert not draft["warnings"]


def test_missing_models_return_honest_unclassified_draft(ingestion, monkeypatch):
    """An absent optional classifier does not generate a fake prediction."""
    api, _ = ingestion
    monkeypatch.setattr(parser_module, "local_classifier", lambda: None)
    draft = api.post("/api/v1/ingestion/text", json={"text": "ăn trưa 65k"}).json()[
        "drafts"
    ][0]
    assert draft["amount"] == 65000
    assert draft["category"] is None
    assert draft["source"] == "UNAVAILABLE"


def test_income_and_wallet_transfer_are_not_expenses(ingestion):
    """Local income cues and inter-wallet movement retain distinct meanings."""
    api, cloud = ingestion
    income = api.post(
        "/api/v1/ingestion/text", json={"text": "nhận lương 12tr"}
    ).json()["drafts"][0]
    transfer = api.post(
        "/api/v1/ingestion/text", json={"text": "chuyển 500k sang ví tiền mặt"}
    ).json()["drafts"][0]
    assert income["transaction_type"] == "income"
    assert income["amount"] == 12000000
    assert transfer["transaction_type"] == "transfer"
    cloud.assert_not_called()


@pytest.mark.parametrize("text", ["   ", ";;;", "x" * 2001, ";".join(["ăn 1k"] * 6)])
def test_invalid_request_limits(ingestion, text):
    """Bound batch size and input size before expensive inference."""
    api, _ = ingestion
    assert api.post("/api/v1/ingestion/text", json={"text": text}).status_code == 422


def test_analysis_requires_authentication():
    """Public callers cannot consume the AI endpoint."""
    assert (
        TestClient(app)
        .post("/api/v1/ingestion/text", json={"text": "ăn trưa 65k"})
        .status_code
        == 401
    )


def test_cloud_can_select_the_users_actual_category(ingestion, monkeypatch):
    """Custom categories map back to actual client IDs and envelopes."""
    api, cloud = ingestion
    monkeypatch.setattr(parser_module, "local_classifier", lambda: None)
    schema = parser_module.category_schema(("Ăn uống gia đình", "Cà phê & gặp gỡ"))
    cloud.return_value = schema(category="Cà phê & gặp gỡ", confidence=0.91)
    response = api.post(
        "/api/v1/ingestion/text",
        json={
            "text": "trà sữa 35k",
            "categories": [{"name": "Ăn uống gia đình"}, {"name": "Cà phê & gặp gỡ"}],
        },
    )
    assert response.status_code == 200
    assert response.json()["drafts"][0]["category"] == "Cà phê & gặp gỡ"
    assert schema.model_json_schema()["properties"]["category"]["enum"] == [
        "Ăn uống gia đình",
        "Cà phê & gặp gỡ",
    ]


def test_income_uses_income_reference_labels(ingestion):
    """Income is kept out of the expense label vocabulary."""
    api, cloud = ingestion
    schema = parser_module.category_schema(("Lương công ty", "Thu nhập làm thêm"))
    cloud.return_value = schema(category="Lương công ty", confidence=0.94)
    response = api.post(
        "/api/v1/ingestion/text",
        json={
            "text": "nhận lương 12tr",
            "categories": [
                {"name": "Lương công ty", "is_income": True},
                {"name": "Thu nhập làm thêm", "is_income": True},
            ],
        },
    )
    assert response.status_code == 200
    assert response.json()["drafts"][0]["category"] == "Lương công ty"
    assert response.json()["drafts"][0]["transaction_type"] == "income"
    cloud.assert_not_awaited()
    assert response.json()["drafts"][0]["source"] == "RULES"


def test_cloud_can_infer_income_from_an_unfamiliar_description(ingestion, monkeypatch):
    """Semantic type detection is not restricted to the local income keywords."""
    api, cloud = ingestion
    monkeypatch.setattr(parser_module, "local_classifier", lambda: None)
    schema = parser_module.category_schema(("Thu nhập phụ", "Chi phí khác"))
    cloud.return_value = schema(
        category="Thu nhập phụ", transaction_type="income", confidence=0.95
    )
    draft = api.post(
        "/api/v1/ingestion/text",
        json={
            "text": "khách thanh toán cho mình 500k",
            "categories": [
                {"name": "Thu nhập phụ", "is_income": True},
                {"name": "Chi phí khác"},
            ],
        },
    ).json()["drafts"][0]
    assert draft["transaction_type"] == "income"
    assert draft["category"] == "Thu nhập phụ"
    assert draft["amount"] == 500000


@pytest.mark.parametrize("separator", [", ", " "])
def test_users_five_expenses_are_automatically_categorized(
    ingestion, monkeypatch, separator
):
    """The reported example resolves offline even when Gemini is unavailable."""
    api, cloud = ingestion
    monkeypatch.setattr(parser_module, "local_classifier", lambda: None)
    names = [
        "Ăn uống & Đi chợ",
        "Sửa chữa xe cộ & Đồ gia dụng",
        "Khám chữa bệnh & Thuốc men",
    ]
    response = api.post(
        "/api/v1/ingestion/text",
        json={
            "text": separator.join(
                [
                    "ăn sáng cơm tấm 30k momo",
                    "ăn trưa bún bò 30k tiền mặt",
                    "ăn chiều 45k momo",
                    "sửa xe 100k momo",
                    "tiền thuốc 100k tiền mặt",
                ]
            ),
            "categories": [{"name": name} for name in names],
        },
    )
    assert response.status_code == 200
    drafts = response.json()["drafts"]
    assert [d["amount"] for d in drafts] == [30000, 30000, 45000, 100000, 100000]
    assert [d["category"] for d in drafts] == [names[0]] * 3 + names[1:]
    assert all(d["source"] == "RULES" for d in drafts)
    assert "momo" in drafts[0]["text"]
    assert "tiền mặt" in drafts[1]["text"]
    cloud.assert_not_awaited()


def test_spoken_money_without_punctuation(ingestion):
    """ASR does not need to produce punctuation for multiple expense drafts."""
    api, _ = ingestion
    response = api.post(
        "/api/v1/ingestion/text",
        json={
            "text": "cơm ba mươi nghìn tiền mặt trà sữa ba lăm k sửa xe một trăm nghìn",
        },
    )
    assert [d["amount"] for d in response.json()["drafts"]] == [30000, 35000, 100000]


@pytest.mark.parametrize(
    "text",
    [
        "cà phê 40k tổng 60k",
        "mua sách từ 20k đến 50k",
        "ăn 30k 40k",
        "cơm 30k, trà 20k, tổng 50k",
    ],
)
def test_totals_ranges_and_unlabeled_amounts_need_review(ingestion, text):
    """Totals and ranges are not made into new spending records."""
    api, _ = ingestion
    drafts = api.post("/api/v1/ingestion/text", json={"text": text}).json()["drafts"]
    assert len(drafts) == 1
    assert drafts[0]["amount"] is None


def test_unknown_batch_uses_one_cloud_call_and_preserves_money(ingestion, monkeypatch):
    """AI classifications select real labels without rewriting monetary amounts."""
    api, _ = ingestion
    monkeypatch.setattr(parser_module, "local_classifier", lambda: None)
    cloud = AsyncMock(
        return_value=[
            parser_module.BatchSuggestion(
                index=0, category="Thú cưng", transaction_type="expense", confidence=0.9
            ),
            parser_module.BatchSuggestion(
                index=1, category="Vườn nhà", transaction_type="expense", confidence=0.9
            ),
        ]
    )
    monkeypatch.setattr(parser_module.NaturalTransactionParser, "_cloud_batch", cloud)
    response = api.post(
        "/api/v1/ingestion/text",
        json={
            "text": "pate cho mèo 35k chậu lan 120k",
            "categories": [{"name": "Thú cưng"}, {"name": "Vườn nhà"}],
        },
    )
    drafts = response.json()["drafts"]
    assert [d["category"] for d in drafts] == ["Thú cưng", "Vườn nhà"]
    assert [d["amount"] for d in drafts] == [35000, 120000]
    cloud.assert_awaited_once()
