"""HTTP endpoints for the multi-user community feed."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response
from pydantic import BaseModel, ConfigDict

from app.api.dependencies import UserDependency
from app.application.community import CommunityService
from app.domain.community import (
    CommunityComment,
    CommunityPost,
    CreateCommentInput,
    LikeToggleResult,
    PublishPlanInput,
)
from app.infrastructure.repositories.community import SupabaseCommunityRepository

router = APIRouter(prefix="/api/v1/community", tags=["Community"])


def get_community_service(context: UserDependency) -> CommunityService:
    """Build the community service for the authenticated user."""
    return CommunityService(
        SupabaseCommunityRepository(context.client, context.user_id)
    )


Service = Annotated[CommunityService, Depends(get_community_service)]


class PostResponse(BaseModel):
    """One shared community post."""

    model_config = ConfigDict(extra="forbid")

    post: CommunityPost


class PostListResponse(BaseModel):
    """A page of shared community posts."""

    model_config = ConfigDict(extra="forbid")

    items: list[CommunityPost]
    total: int
    limit: int
    offset: int


class CommentResponse(BaseModel):
    """One community comment."""

    model_config = ConfigDict(extra="forbid")

    comment: CommunityComment


class CommentListResponse(BaseModel):
    """A page of comments for a post."""

    model_config = ConfigDict(extra="forbid")

    items: list[CommunityComment]
    total: int
    limit: int
    offset: int


@router.get("/posts", response_model=PostListResponse)
def list_posts(
    service: Service,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> PostListResponse:
    """Return shared community posts visible to every signed-in user."""
    return PostListResponse(**service.list_posts(limit, offset))


@router.post("/posts", response_model=PostResponse, status_code=201)
def publish_plan(data: PublishPlanInput, service: Service) -> PostResponse:
    """Share one of the authenticated user's budget plans to the community."""
    return PostResponse(post=service.publish_plan(data))


@router.delete("/posts/{post_id}", status_code=204)
def delete_post(post_id: int, service: Service) -> Response:
    """Delete a community post owned by the authenticated user."""
    service.delete_post(post_id)
    return Response(status_code=204)


@router.post("/posts/{post_id}/like", response_model=LikeToggleResult)
def toggle_like(post_id: int, service: Service) -> LikeToggleResult:
    """Toggle the authenticated user's like on a post."""
    return service.toggle_like(post_id)


@router.get("/posts/{post_id}/comments", response_model=CommentListResponse)
def list_comments(
    post_id: int,
    service: Service,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> CommentListResponse:
    """List comments on a community post."""
    return CommentListResponse(**service.list_comments(post_id, limit, offset))


@router.post(
    "/posts/{post_id}/comments",
    response_model=CommentResponse,
    status_code=201,
)
def add_comment(
    post_id: int, data: CreateCommentInput, service: Service
) -> CommentResponse:
    """Add a comment on a community post."""
    return CommentResponse(comment=service.add_comment(post_id, data))
