"""Tests for SupabaseManagementRepository."""

from decimal import Decimal
from unittest.mock import Mock, patch

import pytest
from postgrest.exceptions import APIError

from app.domain.transactions import TransactionError
from app.infrastructure.repositories.management import SupabaseManagementRepository


class TestSupabaseManagementRepository:
    """Tests for SupabaseManagementRepository."""

    def setup_method(self):
        self.mock_client = Mock()
        self.user_id = "test_user_123"
        self.repo = SupabaseManagementRepository(self.mock_client, self.user_id)

    # Test query method
    def test_query_profile(self):
        """Test query for profile resource."""
        mock_table = Mock()
        mock_query = Mock()
        mock_table.select.return_value = mock_query
        self.mock_client.table.return_value = mock_table

        self.repo.query("profile")

        self.mock_client.table.assert_called_once_with("profiles")
        mock_table.select.assert_called_once()
        # Should scope to user_id
        mock_query.eq.assert_called_once_with("id", self.user_id)

    def test_query_ai_chat_messages(self):
        """Test query for ai_chat_messages includes session join."""
        mock_table = Mock()
        mock_query = Mock()
        mock_table.select.return_value = mock_query
        self.mock_client.table.return_value = mock_table

        self.repo.query("ai_chat_messages")

        self.mock_client.table.assert_called_once_with("ai_chat_messages")
        # Should select with join
        mock_table.select.assert_called_with(
            "*,ai_chat_sessions!inner(user_id)",
            count=None,
        )

    def test_query_transaction_tags(self):
        """Test query for transaction_tags includes transaction join."""
        mock_table = Mock()
        mock_query = Mock()
        mock_table.select.return_value = mock_query
        self.mock_client.table.return_value = mock_table

        self.repo.query("transaction_tags")

        self.mock_client.table.assert_called_once_with("transaction_tags")
        mock_table.select.assert_called_with(
            "*,transactions!inner(user_id)",
            count=None,
        )

    def test_query_with_count(self):
        """Test query with count=True."""
        mock_table = Mock()
        mock_query = Mock()
        mock_table.select.return_value = mock_query
        self.mock_client.table.return_value = mock_table

        self.repo.query("accounts", count=True)

        mock_table.select.assert_called_with(
            "*",
            count="exact",
        )

    def test_query_write_mode(self):
        """Test query with write=True."""
        mock_table = Mock()
        mock_query = Mock()
        mock_table.select.return_value = mock_query
        self.mock_client.table.return_value = mock_table

        self.repo.query("categories", write=True)

        mock_query.eq.assert_called_once_with("user_id", self.user_id)
        mock_query.or_.assert_not_called()

    # Test scope method
    def test_scope_profile(self):
        """Test scope for profile."""
        mock_query = Mock()
        self.repo.scope(mock_query, "profile")
        mock_query.eq.assert_called_with("id", self.user_id)

    def test_scope_categories_read(self):
        """Test scope for categories read mode (includes system categories)."""
        mock_query = Mock()
        self.repo.scope(mock_query, "categories", write=False)
        mock_query.or_.assert_called_with(f"user_id.is.null,user_id.eq.{self.user_id}")

    def test_scope_categories_write(self):
        """Test scope for categories write mode (user only)."""
        mock_query = Mock()
        self.repo.scope(mock_query, "categories", write=True)
        mock_query.eq.assert_called_with("user_id", self.user_id)

    def test_scope_ai_chat_messages(self):
        """Test scope for ai_chat_messages."""
        mock_query = Mock()
        self.repo.scope(mock_query, "ai_chat_messages")
        mock_query.eq.assert_called_with("ai_chat_sessions.user_id", self.user_id)

    def test_scope_transaction_tags(self):
        """Test scope for transaction_tags."""
        mock_query = Mock()
        self.repo.scope(mock_query, "transaction_tags")
        mock_query.eq.assert_called_with("transactions.user_id", self.user_id)

    def test_scope_default(self):
        """Test scope for default resources."""
        mock_query = Mock()
        self.repo.scope(mock_query, "accounts")
        mock_query.eq.assert_called_with("user_id", self.user_id)

    # Test identify method
    def test_identify_profile(self):
        """Test identify for profile returns query unchanged."""
        mock_query = Mock()
        result = self.repo.identify(mock_query, "profile", "me")
        assert result == mock_query

    def test_identify_transaction_tags(self):
        """Test identify for transaction_tags splits key."""
        mock_query = Mock()
        mock_query.eq.return_value = mock_query
        self.repo.identify(mock_query, "transaction_tags", "123:456")
        mock_query.eq.assert_any_call("transaction_id", 123)
        mock_query.eq.assert_any_call("tag_id", 456)

    def test_identify_default(self):
        """Test identify for default resources."""
        mock_query = Mock()
        mock_query.eq.return_value = mock_query
        self.repo.identify(mock_query, "accounts", "123")
        mock_query.eq.assert_called_with("id", 123)

    # Test list method
    def test_list_success(self):
        """Test list returns paginated results."""
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = [{"id": 1}, {"id": 2}]
        mock_result.count = 10
        # Set up method chaining: order() -> range() -> execute()
        mock_query.order.return_value = mock_query
        mock_query.range.return_value = mock_query
        mock_query.execute.return_value = mock_result

        self.repo.query = Mock(return_value=mock_query)
        self.repo.identify = Mock(return_value=mock_query)

        result = self.repo.list("accounts", limit=10, offset=0)

        assert result["items"] == [{"id": 1}, {"id": 2}]
        assert result["total"] == 10
        assert result["limit"] == 10
        assert result["offset"] == 0
        mock_query.order.assert_called_with("id", desc=True)
        mock_query.range.assert_called_with(0, 9)

    def test_list_transaction_tags_orders_by_both(self):
        """Test list for transaction_tags orders by both transaction_id and tag_id."""
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = []
        mock_result.count = 0
        # Set up method chaining
        mock_query.order.return_value = mock_query
        mock_query.range.return_value = mock_query
        mock_query.execute.return_value = mock_result

        self.repo.query = Mock(return_value=mock_query)
        self.repo.identify = Mock(return_value=mock_query)

        self.repo.list("transaction_tags", limit=10, offset=0)

        mock_query.order.assert_any_call("transaction_id", desc=True)
        mock_query.order.assert_any_call("tag_id", desc=True)

    def test_list_api_error_pgrst103_at_offset_zero_raises(self):
        """Test list raises APIError for PGRST103 at offset 0."""
        mock_query = Mock()
        error = APIError({"code": "PGRST103", "message": "Out of range"})
        # Set up method chaining
        mock_query.order.return_value = mock_query
        mock_query.range.return_value = mock_query
        mock_query.execute.side_effect = error

        self.repo.query = Mock(return_value=mock_query)
        self.repo.identify = Mock(return_value=mock_query)

        with pytest.raises(APIError):
            self.repo.list("accounts", limit=10, offset=0)

    def test_list_api_error_pgrst103_beyond_end_returns_empty(self):
        """Test list returns empty for PGRST103 beyond end."""
        mock_query = Mock()
        error = APIError({"code": "PGRST103", "message": "Out of range"})
        # Set up method chaining
        mock_query.order.return_value = mock_query
        mock_query.range.return_value = mock_query
        # First call raises PGRST103, second call returns count result
        mock_count_result = Mock()
        mock_count_result.count = 5
        mock_count_result.data = []
        mock_query.execute.side_effect = [error, mock_count_result]
        mock_query.limit.return_value = mock_query

        self.repo.query = Mock(return_value=mock_query)
        self.repo.identify = Mock(return_value=mock_query)

        result = self.repo.list("accounts", limit=10, offset=100)

        assert result["items"] == []
        assert result["total"] == 5

    def test_list_other_api_error_raises(self):
        """Test list raises for other API errors."""
        mock_query = Mock()
        error = APIError({"code": "OTHER", "message": "Error"})
        # Set up method chaining
        mock_query.order.return_value = mock_query
        mock_query.range.return_value = mock_query
        mock_query.execute.side_effect = error

        self.repo.query = Mock(return_value=mock_query)
        self.repo.identify = Mock(return_value=mock_query)

        with pytest.raises(APIError):
            self.repo.list("accounts", limit=10, offset=0)

    # Test get method
    def test_get_success(self):
        """Test get returns record."""
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = [{"id": 1, "name": "Test"}]
        mock_query.execute.return_value = mock_result

        self.repo.query = Mock(return_value=mock_query)
        self.repo.identify = Mock(return_value=mock_query)

        result = self.repo.get("accounts", "1")

        assert result == {"id": 1, "name": "Test"}

    def test_get_profile_includes_balance(self):
        """Test get for profile includes current_balance."""
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = [{"id": "test_user_123", "full_name": "Test"}]
        mock_query.execute.return_value = mock_result

        self.repo.query = Mock(return_value=mock_query)
        self.repo.identify = Mock(return_value=mock_query)

        with patch(
            "app.infrastructure.repositories.management.included_account_total"
        ) as mock_total:
            mock_total.return_value = Decimal("1000000")
            result = self.repo.get("profile", "me")

        assert result["current_balance"] == Decimal("1000000")

    def test_get_not_found_raises(self):
        """Test get raises TransactionError when not found."""
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = []
        mock_query.execute.return_value = mock_result

        self.repo.query = Mock(return_value=mock_query)
        self.repo.identify = Mock(return_value=mock_query)

        with pytest.raises(TransactionError) as exc_info:
            self.repo.get("accounts", "999")
        assert exc_info.value.status == 404
        assert "Record not found" in str(exc_info.value)

    # Test create method
    def test_create_success(self):
        """Test create inserts record with user_id."""
        mock_table = Mock()
        mock_result = Mock()
        mock_result.data = [{"id": 1, "name": "Test", "user_id": self.user_id}]
        mock_table.insert.return_value.execute.return_value = mock_result
        self.mock_client.table.return_value = mock_table

        result = self.repo.create("accounts", {"name": "Test"})

        assert result == {"id": 1, "name": "Test", "user_id": self.user_id}
        self.mock_client.table.assert_called_with("accounts")
        # Check user_id was added
        insert_call = mock_table.insert.call_args[0][0]
        assert insert_call["user_id"] == self.user_id

    def test_create_ai_chat_messages_no_user_id(self):
        """Test create for ai_chat_messages doesn't add user_id."""
        mock_table = Mock()
        mock_result = Mock()
        mock_result.data = [{"id": 1, "session_id": 1}]
        mock_table.insert.return_value.execute.return_value = mock_result
        self.mock_client.table.return_value = mock_table

        result = self.repo.create(
            "ai_chat_messages", {"session_id": 1, "content": "Test"}
        )

        assert result == {"id": 1, "session_id": 1}
        insert_call = mock_table.insert.call_args[0][0]
        assert "user_id" not in insert_call

    def test_create_transaction_tags_no_user_id(self):
        """Test create for transaction_tags doesn't add user_id."""
        mock_table = Mock()
        mock_result = Mock()
        mock_result.data = [{"id": 1, "transaction_id": 1, "tag_id": 2}]
        mock_table.insert.return_value.execute.return_value = mock_result
        self.mock_client.table.return_value = mock_table

        result = self.repo.create(
            "transaction_tags", {"transaction_id": 1, "tag_id": 2}
        )

        assert result == {"id": 1, "transaction_id": 1, "tag_id": 2}
        insert_call = mock_table.insert.call_args[0][0]
        assert "user_id" not in insert_call

    def test_create_empty_result_raises(self):
        """Test create raises when result is empty."""
        mock_table = Mock()
        mock_result = Mock()
        mock_result.data = []
        mock_table.insert.return_value.execute.return_value = mock_result
        self.mock_client.table.return_value = mock_table

        with pytest.raises(TransactionError) as exc_info:
            self.repo.create("accounts", {"name": "Test"})
        assert exc_info.value.status == 409
        assert "Unable to create record" in str(exc_info.value)

    # Test record_wallet_initial_income
    def test_record_wallet_initial_income_success(self):
        """Test record_wallet_initial_income calls RPC."""
        mock_result = Mock()
        mock_result.data = {"id": 1}
        self.mock_client.rpc.return_value.execute.return_value = mock_result

        result = self.repo.record_wallet_initial_income(
            {"expected_balance": "100000"}, "request_123", 1
        )

        assert result == {"id": 1}
        self.mock_client.rpc.assert_called_with(
            "record_wallet_initial_income",
            {
                "p_account": {"expected_balance": "100000"},
                "p_request_id": "request_123",
                "p_existing_account_id": 1,
            },
        )

    def test_record_wallet_initial_income_pgrst202_raises(self):
        """Test record_wallet_initial_income raises for PGRST202."""
        error = APIError({"code": "PGRST202", "message": "Function not found"})
        self.mock_client.rpc.return_value.execute.side_effect = error

        with pytest.raises(TransactionError) as exc_info:
            self.repo.record_wallet_initial_income({}, "request_123")
        assert exc_info.value.status == 503
        assert "Chưa cập nhật chức năng thu nhập ví" in str(exc_info.value)

    def test_record_wallet_initial_income_constraint_error_raises(self):
        """Test record_wallet_initial_income raises for constraint errors."""
        for code in ["23514", "22023", "P0001", "42501"]:
            error = APIError({"code": code, "message": "Constraint violation"})
            self.mock_client.rpc.return_value.execute.side_effect = error

            with pytest.raises(TransactionError) as exc_info:
                self.repo.record_wallet_initial_income({}, "request_123")
            assert exc_info.value.status == 422

    def test_record_wallet_initial_income_other_error_raises(self):
        """Test record_wallet_initial_income raises for other errors."""
        error = APIError({"code": "OTHER", "message": "Error"})
        self.mock_client.rpc.return_value.execute.side_effect = error

        with pytest.raises(APIError):
            self.repo.record_wallet_initial_income({}, "request_123")

    # Test mutation method
    def test_mutation_update(self):
        """Test mutation for update."""
        mock_table = Mock()
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = [{"id": 1, "name": "Updated"}]
        mock_query.execute.return_value = mock_result
        mock_table.update.return_value = mock_query
        self.mock_client.table.return_value = mock_table

        self.repo.scope = Mock(return_value=mock_query)
        self.repo.identify = Mock(return_value=mock_query)

        result = self.repo.mutation("accounts", "1", {"name": "Updated"})

        assert result == {"id": 1, "name": "Updated"}
        self.mock_client.table.assert_called_with("accounts")
        mock_table.update.assert_called_with({"name": "Updated"})

    def test_mutation_delete(self):
        """Test mutation for delete."""
        mock_table = Mock()
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = [{"id": 1}]
        mock_query.execute.return_value = mock_result
        mock_table.delete.return_value = mock_query
        self.mock_client.table.return_value = mock_table

        self.repo.scope = Mock(return_value=mock_query)
        self.repo.identify = Mock(return_value=mock_query)

        result = self.repo.mutation("accounts", "1", None)

        assert result == {"id": 1}
        mock_table.delete.assert_called_once()

    def test_mutation_ai_chat_messages_no_scope(self):
        """Test mutation for ai_chat_messages doesn't apply scope."""
        mock_table = Mock()
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = [{"id": 1}]
        mock_query.execute.return_value = mock_result
        mock_table.delete.return_value = mock_query
        self.mock_client.table.return_value = mock_table

        self.repo.identify = Mock(return_value=mock_query)
        mock_scope = Mock(return_value=mock_query)
        self.repo.scope = mock_scope

        self.repo.mutation("ai_chat_messages", "1", None)

        mock_scope.assert_not_called()

    def test_mutation_transaction_tags_no_scope(self):
        """Test mutation for transaction_tags doesn't apply scope."""
        mock_table = Mock()
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = [{"id": 1}]
        mock_query.execute.return_value = mock_result
        mock_table.delete.return_value = mock_query
        self.mock_client.table.return_value = mock_table

        self.repo.identify = Mock(return_value=mock_query)
        mock_scope = Mock(return_value=mock_query)
        self.repo.scope = mock_scope

        self.repo.mutation("transaction_tags", "1:2", None)

        mock_scope.assert_not_called()

    def test_mutation_not_found_raises(self):
        """Test mutation raises when record not found."""
        mock_table = Mock()
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = []
        mock_query.execute.return_value = mock_result
        mock_table.delete.return_value = mock_query
        self.mock_client.table.return_value = mock_table

        self.repo.scope = Mock(return_value=mock_query)
        self.repo.identify = Mock(return_value=mock_query)

        with pytest.raises(TransactionError) as exc_info:
            self.repo.mutation("accounts", "999", None)
        assert exc_info.value.status == 404

    # Test update and delete methods
    def test_update_calls_mutation(self):
        """Test update calls mutation."""
        self.repo.mutation = Mock(return_value={"id": 1})
        self.repo.update("accounts", "1", {"name": "New"})
        self.repo.mutation.assert_called_once_with("accounts", "1", {"name": "New"})

    def test_delete_calls_mutation(self):
        """Test delete calls mutation with None."""
        self.repo.mutation = Mock()
        self.repo.delete("accounts", "1")
        self.repo.mutation.assert_called_once_with("accounts", "1", None)

    # Test referenced method
    def test_referenced_true(self):
        """Test referenced returns True when record exists."""
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = [{"id": 1}]
        # Set up method chaining: eq() -> limit() -> execute()
        mock_query.eq.return_value = mock_query
        mock_query.limit.return_value = mock_query
        mock_query.execute.return_value = mock_result

        self.repo.query = Mock(return_value=mock_query)

        result = self.repo.referenced("transactions", "account_id", 1)

        assert result is True
        mock_query.eq.assert_called_with("account_id", 1)
        mock_query.limit.assert_called_with(1)

    def test_referenced_false(self):
        """Test referenced returns False when no record exists."""
        mock_query = Mock()
        mock_result = Mock()
        mock_result.data = []
        # Set up method chaining: eq() -> limit() -> execute()
        mock_query.eq.return_value = mock_query
        mock_query.limit.return_value = mock_query
        mock_query.execute.return_value = mock_result

        self.repo.query = Mock(return_value=mock_query)

        result = self.repo.referenced("transactions", "account_id", 999)

        assert result is False
