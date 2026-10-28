"""Tests for cloud_vlm schemas."""

from datetime import date
from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.infrastructure.ai.cloud_vlm.schemas import (
    AdvisorAlertResponse,
    ReceiptExtractionResult,
    ReceiptItemSchema,
    ReceiptSchema,
    receipt_json_schema,
)


class TestReceiptItemSchema:
    """Tests for ReceiptItemSchema."""

    def test_valid_item(self):
        """Test creating a valid receipt item."""
        item = ReceiptItemSchema(name="Cà phê", quantity=2, price=25000)
        assert item.name == "Cà phê"
        assert item.quantity == 2
        assert item.price == 25000

    def test_valid_item_minimal(self):
        """Test creating item with defaults."""
        item = ReceiptItemSchema(name="Trà", price=0)
        assert item.name == "Trà"
        assert item.quantity == 1
        assert item.price == 0

    def test_empty_name_raises(self):
        """Test empty name raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptItemSchema(name="", quantity=1, price=1000)
        assert [e["loc"] for e in exc_info.value.errors()] == [("name",)]

    def test_quantity_less_than_one_raises(self):
        """Test quantity < 1 raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptItemSchema(name="Test", quantity=0, price=1000)
        assert [e["loc"] for e in exc_info.value.errors()] == [("quantity",)]

    def test_negative_price_raises(self):
        """Test negative price raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptItemSchema(name="Test", quantity=1, price=-100)
        assert [e["loc"] for e in exc_info.value.errors()] == [("price",)]

    def test_extra_fields_forbidden(self):
        """Test extra fields are forbidden."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptItemSchema(name="Test", price=1000, extra_field="not_allowed")
        assert [e["loc"] for e in exc_info.value.errors()] == [("extra_field",)]


