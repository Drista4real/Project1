from collections.abc import Iterator
from dataclasses import dataclass
from typing import Annotated

import httpx
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from postgrest.exceptions import APIError
from supabase import Client, ClientOptions, create_client
from supabase_auth.errors import AuthApiError, AuthError

from app.application.finance import FinanceService
from app.application.transactions import TransactionService
from app.domain.transactions import TransactionError
from app.infrastructure.config.settings import get_settings
from app.infrastructure.repositories.finance import SupabaseFinanceQueries
from app.infrastructure.repositories.transactions import SupabaseTransactionRepository

bearer = HTTPBearer(auto_error=False)


@dataclass
class UserContext:
    client: Client
    user_id: str


def get_user_context(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> Iterator[UserContext]:
    unauthorized = HTTPException(
        status_code=401,
        detail="Sign in with a valid Supabase access token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise unauthorized
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_publishable_key:
        raise HTTPException(503, "Supabase is not configured")
    # A fresh client prevents one request's token from leaking into another.
    with httpx.Client(timeout=10) as transport:
        client = create_client(
            str(settings.supabase_url),
            settings.supabase_publishable_key.get_secret_value(),
            options=ClientOptions(
                httpx_client=transport,
                persist_session=False,
                auto_refresh_token=False,
            ),
        )
        try:
            response = client.auth.get_user(credentials.credentials)
        except AuthApiError as error:
            if error.status >= 500 or error.status == 429:
                raise HTTPException(
                    503, "Authentication service unavailable"
                ) from error
            raise unauthorized from error
        except (AuthError, httpx.HTTPError) as error:
            raise HTTPException(503, "Authentication service unavailable") from error
        if response is None or response.user is None:
            raise unauthorized
        client.postgrest.auth(credentials.credentials)
        try:
            yield UserContext(client, str(response.user.id))
        except TransactionError as error:
            raise HTTPException(error.status, error.message) from error
        except APIError as error:
            if error.code in {"23505", "23P01", "P0001"}:
                raise HTTPException(409, "Record is duplicated or in use") from error
            if error.code in {"23503", "23514", "22P02"}:
                raise HTTPException(
                    422, "Invalid references or values"
                ) from error
            if error.code == "42501":
                raise HTTPException(403, "Operation is not permitted") from error
            if error.code in {"PGRST301", "PGRST303"}:
                raise unauthorized from error
            raise HTTPException(503, "Data service unavailable") from error
        except httpx.HTTPError as error:
            raise HTTPException(503, "Data service unavailable") from error


UserDependency = Annotated[UserContext, Depends(get_user_context)]


def get_transaction_service(context: UserDependency) -> TransactionService:
    return TransactionService(
        SupabaseTransactionRepository(context.client, context.user_id)
    )


ServiceDependency = Annotated[TransactionService, Depends(get_transaction_service)]


def get_finance_service(context: UserDependency) -> FinanceService:
    return FinanceService(SupabaseFinanceQueries(context.client, context.user_id))


FinanceDependency = Annotated[FinanceService, Depends(get_finance_service)]
