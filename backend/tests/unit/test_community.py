"""Unit and endpoint tests for the multi-user community feed."""

from datetime import date
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import UserContext, get_user_context
from app.api.v1.endpoints.community import get_community_service
from app.application.community import CommunityService
from app.domain.community import (
    CommunityComment,
    CommunityGroupSnapshot,
    CommunityPost,
    LikeToggleResult,
)
from app.domain.transactions import TransactionError
from app.infrastructure.repositories.community import _author_display_name
from app.main import app


class FakeCommunityStore:
    """Shared multi-user in-memory store to verify cross-user visibility."""

    def __init__(self) -> None:
        self.posts: list[dict] = []
        self.likes: dict[int, set[str]] = {}
        self.comments: dict[int, list[dict]] = {}
        self._next_post_id = 1
        self._next_comment_id = 1


class FakeCommunityRepository:
    """Per-user view over the shared FakeCommunityStore."""

    def __init__(self, store: FakeCommunityStore, user_id: str) -> None:
        self.store = store
        self.user_id = user_id

    def _serialize_post(self, row: dict) -> CommunityPost:
        pid = row["id"]
        likes = self.store.likes.get(pid, set())
        comments = self.store.comments.get(pid, [])
        return CommunityPost(
            id=pid,
            plan_id=row["plan_id"],
            author_name=row["author_name"],
            author_avatar_url=row["author_avatar_url"],
            is_own_post=row["user_id"] == self.user_id,
            title=row["title"],
            caption=row["caption"],
            total_income=row["total_income"],
            fixed_expenses=row["fixed_expenses"],
            savings_target=row["savings_target"],
            spendable_budget=row["spendable_budget"],
            daily_allowance=row["daily_allowance"],
            duration_days=row["duration_days"],
            start_date=row["start_date"],
            groups=row["groups"],
            likes_count=len(likes),
            comments_count=len(comments),
            liked_by_me=self.user_id in likes,
            created_at="2026-11-28T09:00:00Z",
        )

    def list_posts(self, limit: int, offset: int) -> dict:
        ordered = list(reversed(self.store.posts))
        sliced = ordered[offset : offset + limit]
        return {
            "items": [self._serialize_post(row) for row in sliced],
            "total": len(ordered),
            "limit": limit,
            "offset": offset,
        }

    def publish_plan(
        self, plan_id: int, caption: str | None
    ) -> CommunityPost:
        row = {
            "id": self.store._next_post_id,
            "user_id": self.user_id,
            "plan_id": plan_id,
            "author_name": f"User {self.user_id}",
            "author_avatar_url": "preset:leaf",
            "title": "Kế hoạch tháng 11",
            "caption": caption,
            "total_income": Decimal("3000000"),
            "fixed_expenses": Decimal("1500000"),
            "savings_target": Decimal("300000"),
            "spendable_budget": Decimal("1200000"),
            "daily_allowance": Decimal("40000"),
            "duration_days": 30,
            "start_date": date(2026, 11, 25),
            "groups": (
                CommunityGroupSnapshot(
                    group_key="food",
                    pillar="needs",
                    daily_amount=Decimal("24000"),
                    total_amount=Decimal("720000"),
                ),
            ),
        }
        self.store._next_post_id += 1
        self.store.posts.append(row)
        return self._serialize_post(row)

    def delete_post(self, post_id: int) -> None:
        for idx, row in enumerate(self.store.posts):
            if row["id"] == post_id and row["user_id"] == self.user_id:
                self.store.posts.pop(idx)
                return
        raise TransactionError(404, "Không tìm thấy bài viết hoặc không có quyền xóa.")

    def toggle_like(self, post_id: int) -> LikeToggleResult:
        if not any(row["id"] == post_id for row in self.store.posts):
            raise TransactionError(404, "Bài viết không tồn tại.")
        likes = self.store.likes.setdefault(post_id, set())
        if self.user_id in likes:
            likes.remove(self.user_id)
            liked = False
        else:
            likes.add(self.user_id)
            liked = True
        return LikeToggleResult(
            post_id=post_id, liked_by_me=liked, likes_count=len(likes)
        )

    def list_comments(self, post_id: int, limit: int, offset: int) -> dict:
        if not any(row["id"] == post_id for row in self.store.posts):
            raise TransactionError(404, "Bài viết không tồn tại.")
        items = self.store.comments.get(post_id, [])
        sliced = items[offset : offset + limit]
        return {
            "items": [
                CommunityComment(
                    id=c["id"],
                    post_id=post_id,
                    author_name=c["author_name"],
                    author_avatar_url=c["author_avatar_url"],
                    content=c["content"],
                    is_own_comment=c["user_id"] == self.user_id,
                    created_at="2026-11-28T09:05:00Z",
                )
                for c in sliced
            ],
            "total": len(items),
            "limit": limit,
            "offset": offset,
        }

    def add_comment(self, post_id: int, content: str) -> CommunityComment:
        if not any(row["id"] == post_id for row in self.store.posts):
            raise TransactionError(404, "Bài viết không tồn tại.")
        row = {
            "id": self.store._next_comment_id,
            "user_id": self.user_id,
            "author_name": f"User {self.user_id}",
            "author_avatar_url": "preset:star",
            "content": content,
        }
        self.store._next_comment_id += 1
        self.store.comments.setdefault(post_id, []).append(row)
        return CommunityComment(
            id=row["id"],
            post_id=post_id,
            author_name=row["author_name"],
            author_avatar_url=row["author_avatar_url"],
            content=content,
            is_own_comment=True,
            created_at="2026-11-28T09:05:00Z",
        )


