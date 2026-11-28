"""HTTP endpoints for the conversational assistant.

The assistant is reached through one endpoint. The client sends a message and
the server owns the session, the slots and the tool calls (ADR 0010).
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field

from app.api.dependencies import UserDependency
from app.application.chat import ChatService
from app.domain.chat import ChatError, ChatMessage, ChatSession, ChatTurn

router = APIRouter(prefix="/api/v1/chat", tags=["Chat"])


class ChatTurnRequest(BaseModel):
    """One user message inside a conversation."""

    model_config = ConfigDict(extra="forbid")

    session_id: int = Field(gt=0)
    message: str = Field(min_length=1, max_length=4000)


class ChatSessionRequest(BaseModel):
    """The body of a new conversation."""

    model_config = ConfigDict(extra="forbid")

    title: str = Field(default="Cuộc trò chuyện tư vấn", max_length=120)


class ChatSessionResponse(BaseModel):
    """A conversation with its collected slots."""

    model_config = ConfigDict(extra="forbid")

    session: ChatSession


class ChatSessionListResponse(BaseModel):
    """A page of conversations."""

    model_config = ConfigDict(extra="forbid")

    items: list[ChatSession]
    total: int
    limit: int
    offset: int


class ChatTurnResponse(BaseModel):
    """The assistant's answer to one message."""

    model_config = ConfigDict(extra="forbid")

    turn: ChatTurn


class ToolDescriptor(BaseModel):
    """One tool the assistant may call."""

    model_config = ConfigDict(extra="forbid")

    name: str
    description: str
    writes: bool


class ToolListResponse(BaseModel):
    """The available tools and whether the assistant can run."""

    model_config = ConfigDict(extra="forbid")

    tools: list[ToolDescriptor]
    assistant_available: bool


class ChatMessageListResponse(BaseModel):
    """The messages of one conversation."""

    model_config = ConfigDict(extra="forbid")

    items: list[ChatMessage]


def get_chat_service(context: UserDependency) -> ChatService:
    """Build the chat service for the authenticated owner."""
    from app.api.v1.chat_tools import build_chat_service

    return build_chat_service(context)


ChatServiceDependency = Annotated[ChatService, Depends(get_chat_service)]


@router.get("/tools", response_model=ToolListResponse)
def list_tools(service: ChatServiceDependency) -> ToolListResponse:
    """List the tools the assistant may call."""
    registry = service.registry
    tools = [
        ToolDescriptor(
            name=name,
            description=registry.description(name),
            writes=registry.writes(name),
        )
        for name in registry.names
    ]
    return ToolListResponse(
        tools=tools,
        assistant_available=service.assistant_available,
    )


@router.get("/sessions", response_model=ChatSessionListResponse)
def list_sessions(
    service: ChatServiceDependency,
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> ChatSessionListResponse:
    """List the conversations owned by the authenticated user."""
    page = service.list_sessions(limit, offset)
    return ChatSessionListResponse(**page)


@router.post("/sessions", response_model=ChatSessionResponse, status_code=201)
def create_session(
    body: ChatSessionRequest, service: ChatServiceDependency
) -> ChatSessionResponse:
    """Start a new conversation."""
    return ChatSessionResponse(session=service.create_session(body.title))


@router.get("/sessions/{session_id}", response_model=ChatSessionResponse)
def get_session(
    session_id: int, service: ChatServiceDependency
) -> ChatSessionResponse:
    """Return one conversation with its collected slots."""
    return ChatSessionResponse(session=service.session(session_id))


@router.get(
    "/sessions/{session_id}/messages", response_model=ChatMessageListResponse
)
def list_messages(
    session_id: int,
    service: ChatServiceDependency,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> ChatMessageListResponse:
    """Return the messages of one conversation."""
    return ChatMessageListResponse(items=service.messages(session_id, limit))


@router.post("/turn", response_model=ChatTurnResponse)
async def run_turn(
    body: ChatTurnRequest, service: ChatServiceDependency
) -> ChatTurnResponse:
    """Handle one user message and return the assistant's answer."""
    try:
        turn = await service.run_turn(
            session_id=body.session_id, user_input=body.message
        )
    except ChatError as error:
        raise error
    return ChatTurnResponse(turn=turn)
