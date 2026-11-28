"""Supabase persistence for shared community posts, likes and comments."""

from datetime import date
from decimal import Decimal
from typing import Any

from postgrest.exceptions import APIError
from supabase import Client

from app.domain.community import (
    CommunityComment,
    CommunityGroupSnapshot,
    CommunityPost,
    LikeToggleResult,
)
from app.domain.transactions import TransactionError
from app.infrastructure.repositories.budget_plans import (
    SupabaseBudgetPlanRepository,
)


def _decimal(value: Any) -> Decimal:
    if value is None:
        return Decimal("0")
    return Decimal(str(value))


def _author_display_name(profile: dict | None) -> str:
    if not profile:
        return "Người dùng Kakeibo"
    full_name = str(profile.get("full_name") or "").strip()
    if full_name:
        return full_name[:120]
    email = str(profile.get("email") or "").strip()
    if email and "@" in email:
        prefix = email.split("@", 1)[0].strip()
        if prefix:
            return prefix[:120]
    return "Người dùng Kakeibo"


class SupabaseCommunityRepository:
    """Community persistence backed by Supabase with RLS enforcement."""

    def __init__(self, client: Client, user_id: str) -> None:
        self.client = client
        self.user_id = user_id

    def _current_author(self) -> tuple[str, str | None]:
        result = (
            self.client.table("profiles")
            .select("full_name, email, avatar_url")
            .eq("id", self.user_id)
            .limit(1)
            .execute()
        )
        profile = result.data[0] if result.data else None
        avatar = (
            str(profile["avatar_url"]).strip()
            if profile and profile.get("avatar_url")
            else None
        )
        return _author_display_name(profile), avatar or None

    def _ensure_post_exists(self, post_id: int) -> dict:
        result = (
            self.client.table("community_posts")
            .select("*")
            .eq("id", post_id)
            .limit(1)
            .execute()
        )
        if not result.data:
            raise TransactionError(404, "Bài viết không tồn tại hoặc đã bị gỡ.")
        return result.data[0]

    def _to_post(
        self,
        row: dict,
        *,
        likes_count: int = 0,
        comments_count: int = 0,
        liked_by_me: bool = False,
    ) -> CommunityPost:
        raw_groups = row.get("groups_snapshot") or []
        groups = tuple(
            CommunityGroupSnapshot(
                group_key=str(item.get("group_key") or ""),
                pillar=str(item.get("pillar") or "needs"),
                daily_amount=_decimal(item.get("daily_amount")),
                total_amount=_decimal(item.get("total_amount")),
            )
            for item in raw_groups
            if isinstance(item, dict) and item.get("group_key")
        )
        return CommunityPost(
            id=row["id"],
            plan_id=row.get("plan_id"),
            author_name=str(row.get("author_name") or "Người dùng Kakeibo"),
            author_avatar_url=row.get("author_avatar_url"),
            is_own_post=str(row.get("user_id")) == self.user_id,
            title=str(row.get("title") or "Kế hoạch chi tiêu"),
            caption=row.get("caption"),
            total_income=_decimal(row.get("total_income")),
            fixed_expenses=_decimal(row.get("fixed_expenses")),
            savings_target=_decimal(row.get("savings_target")),
            spendable_budget=_decimal(row.get("spendable_budget")),
            daily_allowance=_decimal(row.get("daily_allowance")),
            duration_days=int(row["duration_days"]),
            start_date=date.fromisoformat(str(row["start_date"])),
            groups=groups,
            likes_count=likes_count,
            comments_count=comments_count,
            liked_by_me=liked_by_me,
            created_at=row.get("created_at"),
        )

    def _to_comment(self, row: dict) -> CommunityComment:
        return CommunityComment(
            id=row["id"],
            post_id=row["post_id"],
            author_name=str(row.get("author_name") or "Người dùng Kakeibo"),
            author_avatar_url=row.get("author_avatar_url"),
            content=str(row.get("content") or ""),
            is_own_comment=str(row.get("user_id")) == self.user_id,
            created_at=row.get("created_at"),
        )

    def list_posts(self, limit: int, offset: int) -> dict:
        result = (
            self.client.table("community_posts")
            .select("*", count="exact")
            .order("created_at", desc=True)
            .order("id", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        rows = result.data or []
        post_ids = [row["id"] for row in rows]

        likes_by_post: dict[int, int] = {}
        liked_posts: set[int] = set()
        comments_by_post: dict[int, int] = {}

        if post_ids:
            likes_res = (
                self.client.table("community_post_likes")
                .select("post_id, user_id")
                .in_("post_id", post_ids)
                .execute()
            )
            for like in likes_res.data or []:
                pid = like["post_id"]
                likes_by_post[pid] = likes_by_post.get(pid, 0) + 1
                if str(like.get("user_id")) == self.user_id:
                    liked_posts.add(pid)

            comments_res = (
                self.client.table("community_post_comments")
                .select("post_id")
                .in_("post_id", post_ids)
                .execute()
            )
            for comment in comments_res.data or []:
                pid = comment["post_id"]
                comments_by_post[pid] = comments_by_post.get(pid, 0) + 1

        items = [
            self._to_post(
                row,
                likes_count=likes_by_post.get(row["id"], 0),
                comments_count=comments_by_post.get(row["id"], 0),
                liked_by_me=row["id"] in liked_posts,
            )
            for row in rows
        ]
        return {
            "items": items,
            "total": result.count if result.count is not None else len(items),
            "limit": limit,
            "offset": offset,
        }

    def publish_plan(
        self, plan_id: int, caption: str | None
    ) -> CommunityPost:
        plan_repo = SupabaseBudgetPlanRepository(self.client, self.user_id)
        plan = plan_repo.get(plan_id)
        author_name, author_avatar_url = self._current_author()

        groups_snapshot = [
            {
                "group_key": g.group_key,
                "pillar": g.pillar,
                "daily_amount": str(g.daily_amount),
                "total_amount": str(g.total_amount),
            }
            for g in plan.groups
        ]

        payload = {
            "user_id": self.user_id,
            "plan_id": plan.id,
            "author_name": author_name,
            "author_avatar_url": author_avatar_url,
            "title": plan.title,
            "caption": caption,
            "total_income": str(plan.total_income),
            "fixed_expenses": str(plan.fixed_expenses),
            "savings_target": str(plan.savings_target),
            "spendable_budget": str(plan.spendable_budget),
            "daily_allowance": str(plan.daily_allowance),
            "duration_days": plan.duration_days,
            "start_date": plan.start_date.isoformat(),
            "groups_snapshot": groups_snapshot,
        }

        existing = (
            self.client.table("community_posts")
            .select("*")
            .eq("user_id", self.user_id)
            .eq("plan_id", plan.id)
            .limit(1)
            .execute()
        )
        if existing.data:
            existing_row = existing.data[0]
            updated = (
                self.client.table("community_posts")
                .update(payload)
                .eq("id", existing_row["id"])
                .eq("user_id", self.user_id)
                .execute()
            )
            row = updated.data[0] if updated.data else existing_row
            return self._load_single_post(row)

        try:
            inserted = self.client.table("community_posts").insert(payload).execute()
        except APIError as error:
            if error.code == "23505":
                retry = (
                    self.client.table("community_posts")
                    .select("*")
                    .eq("user_id", self.user_id)
                    .eq("plan_id", plan.id)
                    .limit(1)
                    .execute()
                )
                if retry.data:
                    return self._load_single_post(retry.data[0])
            raise
        if not inserted.data:
            raise TransactionError(409, "Không thể đăng bài viết lên cộng đồng.")
        return self._to_post(inserted.data[0])

    def _load_single_post(self, row: dict) -> CommunityPost:
        pid = row["id"]
        likes_res = (
            self.client.table("community_post_likes")
            .select("user_id")
            .eq("post_id", pid)
            .execute()
        )
        likes_data = likes_res.data or []
        liked_by_me = any(
            str(item.get("user_id")) == self.user_id for item in likes_data
        )
        comments_res = (
            self.client.table("community_post_comments")
            .select("id", count="exact")
            .eq("post_id", pid)
            .execute()
        )
        comments_count = (
            comments_res.count
            if comments_res.count is not None
            else len(comments_res.data or [])
        )
        return self._to_post(
            row,
            likes_count=len(likes_data),
            comments_count=comments_count,
            liked_by_me=liked_by_me,
        )

    def delete_post(self, post_id: int) -> None:
        result = (
            self.client.table("community_posts")
            .delete()
            .eq("id", post_id)
            .eq("user_id", self.user_id)
            .execute()
        )
        if not result.data:
            raise TransactionError(
                404, "Không tìm thấy bài viết hoặc bạn không có quyền xóa."
            )

    def toggle_like(self, post_id: int) -> LikeToggleResult:
        self._ensure_post_exists(post_id)
        existing = (
            self.client.table("community_post_likes")
            .select("post_id")
            .eq("post_id", post_id)
            .eq("user_id", self.user_id)
            .limit(1)
            .execute()
        )
        if existing.data:
            (
                self.client.table("community_post_likes")
                .delete()
                .eq("post_id", post_id)
                .eq("user_id", self.user_id)
                .execute()
            )
            liked = False
        else:
            try:
                self.client.table("community_post_likes").insert(
                    {"post_id": post_id, "user_id": self.user_id}
                ).execute()
            except APIError as error:
                if error.code != "23505":
                    raise
            liked = True

        count_res = (
            self.client.table("community_post_likes")
            .select("post_id", count="exact")
            .eq("post_id", post_id)
            .execute()
        )
        count = (
            count_res.count
            if count_res.count is not None
            else len(count_res.data or [])
        )
        return LikeToggleResult(
            post_id=post_id,
            liked_by_me=liked,
            likes_count=count,
        )

    def list_comments(self, post_id: int, limit: int, offset: int) -> dict:
        self._ensure_post_exists(post_id)
        result = (
            self.client.table("community_post_comments")
            .select("*", count="exact")
            .eq("post_id", post_id)
            .order("created_at", desc=False)
            .order("id", desc=False)
            .range(offset, offset + limit - 1)
            .execute()
        )
        items = [self._to_comment(row) for row in (result.data or [])]
        return {
            "items": items,
            "total": result.count if result.count is not None else len(items),
            "limit": limit,
            "offset": offset,
        }

    def add_comment(self, post_id: int, content: str) -> CommunityComment:
        self._ensure_post_exists(post_id)
        author_name, author_avatar_url = self._current_author()
        inserted = (
            self.client.table("community_post_comments")
            .insert(
                {
                    "post_id": post_id,
                    "user_id": self.user_id,
                    "author_name": author_name,
                    "author_avatar_url": author_avatar_url,
                    "content": content,
                }
            )
            .execute()
        )
        if not inserted.data:
            raise TransactionError(409, "Không thể gửi bình luận.")
        return self._to_comment(inserted.data[0])