@pytest.fixture
def community_env():
    store = FakeCommunityStore()
    active_user = {"id": "user-a"}

    async def fake_context():
        yield UserContext(client=None, user_id=active_user["id"])

    def service_factory():
        return CommunityService(
            FakeCommunityRepository(store, active_user["id"])
        )

    app.dependency_overrides[get_user_context] = fake_context
    app.dependency_overrides[get_community_service] = service_factory
    with TestClient(app) as client:
        yield client, active_user
    app.dependency_overrides.clear()


class TestCommunityEndpoints:
    def test_any_signed_in_user_can_view_and_interact_with_posts(
        self, community_env
    ):
        client, active_user = community_env

        # User A publishes a plan
        res = client.post(
            "/api/v1/community/posts",
            json={"plan_id": 10, "caption": "Quyết tâm tiết kiệm tháng 11"},
        )
        assert res.status_code == 201
        post_id = res.json()["post"]["id"]
        assert res.json()["post"]["is_own_post"] is True

        # Switch to User B
        active_user["id"] = "user-b"
        feed = client.get("/api/v1/community/posts")
        assert feed.status_code == 200
        items = feed.json()["items"]
        assert len(items) == 1
        assert items[0]["id"] == post_id
        assert items[0]["is_own_post"] is False
        assert items[0]["caption"] == "Quyết tâm tiết kiệm tháng 11"

        # User B likes and comments
        like = client.post(f"/api/v1/community/posts/{post_id}/like")
        assert like.status_code == 200
        assert like.json() == {
            "post_id": post_id,
            "liked_by_me": True,
            "likes_count": 1,
        }

        comment = client.post(
            f"/api/v1/community/posts/{post_id}/comments",
            json={"content": "Kế hoạch hợp lý quá!"},
        )
        assert comment.status_code == 201
        assert comment.json()["comment"]["content"] == "Kế hoạch hợp lý quá!"

        # Blank comment is rejected
        bad_comment = client.post(
            f"/api/v1/community/posts/{post_id}/comments",
            json={"content": "   "},
        )
        assert bad_comment.status_code == 422

        # User B cannot delete User A's post
        delete_forbidden = client.delete(f"/api/v1/community/posts/{post_id}")
        assert delete_forbidden.status_code == 404

        # User A sees the like & comment, and can delete their own post
        active_user["id"] = "user-a"
        feed_a = client.get("/api/v1/community/posts").json()["items"][0]
        assert feed_a["likes_count"] == 1
        assert feed_a["comments_count"] == 1
        assert feed_a["liked_by_me"] is False

        delete_ok = client.delete(f"/api/v1/community/posts/{post_id}")
        assert delete_ok.status_code == 204
        assert client.get("/api/v1/community/posts").json()["items"] == []


def test_author_display_name_fallbacks():
    assert (
        _author_display_name({"full_name": "Minh Anh", "email": "a@b.com"})
        == "Minh Anh"
    )
    assert (
        _author_display_name({"full_name": "  ", "email": "dat@example.com"})
        == "dat"
    )
    assert _author_display_name(None) == "Người dùng Kakeibo"
