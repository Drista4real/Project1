"""Tests for ManagementService."""

from datetime import date
from unittest.mock import Mock

import pytest
from pydantic import ValidationError

from app.application.management import ManagementService
from app.domain.management import (
    AccountInput,
)
from app.domain.transactions import TransactionError


class TestManagementService:
    """Tests for ManagementService."""

    def setup_method(self):
        self.mock_repository = Mock()
        self.mock_repository.user_id = "test_user_123"
        self.service = ManagementService(repository=self.mock_repository)

    # Test require method
    def test_require_valid_resource(self):
        """Test require returns model for valid resource."""
        model = self.service.require("accounts")
        assert model == AccountInput

    def test_require_invalid_resource_raises(self):
        """Test require raises TransactionError for invalid resource."""
        with pytest.raises(TransactionError) as exc_info:
            self.service.require("invalid_resource")
        assert exc_info.value.status == 404
        assert "Unknown resource" in str(exc_info.value)

    # Test check_key method
    def test_check_key_profile_valid(self):
        """Test check_key for profile with valid key."""
        self.service.check_key("profile", "me")  # Should not raise

    def test_check_key_profile_invalid_raises(self):
        """Test check_key for profile with invalid key raises."""
        with pytest.raises(TransactionError) as exc_info:
            self.service.check_key("profile", "not_me")
        assert exc_info.value.status == 404
        assert "Record not found" in str(exc_info.value)

    def test_check_key_transaction_tags_valid(self):
        """Test check_key for transaction_tags with valid format."""
        self.service.check_key("transaction_tags", "123:456")  # Should not raise

    def test_check_key_transaction_tags_invalid_format_raises(self):
        """Test check_key for transaction_tags with invalid format raises."""
        with pytest.raises(TransactionError) as exc_info:
            self.service.check_key("transaction_tags", "123")
        assert exc_info.value.status == 422
        assert "Invalid record identifier" in str(exc_info.value)

        with pytest.raises(TransactionError):
            self.service.check_key("transaction_tags", "123:456:789")

    def test_check_key_other_resources_valid(self):
        """Test check_key for other resources with valid numeric ID."""
        self.service.check_key("accounts", "123")  # Should not raise
        self.service.check_key("categories", "456")  # Should not raise

    def test_check_key_other_resources_invalid_format_raises(self):
        """Test check_key for other resources with invalid format raises."""
        with pytest.raises(TransactionError) as exc_info:
            self.service.check_key("accounts", "abc")
        assert exc_info.value.status == 422
        assert "Invalid record identifier" in str(exc_info.value)

    def test_check_key_non_ascii_raises(self):
        """Test check_key with non-ASCII characters raises."""
        with pytest.raises(TransactionError) as exc_info:
            self.service.check_key("accounts", "１２３")  # Full-width digits
        assert exc_info.value.status == 422

    def test_check_key_zero_or_negative_raises(self):
        """Test check_key with zero or negative ID raises."""
        with pytest.raises(TransactionError):
            self.service.check_key("accounts", "0")
        with pytest.raises(TransactionError):
            self.service.check_key("accounts", "-1")

    def test_check_key_too_large_raises(self):
        """Test check_key with too large ID raises."""
        with pytest.raises(TransactionError):
            self.service.check_key("accounts", "9223372036854775808")  # > max int64

    # Test writable method
    def test_writable_system_category_raises(self):
        """Test writable raises for system category (user_id is None)."""
        record = {"user_id": None}
        with pytest.raises(TransactionError) as exc_info:
            self.service.writable("categories", record)
        assert exc_info.value.status == 403
        assert "Danh mục hệ thống chỉ được xem" in str(exc_info.value)

    def test_writable_user_category_allows(self):
        """Test writable allows user's own category."""
        record = {"user_id": "test_user_123"}
        self.service.writable("categories", record)  # Should not raise

    def test_writable_other_users_category_raises(self):
        """Test writable raises for other user's category."""
        record = {"user_id": "other_user"}
        with pytest.raises(TransactionError) as exc_info:
            self.service.writable("categories", record)
        assert exc_info.value.status == 403

    def test_writable_non_category_allows(self):
        """Test writable allows non-category resources."""
        record = {"user_id": "other_user"}
        self.service.writable("accounts", record)  # Should not raise

    # Test validate method
    def test_validate_valid_data(self):
        """Test validate returns validated data for valid input."""
        data = {
            "name": "Test Account",
            "account_type": "cash",
            "balance": "0",
            "currency": "VND",
        }
        result = self.service.validate("accounts", data)
        assert result["name"] == "Test Account"
        assert result["account_type"] == "cash"

    def test_validate_invalid_data_raises(self):
        """Test validate raises TransactionError for invalid data."""
        data = {"name": "", "account_type": "invalid"}  # Empty name, invalid type
        with pytest.raises(TransactionError) as exc_info:
            self.service.validate("accounts", data)
        assert exc_info.value.status == 422

    def test_validate_invalid_reference_raises(self):
        """Test validate raises for invalid reference."""

        # Mock get to raise TransactionError for category reference check
        # get is called with (resource, key) - we only raise for categories reference
        def mock_get(resource, key):
            if resource == "categories":
                raise TransactionError(404, "Not found")
            return {}

        self.mock_repository.get.side_effect = mock_get
        # Use recurring_transactions which has category_id reference and is in RESOURCES
        data = {
            "amount": "100000",
            "transaction_type": "expense",
            "category_id": 999,
            "description": "Test",
            "frequency": "monthly",
            "start_date": date(2024, 1, 1),
            "next_execution_date": date(2024, 2, 1),
        }
        with pytest.raises(TransactionError) as exc_info:
            self.service.validate("recurring_transactions", data)
        assert exc_info.value.status == 422
        assert "dữ liệu không tồn tại hoặc không thuộc về bạn" in str(exc_info.value)

    def test_validate_archived_account_reference_raises(self):
        """Test validate raises when referencing archived account."""

        # get is called with (resource, key) - return archived account for accounts
        # reference
        def mock_get(resource, key):
            if resource == "accounts":
                return {"is_archived": True}
            return {}

        self.mock_repository.get.side_effect = mock_get
        # Use recurring_transactions which has account_id reference
        data = {
            "amount": "100000",
            "transaction_type": "expense",
            "account_id": 123,
            "description": "Test",
            "frequency": "monthly",
            "start_date": date(2024, 1, 1),
            "next_execution_date": date(2024, 2, 1),
        }
        with pytest.raises(TransactionError) as exc_info:
            self.service.validate("recurring_transactions", data)
        assert exc_info.value.status == 422
        assert "Vui lòng chọn ví chưa lưu trữ" in str(exc_info.value)

    def test_validate_archived_account_unchanged_allows(self):
        """Test validate allows unchanged archived account reference."""
        # First call (reference check): returns archived account
        # Second call (current record): returns same account_id
        calls = [
            {"is_archived": True},  # First call for reference check (accounts)
            {
                "account_id": 123
            },  # Second call for current record (recurring_transactions)
        ]

        def mock_get(resource, key):
            return calls.pop(0)

        self.mock_repository.get.side_effect = mock_get
        # Use recurring_transactions which has account_id reference
        data = {
            "amount": "100000",
            "transaction_type": "expense",
            "account_id": 123,
            "description": "Test",
            "frequency": "monthly",
            "start_date": date(2024, 1, 1),
            "next_execution_date": date(2024, 2, 1),
        }
        result = self.service.validate("recurring_transactions", data, key="456")
        assert result["account_id"] == 123

    def test_validate_category_income_mismatch_raises(self):
        """Test validate raises for category income/expense mismatch."""
        self.mock_repository.get.return_value = {"is_income": True}  # Income category
        data = {
            "name": "Test",
            "is_income": False,
            "parent_id": 123,
        }  # Expense category
        with pytest.raises(TransactionError) as exc_info:
            self.service.validate("categories", data)
        assert exc_info.value.status == 422
        assert "Danh mục phải khớp loại thu nhập hoặc chi tiêu" in str(exc_info.value)

    def test_validate_category_parent_loop_raises(self):
        """Test validate raises for category parent loop."""

        # Parent chain: 1 -> 2 -> 1 (loop)
        # get is called with (resource, key)
        def get_category(resource, key):
            if key == "1":
                return {"parent_id": 2, "is_income": False}
            elif key == "2":
                return {"parent_id": 1, "is_income": False}
            return {"is_income": False}

        self.mock_repository.get.side_effect = get_category

        data = {"name": "Test", "is_income": False, "parent_id": 1}
        with pytest.raises(TransactionError) as exc_info:
            self.service.validate("categories", data, key="1")
        assert exc_info.value.status == 422
        assert "Danh mục cha tạo thành vòng lặp" in str(exc_info.value)

    def test_validate_category_deep_parent_chain(self):
        """Test validate handles deep parent chain."""

        def get_category(resource, key):
            chain = {
                "3": {"parent_id": 2, "is_income": False},
                "2": {"parent_id": 1, "is_income": False},
                "1": {"parent_id": None, "is_income": False},
            }
            return chain.get(key, {"is_income": False})

        self.mock_repository.get.side_effect = get_category

        data = {"name": "Test", "is_income": False, "parent_id": 3}
        result = self.service.validate("categories", data)
        assert result["parent_id"] == 3

    # Test create method
    def test_create_profile_raises(self):
        """Test create raises for profile resource."""
        with pytest.raises(TransactionError) as exc_info:
            self.service.create("profile", {})
        assert exc_info.value.status == 405
        assert "Profiles are created by authentication" in str(exc_info.value)

    def test_create_account_with_initial_income(self):
        """Test create account with record_initial_income=True."""
        account_data = {
            "name": "Test Wallet",
            "account_type": "cash",
            "balance": "100000",
            "currency": "VND",
            "record_initial_income": True,
            "client_request_id": "a" * 32,
        }
        self.mock_repository.record_wallet_initial_income.return_value = {"id": 1}
        result = self.service.create("accounts", account_data)
        assert result == {"id": 1}
        self.mock_repository.record_wallet_initial_income.assert_called_once()

    def test_create_account_without_initial_income(self):
        """Test create account without initial income."""
        account_data = {
            "name": "Test Wallet",
            "account_type": "cash",
            "balance": "0",
            "currency": "VND",
        }
        self.mock_repository.create.return_value = {"id": 1}
        result = self.service.create("accounts", account_data)
        assert result == {"id": 1}
        self.mock_repository.create.assert_called_once()

    def test_create_account_initial_income_validation_fails(self):
        """Test create account fails validation for initial income."""
        account_data = {
            "name": "Test Wallet",
            "account_type": "cash",
            "balance": "0",  # Balance must be > 0 for initial income
            "currency": "VND",
            "record_initial_income": True,
            "client_request_id": "a" * 32,
        }
        with pytest.raises(ValidationError) as exc_info:
            self.service.create("accounts", account_data)
        assert "Thu nhập ban đầu phải lớn hơn 0" in str(exc_info.value)

    def test_create_other_resource(self):
        """Test create for other resources."""
        data = {"name": "Test Category", "is_income": False}
        self.mock_repository.create.return_value = {"id": 1}
        result = self.service.create("categories", data)
        assert result == {"id": 1}
        self.mock_repository.create.assert_called_once()
        # Verify create was called with validated data
        call_args = self.mock_repository.create.call_args[0]
        assert call_args[0] == "categories"
        assert call_args[1]["name"] == "Test Category"
        assert call_args[1]["is_income"] is False

    # Test record_wallet_initial_income
    def test_record_wallet_initial_income(self):
        """Test record_wallet_initial_income delegates to repository."""
        self.mock_repository.record_wallet_initial_income.return_value = {"id": 1}
        result = self.service.record_wallet_initial_income("123", "request_123", 50000)
        assert result == {"id": 1}
        self.mock_repository.record_wallet_initial_income.assert_called_once_with(
            {"expected_balance": "50000"}, "request_123", 123
        )

    # Test update method
    def test_update_valid(self):
        """Test update with valid patch."""
        # Return complete account data with all required fields
        self.mock_repository.get.return_value = {
            "id": 1,
            "name": "Old",
            "user_id": "test_user_123",
            "account_type": "cash",
            "balance": "0",
            "currency": "VND",
        }
        self.mock_repository.update.return_value = {"id": 1, "name": "New"}
        result = self.service.update("accounts", "1", {"name": "New"})
        assert result["name"] == "New"

    def test_update_invalid_resource_raises(self):
        """Test update with invalid resource raises."""
        with pytest.raises(TransactionError) as exc_info:
            self.service.update("invalid", "1", {"name": "New"})
        assert exc_info.value.status == 404

    def test_update_nonexistent_key_raises(self):
        """Test update with nonexistent key raises."""
        self.mock_repository.get.side_effect = TransactionError(404, "Not found")
        with pytest.raises(TransactionError) as exc_info:
            self.service.update("accounts", "999", {"name": "New"})
        assert exc_info.value.status == 404

    def test_update_system_category_raises(self):
        """Test update system category raises."""
        self.mock_repository.get.return_value = {"user_id": None}
        with pytest.raises(TransactionError) as exc_info:
            self.service.update("categories", "1", {"name": "New"})
        assert exc_info.value.status == 403

    def test_update_invalid_fields_raises(self):
        """Test update with invalid fields raises."""
        self.mock_repository.get.return_value = {
            "id": 1,
            "name": "Old",
            "user_id": "test_user_123",
            "account_type": "cash",
            "balance": "0",
            "currency": "VND",
        }
        with pytest.raises(TransactionError) as exc_info:
            self.service.update("accounts", "1", {"invalid_field": "value"})
        assert exc_info.value.status == 422
        assert "Supply editable fields only" in str(exc_info.value)

    def test_update_empty_patch_raises(self):
        """Test update with empty patch raises."""
        self.mock_repository.get.return_value = {
            "id": 1,
            "name": "Old",
            "user_id": "test_user_123",
            "account_type": "cash",
            "balance": "0",
            "currency": "VND",
        }
        with pytest.raises(TransactionError) as exc_info:
            self.service.update("accounts", "1", {})
        assert exc_info.value.status == 422

    def test_update_category_income_type_change_blocked_when_referenced(self):
        """Test update category income type change blocked when referenced."""
        # Return complete category data with all required fields
        self.mock_repository.get.return_value = {
            "id": 1,
            "is_income": False,
            "user_id": "test_user_123",
            "name": "Test Category",
        }
        self.mock_repository.referenced.return_value = True
        with pytest.raises(TransactionError) as exc_info:
            self.service.update("categories", "1", {"is_income": True})
        assert exc_info.value.status == 409
        assert "Danh mục đang được sử dụng" in str(exc_info.value)

    def test_update_category_income_type_change_allowed_when_not_referenced(self):
        """Test update category income type change allowed when not referenced."""
        self.mock_repository.get.return_value = {
            "id": 1,
            "is_income": False,
            "user_id": "test_user_123",
            "name": "Test Category",
        }
        self.mock_repository.referenced.return_value = False
        self.mock_repository.update.return_value = {"id": 1, "is_income": True}
        result = self.service.update("categories", "1", {"is_income": True})
        assert result["is_income"] is True

    # Test delete method
    def test_delete_valid(self):
        """Test delete valid resource."""
        self.mock_repository.get.return_value = {"id": 1, "user_id": "test_user_123"}
        self.mock_repository.referenced.return_value = False
        self.service.delete("accounts", "1")
        self.mock_repository.delete.assert_called_once_with("accounts", "1")

    def test_delete_profile_raises(self):
        """Test delete profile raises."""
        with pytest.raises(TransactionError) as exc_info:
            self.service.delete("profile", "me")
        assert exc_info.value.status == 405
        assert "Profile lifecycle is managed by authentication" in str(exc_info.value)

    def test_delete_system_category_raises(self):
        """Test delete system category raises."""
        self.mock_repository.get.return_value = {"user_id": None}
        with pytest.raises(TransactionError) as exc_info:
            self.service.delete("categories", "1")
        assert exc_info.value.status == 403

    def test_delete_referenced_account_raises(self):
        """Test delete referenced account raises."""
        self.mock_repository.get.return_value = {"id": 1, "user_id": "test_user_123"}
        self.mock_repository.referenced.return_value = True
        with pytest.raises(TransactionError) as exc_info:
            self.service.delete("accounts", "1")
        assert exc_info.value.status == 409
        assert "Dữ liệu đang được sử dụng" in str(exc_info.value)

    def test_delete_referenced_category_raises(self):
        """Test delete referenced category raises."""
        self.mock_repository.get.return_value = {"id": 1, "user_id": "test_user_123"}
        self.mock_repository.referenced.return_value = True
        with pytest.raises(TransactionError) as exc_info:
            self.service.delete("categories", "1")
        assert exc_info.value.status == 409

    def test_delete_non_referenced_allows(self):
        """Test delete non-referenced resource allows."""
        self.mock_repository.get.return_value = {"id": 1, "user_id": "test_user_123"}
        self.mock_repository.referenced.return_value = False
        self.service.delete("tags", "1")
        self.mock_repository.delete.assert_called_once_with("tags", "1")


