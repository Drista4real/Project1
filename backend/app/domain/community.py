"""Domain models and repository port for the public community feed."""

from datetime import date
from decimal import Decimal
from typing import Protocol

from pydantic import BaseModel, ConfigDict, Field


class CommunityGroupSnapshot(BaseModel):
    """Daily/total allocation of one planning group in a shared post."""

    model_config = ConfigDict(extra="forbid")

    group_key: str
    pillar: str = "needs"
    daily_amount: Decimal = Field(ge=0)
    total_amount: Decimal = Field(ge=0)


class CommunityComment(BaseModel):
    """One comment left by an authenticated user on a community post."""

    model_config = ConfigDict(extra="forbid")

    id: int
    post_id: int
    author_name: str
    author_avatar_url: str | None = None
    content: str
    is_own_comment: bool = False
    created_at: str | None = None


class CommunityPost(BaseModel):
    """A shared spending & savings plan visible to all authenticated users."""

    model_config = ConfigDict(extra="forbid")

    id: int
    plan_id: int | None = None
    author_name: str
    author_avatar_url: str | None = None
    is_own_post: bool = False
    title: str
    caption: str | None = None
    total_income: Decimal = Field(ge=0)
    fixed_expenses: Decimal = Field(ge=0)
    savings_target: Decimal = Field(ge=0)
    spendable_budget: Decimal = Field(ge=0)
    daily_allowance: Decimal = Field(ge=0)
    duration_days: int = Field(ge=1, le=365)
    start_date: date
    groups: tuple[CommunityGroupSnapshot, ...] = ()
    likes_count: int = Field(default=0, ge=0)
    comments_count: int = Field(default=0, ge=0)
    liked_by_me: bool = False
    created_at: str | None = None


class PublishPlanInput(BaseModel):
    """Payload to publish an existing budget plan to the community feed."""

    model_config = ConfigDict(extra="forbid")

    plan_id: int = Field(ge=1)
    caption: str | None = Field(default=None, max_length=500)


class CreateCommentInput(BaseModel):
    """Payload to add a comment to a community post."""

    model_config = ConfigDict(extra="forbid")

    content: str = Field(min_length=1, max_length=1000)


class LikeToggleResult(BaseModel):
    """Result after toggling a like on a community post."""

    model_config = ConfigDict(extra="forbid")

    post_id: int
    liked_by_me: bool
    likes_count: int = Field(ge=0)


class CommunityRepository(Protocol):
    """Persistence contract for shared community posts, likes and comments."""

    def list_posts(self, limit: int, offset: int) -> dict: ...

    def publish_plan(
        self, plan_id: int, caption: str | None
    ) -> CommunityPost: ...

    def delete_post(self, post_id: int) -> None: ...

    def toggle_like(self, post_id: int) -> LikeToggleResult: ...

    def list_comments(
        self, post_id: int, limit: int, offset: int
    ) -> dict: ...

    def add_comment(self, post_id: int, content: str) -> CommunityComment: ...