class TestReceiptExtractionResult:
    """Tests for ReceiptExtractionResult."""

    def test_valid_extraction_result(self):
        """Test creating a valid extraction result."""
        result = ReceiptExtractionResult(
            merchant_name="Cà phê A",
            transaction_date="2024-01-15",
            items=[
                ReceiptItemSchema(name="Cà phê đen", quantity=1, price=30000),
                ReceiptItemSchema(name="Bánh mì", quantity=2, price=15000),
            ],
            total_amount=60000,
            category="Ăn uống",
            confidence_score=0.95,
            is_arithmetic_valid=True,
        )
        assert result.merchant_name == "Cà phê A"
        assert result.transaction_date == "2024-01-15"
        assert len(result.items) == 2
        assert result.total_amount == 60000
        assert result.category == "Ăn uống"
        assert result.confidence_score == 0.95
        assert result.is_arithmetic_valid is True

    def test_valid_without_date(self):
        """Test valid result without transaction_date."""
        result = ReceiptExtractionResult(
            merchant_name="Shop B",
            items=[ReceiptItemSchema(name="Item 1", quantity=1, price=10000)],
            total_amount=10000,
            category="Mua sắm",
            confidence_score=0.8,
        )
        assert result.transaction_date is None
        assert result.is_arithmetic_valid is False

    def test_invalid_date_format_raises(self):
        """Test invalid date format raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptExtractionResult(
                merchant_name="Test",
                transaction_date="15-01-2024",  # Wrong format
                items=[ReceiptItemSchema(name="Item", quantity=1, price=1000)],
                total_amount=1000,
                category="Khác",
                confidence_score=0.5,
            )
        assert [e["loc"] for e in exc_info.value.errors()] == [("transaction_date",)]

    def test_invalid_date_nonexistent_raises(self):
        """Test nonexistent date raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptExtractionResult(
                merchant_name="Test",
                transaction_date="2024-02-30",  # Invalid date
                items=[ReceiptItemSchema(name="Item", quantity=1, price=1000)],
                total_amount=1000,
                category="Khác",
                confidence_score=0.5,
            )
        assert [e["loc"] for e in exc_info.value.errors()] == [("transaction_date",)]

    def test_confidence_score_bounds(self):
        """Test confidence_score must be between 0 and 1."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptExtractionResult(
                merchant_name="Test",
                items=[ReceiptItemSchema(name="Item", quantity=1, price=1000)],
                total_amount=1000,
                category="Khác",
                confidence_score=-0.1,
            )
        assert [e["loc"] for e in exc_info.value.errors()] == [("confidence_score",)]
        with pytest.raises(ValidationError) as exc_info:
            ReceiptExtractionResult(
                merchant_name="Test",
                items=[ReceiptItemSchema(name="Item", quantity=1, price=1000)],
                total_amount=1000,
                category="Khác",
                confidence_score=1.1,
            )
        assert [e["loc"] for e in exc_info.value.errors()] == [("confidence_score",)]

    def test_total_amount_nonnegative(self):
        """Test total_amount must be non-negative."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptExtractionResult(
                merchant_name="Test",
                items=[ReceiptItemSchema(name="Item", quantity=1, price=1000)],
                total_amount=-1,
                category="Khác",
                confidence_score=0.5,
            )
        assert [e["loc"] for e in exc_info.value.errors()] == [("total_amount",)]

    def test_category_literal(self):
        """Test category must be one of the allowed literals."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptExtractionResult(
                merchant_name="Test",
                items=[ReceiptItemSchema(name="Item", quantity=1, price=1000)],
                total_amount=1000,
                category="Invalid Category",
                confidence_score=0.5,
            )
        assert [e["loc"] for e in exc_info.value.errors()] == [("category",)]

    def test_to_domain(self):
        """Test conversion to domain ReceiptData."""
        result = ReceiptExtractionResult(
            merchant_name="Test Merchant",
            transaction_date="2024-01-15",
            items=[
                ReceiptItemSchema(name="Item 1", quantity=2, price=5000),
            ],
            total_amount=10000,
            category="Ăn uống",
            confidence_score=0.9,
            is_arithmetic_valid=True,
        )
        domain = result.to_domain()
        assert domain.merchant == "Test Merchant"
        assert domain.total == Decimal("10000")
        assert domain.issued_on == date(2024, 1, 15)
        assert len(domain.items) == 1
        assert domain.items[0].name == "Item 1"
        assert domain.items[0].quantity == 2
        assert domain.items[0].price == 5000
        assert domain.category == "Ăn uống"
        assert domain.confidence_score == 0.9
        assert domain.is_arithmetic_valid is True

    def test_to_domain_without_date(self):
        """Test conversion to domain without date."""
        result = ReceiptExtractionResult(
            merchant_name="Test",
            items=[ReceiptItemSchema(name="Item", quantity=1, price=1000)],
            total_amount=1000,
            category="Khác",
            confidence_score=0.5,
        )
        domain = result.to_domain()
        assert domain.issued_on is None

    def test_empty_items_list_allowed(self):
        """Test empty items list is allowed."""
        result = ReceiptExtractionResult(
            merchant_name="Test",
            items=[],
            total_amount=0,
            category="Khác",
            confidence_score=0.5,
        )
        assert result.items == []

    def test_extra_fields_forbidden(self):
        """Test extra fields are forbidden."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptExtractionResult(
                merchant_name="Test",
                items=[ReceiptItemSchema(name="Item", quantity=1, price=1000)],
                total_amount=1000,
                category="Khác",
                confidence_score=0.5,
                extra_field="not_allowed",
            )
        assert [e["loc"] for e in exc_info.value.errors()] == [("extra_field",)]


