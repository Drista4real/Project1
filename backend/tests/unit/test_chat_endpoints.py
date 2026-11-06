"""HTTP-level tests for the chat endpoints.

The endpoints are exercised through the real FastAPI app with the
authentication dependency replaced, so the routing, the response models and
the error mapping are covered without a live Supabase project.
"""

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import UserContext, get_user_context
from app.api.v1.endpoints.chat import get_chat_service
from app.application.chat import ChatService
from app.domain.chat import BudgetSlots, ChatSession
from app.main import app


class FakeChatRepository:
    """An in-memory conversation store."""

    def __init__(self) -> None:
        self.sessions = {1: ChatSession(id=1, title="Test")}
        self.stored: list = []

    def session(self, session_id: int) -> ChatSession:
        return self.sessions[session_id]

    def list_sessions(self, limit: int, offset: int) -> dict:
        return {
            "items": list(self.sessions.values())[offset : offset + limit],
            "total": len(self.sessions),
            "limit": limit,
            "offset": offset,
        }

    def create_session(self, title: str) -> ChatSession:
        session = ChatSession(id=2, title=title)
        self.sessions[2] = session
        return session

    def messages(self, session_id: int, limit: int) -> list:
        return list(self.stored)[-limit:]

    def append_message(
        self,
        session_id: int,
        sender: str,
        content: str,
        tool_name: str | None = None,
        tool_args: dict | None = None,
        tool_result: dict | None = None,
    ):
        from app.domain.chat import ChatMessage

        message = ChatMessage(
            id=len(self.stored) + 1,
            session_id=session_id,
            sender=sender,
            content=content,
            tool_name=tool_name,
            tool_args=tool_args,
            tool_result=tool_result,
        )
        self.stored.append(message)
        return message

    def save_slots(self, session_id: int, slots: BudgetSlots) -> None:
        self.sessions[session_id] = self.sessions[session_id].model_copy(
            update={"slots": slots}
        )


class FakeModel:
    """A scripted model that never reaches the cloud."""

    is_mock = False

    def __init__(self, reply: str = "Chào bạn!") -> None:
        self.reply = reply

    async def complete(self, **kwargs):
        return self.reply, ()


@pytest.fixture
def client(monkeypatch):
    """A test client whose chat service uses the in-memory store."""
    repository = FakeChatRepository()
    model = FakeModel()

    from app.application.chat import ChatService
    from app.application.chat_tools import (
        AskUserQuestionArgs,
        ConfirmRebalanceArgs,
        CreateBudgetPlanArgs,
        SearchNearbySimilarPlacesArgs,
        SimulatePurchaseImpactArgs,
        ToolHandler,
        ToolRegistry,
        ToolSpec,
    )

    async def noop(arguments):
        return {"ok": True}

    registry = ToolRegistry(
        (
            ToolHandler(
                spec=ToolSpec(
                    name="create_budget_plan",
                    description="Create a plan",
                    writes=True,
                    input_model=CreateBudgetPlanArgs,
                ),
                handler=noop,
            ),
            ToolHandler(
                spec=ToolSpec(
                    name="simulate_purchase_impact",
                    description="Simulate a purchase",
                    writes=False,
                    input_model=SimulatePurchaseImpactArgs,
                ),
                handler=noop,
            ),
            ToolHandler(
                spec=ToolSpec(
                    name="search_nearby_similar_places",
                    description="Find similar places",
                    writes=False,
                    input_model=SearchNearbySimilarPlacesArgs,
                ),
                handler=noop,
            ),
            ToolHandler(
                spec=ToolSpec(
                    name="confirm_and_rebalance_budget",
                    description="Confirm a purchase",
                    writes=True,
                    input_model=ConfirmRebalanceArgs,
                ),
                handler=noop,
            ),
            ToolHandler(
                spec=ToolSpec(
                    name="ask_user_question",
                    description="Ask a multiple-choice question",
                    writes=False,
                    input_model=AskUserQuestionArgs,
                ),
                handler=noop,
            ),
        )
    )

    service = ChatService(
        repository=repository,
        registry=registry,
        model=model,
        system_prompt="system",
    )

    async def fake_context():
        yield UserContext(client=None, user_id="user-1")

    def fake_service():
        return service

    app.dependency_overrides[get_user_context] = fake_context
    app.dependency_overrides[get_chat_service] = fake_service
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


class TestChatEndpoints:
    """The five endpoints of the conversational canvas."""

    def test_the_tool_catalog_is_listed(self, client):
        response = client.get("/api/v1/chat/tools")
        assert response.status_code == 200
        assert "assistant_available" in response.json()

    def test_a_session_is_created(self, client):
        response = client.post(
            "/api/v1/chat/sessions", json={"title": "Cuộc trò chuyện"}
        )
        assert response.status_code == 201
        assert response.json()["session"]["id"] == 2

    def test_the_messages_of_a_session_are_listed(self, client):
        response = client.get("/api/v1/chat/sessions/1/messages")
        assert response.status_code == 200
        assert response.json()["items"] == []

    def test_a_turn_answers_the_user(self, client):
        response = client.post(
            "/api/v1/chat/turn",
            json={"session_id": 1, "message": "Xin chào"},
        )
        assert response.status_code == 200
        assert response.json()["turn"]["reply"] == "Chào bạn!"

    def test_an_empty_message_is_refused(self, client):
        response = client.post(
            "/api/v1/chat/turn", json={"session_id": 1, "message": "   "}
        )
        assert response.status_code == 422


class TestQuotaEndpoint:
    """A spent daily allowance reaches the client as a 429."""

    def test_the_quota_failure_is_reported_with_its_own_status(self, client):
        from app.domain.chat import ChatUnavailable

        class QuotaModel:
            is_mock = False

            async def complete(self, **kwargs):
                raise ChatUnavailable(
                    "Trợ lý hội thoại đã hết hạn mức gọi hôm nay. "
                    "Vui lòng thử lại sau hoặc dùng gói có hạn mức cao hơn.",
                    code="quota",
                    status=429,
                )

        original = app.dependency_overrides[get_chat_service]()
        quota_service = ChatService(
            repository=original.repository,
            registry=original.registry,
            model=QuotaModel(),
            system_prompt="system",
        )
        app.dependency_overrides[get_chat_service] = lambda: quota_service

        response = client.post(
            "/api/v1/chat/turn", json={"session_id": 1, "message": "Xin chào"}
        )
        assert response.status_code == 429
        assert "hết hạn mức" in response.json()["detail"]
