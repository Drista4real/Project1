from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response
from pydantic import BaseModel, ConfigDict, create_model

from app.api.dependencies import UserDependency
from app.application.management import ManagementService
from app.domain.management import RESOURCES
from app.infrastructure.repositories.management import SupabaseManagementRepository

router = APIRouter(prefix="/api/v1/manage", tags=["Management"])


def get_service(context: UserDependency):
    return ManagementService(
        SupabaseManagementRepository(context.client, context.user_id)
    )


Service = Annotated[ManagementService, Depends(get_service)]


def register_writes(resource: str, model: type[BaseModel]):
    """Keep each resource's request contract visible in OpenAPI."""
    fields = {}
    for field, info in model.model_fields.items():
        annotation = info.annotation | None
        if info.metadata:
            annotation = Annotated[annotation, *info.metadata]
        fields[field] = (annotation, None)
    patch_model = create_model(
        f"{model.__name__}Patch", __config__=ConfigDict(extra="forbid"), **fields
    )

    def create_record(data, service):
        return service.create(
            resource, data.model_dump(mode="json", exclude_unset=True)
        )

    create_record.__annotations__ = {"data": model, "service": Service}
    create_record.__name__ = f"create_{resource}"

    def update_record(key, data, service):
        return service.update(
            resource, key, data.model_dump(mode="json", exclude_unset=True)
        )

    update_record.__annotations__ = {
        "key": str,
        "data": patch_model,
        "service": Service,
    }
    update_record.__name__ = f"update_{resource}"
    if resource != "profile":
        router.add_api_route(
            f"/{resource}", create_record, methods=["POST"], status_code=201
        )
    router.add_api_route(f"/{resource}/{{key}}", update_record, methods=["PATCH"])


for resource_name, (_, input_model) in RESOURCES.items():
    register_writes(resource_name, input_model)


@router.get("/resources")
def resources(context: UserDependency):
    return [
        {
            "name": name,
            "title": title,
            "schema": model.model_json_schema(),
            "singleton": name == "profile",
        }
        for name, (title, model) in RESOURCES.items()
    ]


@router.get("/{resource}")
def list_records(
    resource: str,
    service: Service,
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
    offset: Annotated[int, Query(ge=0)] = 0,
):
    return service.list(resource, limit, offset)


@router.get("/{resource}/{key}")
def get_record(resource: str, key: str, service: Service):
    return service.get(resource, key)


@router.delete("/{resource}/{key}", status_code=204)
def delete_record(resource: str, key: str, service: Service):
    service.delete(resource, key)
    return Response(status_code=204)
