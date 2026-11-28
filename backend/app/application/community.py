"""Application service for the multi-user community feed."""

from app.domain.community import (
    CommunityComment,
    CommunityPost,
    CommunityRepository,
    CreateCommentInput,
    LikeToggleResult,
    PublishPlanInput,
)
from app.domain.transactions import TransactionError


class CommunityService:
    """Orchestrates public community feed operations with validation."""

    def __init__(self, repository: CommunityRepository) -> None:
        self.repository = repository

    def list_posts(self, limit: int = 20, offset: int = 0) -> dict:
        """Return paginated community posts visible to all signed-in users."""
        return self.repository.list_posts(limit, offset)

    def publish_plan(self, data: PublishPlanInput) -> CommunityPost:
        """Share one of the authenticated user's plans to the community."""
        caption = data.caption.strip() if data.caption else None
        return self.repository.publish_plan(data.plan_id, caption or None)

    def delete_post(self, post_id: int) -> None:
        """Remove a post owned by the authenticated user."""
        self.repository.delete_post(post_id)

    def toggle_like(self, post_id: int) -> LikeToggleResult:
        """Like or unlike a community post."""
        return self.repository.toggle_like(post_id)

    def list_comments(
        self, post_id: int, limit: int = 50, offset: int = 0
    ) -> dict:
        """Return comments for a community post."""
        return self.repository.list_comments(post_id, limit, offset)

    def add_comment(
        self, post_id: int, data: CreateCommentInput
    ) -> CommunityComment:
        """Post a validated comment on a community post."""
        content = data.content.strip()
        if not content:
            raise TransactionError(422, "Nội dung bình luận không được để trống.")
        return self.repository.add_comment(post_id, content)