class TestManagementServiceEdgeCases:
    """Edge case tests for ManagementService."""

    def setup_method(self):
        self.mock_repository = Mock()
        self.mock_repository.user_id = "test_user_123"
        self.service = ManagementService(repository=self.mock_repository)

    def test_validate_budget_month_year_day_not_first(self):
        """Test validate rejects budget with month_year not on first day."""
        data = {
            "month_year": date(2024, 1, 15),  # Not first day
            "limit_amount": "1000000",
        }
        with pytest.raises(TransactionError) as exc_info:
            self.service.validate("budgets", data)
        assert exc_info.value.status == 422

    def test_validate_budget_both_category_and_pillar_raises(self):
        """Test validate rejects budget with both category_id and pillar."""
        data = {
            "month_year": date(2024, 1, 1),
            "limit_amount": "1000000",
            "category_id": 1,
            "pillar": "needs",
        }
        with pytest.raises(TransactionError) as exc_info:
            self.service.validate("budgets", data)
        assert exc_info.value.status == 422

    def test_validate_recurring_dates_validation(self):
        """Test validate recurring transaction date constraints."""
        data = {
            "amount": "100000",
            "transaction_type": "expense",
            "description": "Test",
            "frequency": "monthly",
            "start_date": date(2024, 1, 1),
            "next_execution_date": date(2023, 12, 1),  # Before start_date
        }
        with pytest.raises(TransactionError) as exc_info:
            self.service.validate("recurring_transactions", data)
        assert exc_info.value.status == 422

    def test_validate_forecast_bounds(self):
        """Test validate forecast bounds."""
        data = {
            "forecast_date": date(2024, 1, 1),
            "predicted_balance": "1000000",
            "lower_bound": "2000000",
            "upper_bound": "1000000",  # lower > upper
        }
        with pytest.raises(TransactionError) as exc_info:
            self.service.validate("cashflow_forecasts", data)
        assert exc_info.value.status == 422
        assert "Cận dưới không được vượt cận trên" in str(exc_info.value)

    def test_validate_debt_paid_amount_exceeds(self):
        """Test validate debt paid amount exceeds total."""
        data = {
            "type": "debt",
            "person_name": "Test",
            "amount": "100000",
            "paid_amount": "200000",  # Exceeds amount
        }
        with pytest.raises(TransactionError) as exc_info:
            self.service.validate("debts_loans", data)
        assert exc_info.value.status == 422
        assert "Số tiền đã thanh toán vượt quá khoản nợ" in str(exc_info.value)