class TestAdvisorAlertResponse:
    """Tests for AdvisorAlertResponse."""

    def test_valid_alert(self):
        """Test creating a valid alert response."""
        alert = AdvisorAlertResponse(
            alert_type="CASHFLOW_MISMATCH",
            message="Bạn đã chi tiêu quá mức tháng này",
            suggested_action="Giảm chi tiêu không cần thiết",
        )
        assert alert.alert_type == "CASHFLOW_MISMATCH"
        assert alert.message == "Bạn đã chi tiêu quá mức tháng này"
        assert alert.suggested_action == "Giảm chi tiêu không cần thiết"

    def test_valid_alert_without_action(self):
        """Test valid alert without suggested_action."""
        alert = AdvisorAlertResponse(
            alert_type="SAFE",
            message="Cảnh báo ngân sách",
        )
        assert alert.suggested_action is None

    def test_empty_message_raises(self):
        """Test empty message raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            AdvisorAlertResponse(
                alert_type="SAFE",
                message="",
            )
        assert [e["loc"] for e in exc_info.value.errors()] == [("message",)]

    def test_message_too_long_raises(self):
        """Test message > 1000 chars raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            AdvisorAlertResponse(
                alert_type="SAFE",
                message="x" * 1001,
            )
        assert [e["loc"] for e in exc_info.value.errors()] == [("message",)]

    def test_suggested_action_too_long_raises(self):
        """Test suggested_action > 1000 chars raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            AdvisorAlertResponse(
                alert_type="SAFE",
                message="Test",
                suggested_action="x" * 1001,
            )
        assert [e["loc"] for e in exc_info.value.errors()] == [("suggested_action",)]

    def test_extra_fields_forbidden(self):
        """Test extra fields are forbidden."""
        with pytest.raises(ValidationError) as exc_info:
            AdvisorAlertResponse(
                alert_type="SAFE",
                message="Test",
                extra_field="not_allowed",
            )
        assert [e["loc"] for e in exc_info.value.errors()] == [("extra_field",)]


class TestReceiptSchema:
    """Tests for legacy ReceiptSchema."""

    def test_valid_receipt_schema(self):
        """Test creating a valid legacy receipt schema."""
        receipt = ReceiptSchema(
            merchant="Test Shop",
            total=Decimal("50000"),
            currency="VND",
            issued_on=date(2024, 1, 15),
        )
        assert receipt.merchant == "Test Shop"
        assert receipt.total == Decimal("50000")
        assert receipt.currency == "VND"
        assert receipt.issued_on == date(2024, 1, 15)

    def test_valid_receipt_schema_minimal(self):
        """Test minimal valid receipt schema."""
        receipt = ReceiptSchema(
            merchant="Test",
            total=Decimal("10000"),
        )
        assert receipt.merchant == "Test"
        assert receipt.total == Decimal("10000")
        assert receipt.currency == "VND"
        assert receipt.issued_on is None

    def test_negative_total_raises(self):
        """Test negative total raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptSchema(merchant="Test", total=Decimal("-100"))
        assert [e["loc"] for e in exc_info.value.errors()] == [("total",)]

    def test_currency_length(self):
        """Test currency must be 3 characters."""
        with pytest.raises(ValidationError) as exc_info:
            ReceiptSchema(merchant="Test", total=Decimal("100"), currency="VN")
        assert [e["loc"] for e in exc_info.value.errors()] == [("currency",)]
        with pytest.raises(ValidationError) as exc_info:
            ReceiptSchema(merchant="Test", total=Decimal("100"), currency="VNDD")
        assert [e["loc"] for e in exc_info.value.errors()] == [("currency",)]

    def test_to_domain(self):
        """Test conversion to domain ReceiptData."""
        receipt = ReceiptSchema(
            merchant="Legacy Shop",
            total=Decimal("25000"),
            currency="VND",
            issued_on=date(2024, 6, 20),
        )
        domain = receipt.to_domain()
        assert domain.merchant == "Legacy Shop"
        assert domain.total == Decimal("25000")
        assert domain.currency == "VND"
        assert domain.issued_on == date(2024, 6, 20)


class TestReceiptJsonSchema:
    """Tests for receipt_json_schema function."""

    def test_returns_dict(self):
        """Test receipt_json_schema returns a dictionary."""
        schema = receipt_json_schema()
        assert isinstance(schema, dict)

    def test_contains_required_fields(self):
        """Test schema contains required fields."""
        schema = receipt_json_schema()
        assert "properties" in schema
        assert "merchant_name" in schema["properties"]
        assert "items" in schema["properties"]
        assert "total_amount" in schema["properties"]
        assert "category" in schema["properties"]
        assert "confidence_score" in schema["properties"]

    def test_category_enum_in_schema(self):
        """Test category enum is in schema."""
        schema = receipt_json_schema()
        category_prop = schema["properties"]["category"]
        assert "enum" in category_prop
        assert "Ăn uống" in category_prop["enum"]
        assert "Đi lại" in category_prop["enum"]
        assert "Mua sắm" in category_prop["enum"]
        assert "Hóa đơn/Nhà ở" in category_prop["enum"]
        assert "Y tế" in category_prop["enum"]
        assert "Khác" in category_prop["enum"]
