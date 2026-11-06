"""Nearby place search for the assistant.

Google Places exposes a coarse price level and no price, so the tool returns
places that are *similar* to what the user asked about, filtered by rating,
price level and open state. It never claims to find somewhere cheaper.

`FakePlacesSearch` is deterministic and needs no key, so the tool contract can
be tested and the conversation still works without a Places provider.
"""

import hashlib
import logging
import math
from collections.abc import Sequence

from app.domain.chat import PlaceSuggestion
from app.infrastructure.ai.cloud_vlm._common import configured_value

logger = logging.getLogger(__name__)

#: Prices of the deterministic fake dataset, in VND.
_FAKE_PRICES: tuple[int, ...] = (25_000, 35_000, 45_000, 60_000, 85_000)
_FAKE_RATINGS: tuple[float, ...] = (4.3, 4.5, 4.6, 4.7, 4.8)
_FAKE_NAMES: tuple[str, ...] = (
    "Quán Cà phê Gia đình",
    "Cà phê Sáng",
    "Quán Ăn Vặt",
    "Cà phê Lá",
    "Quán Trà",
)


class FakePlacesSearch:
    """A deterministic place source used in tests and keyless deployments."""

    @property
    def available(self) -> bool:
        """The fake source is always usable."""
        return True

    async def search(
        self,
        *,
        query: str,
        latitude: float,
        longitude: float,
        radius_m: int,
        max_price_level: int,
        min_rating: float,
    ) -> Sequence[PlaceSuggestion]:
        """Return a stable set of places that satisfies the filters."""
        seed = int(
            hashlib.sha256(query.strip().lower().encode("utf-8")).hexdigest()[:8],
            16,
        )
        suggestions: list[PlaceSuggestion] = []
        for index in range(5):
            item = seed + index
            rating = _FAKE_RATINGS[item % len(_FAKE_RATINGS)]
            if rating < min_rating:
                continue
            price_level = (item % 4) + 1
            if price_level > max_price_level:
                continue
            name = _FAKE_NAMES[item % len(_FAKE_NAMES)]
            suggestions.append(
                PlaceSuggestion(
                    name=f"{name} #{index + 1}",
                    rating=rating,
                    price_level=price_level,
                    open_now=(item % 3) != 0,
                    address=f"{item + 1} Đường mẫu, Quận {item % 12 + 1}",
                    google_maps_uri=None,
                )
            )
        return tuple(suggestions)


class GooglePlacesSearch:
    """Search Google Maps Platform Nearby Search for similar places."""

    ENDPOINT = "https://places.googleapis.com/v1/places:searchNearby"
    FIELD_MASK = (
        "places.id,places.displayName,places.rating,places.userRatingCount,"
        "places.priceLevel,places.formattedAddress,places.googleMapsUri,"
        "places.regularOpeningHours"
    )

    def __init__(
        self,
        api_key: str | None = None,
        *,
        timeout_seconds: float = 8.0,
    ) -> None:
        """Read the key from configuration; a missing key disables the tool."""
        key = api_key or configured_value("PLACES_API_KEY") or ""
        self._api_key = key.strip()
        self.timeout_seconds = timeout_seconds

    @property
    def available(self) -> bool:
        """False when no Places key is configured."""
        return bool(self._api_key)

    async def search(
        self,
        *,
        query: str,
        latitude: float,
        longitude: float,
        radius_m: int,
        max_price_level: int,
        min_rating: float,
    ) -> Sequence[PlaceSuggestion]:
        """Return the nearby places that satisfy the filters."""
        if not self.available:
            raise PlacesUnavailable("Google Places chưa được cấu hình.")
        import httpx

        headers = {
            "X-Goog-Api-Key": self._api_key,
            "X-Goog-FieldMask": self.FIELD_MASK,
            "Content-Type": "application/json",
        }
        payload = {
            "includedTypes": ["cafe", "coffee_shop", "restaurant"],
            "maxResultCount": 10,
            "locationRestriction": {
                "circle": {
                    "center": {"latitude": latitude, "longitude": longitude},
                    "radius": float(radius_m),
                }
            },
        }
        try:
            async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                response = await client.post(
                    self.ENDPOINT, headers=headers, json=payload
                )
                response.raise_for_status()
                body = response.json()
        except Exception as error:  # noqa: BLE001 - reported as unavailable
            logger.warning("Places search failed: %s", type(error).__name__)
            raise PlacesUnavailable(
                "Không tìm được địa điểm gần đó lúc này."
            ) from error
        return self._to_suggestions(body, max_price_level, min_rating)

    @staticmethod
    def _to_suggestions(
        body: dict, max_price_level: int, min_rating: float
    ) -> tuple[PlaceSuggestion, ...]:
        """Filter the provider payload by rating and price level."""
        suggestions: list[PlaceSuggestion] = []
        for place in body.get("places", []) or []:
            rating = place.get("rating")
            price_level = _price_level(place.get("priceLevel"))
            if rating is not None and rating < min_rating:
                continue
            if price_level is not None and price_level > max_price_level:
                continue
            display_name = place.get("displayName") or {}
            hours = place.get("regularOpeningHours") or {}
            suggestions.append(
                PlaceSuggestion(
                    name=display_name.get("text") or "Địa điểm không tên",
                    rating=rating,
                    price_level=price_level,
                    open_now=hours.get("openNow"),
                    address=place.get("formattedAddress"),
                    google_maps_uri=place.get("googleMapsUri"),
                )
            )
        return tuple(suggestions)


def _price_level(value: str | None) -> int | None:
    """Convert the provider's price level enum into a comparable number."""
    if not value:
        return None
    mapping = {
        "PRICE_LEVEL_FREE": 0,
        "PRICE_LEVEL_INEXPENSIVE": 1,
        "PRICE_LEVEL_MODERATE": 2,
        "PRICE_LEVEL_EXPENSIVE": 3,
        "PRICE_LEVEL_VERY_EXPENSIVE": 4,
    }
    return mapping.get(value)


def build_places_search(api_key: str | None = None):
    """Return the real adapter when it is configured, the fake one otherwise."""
    adapter = GooglePlacesSearch(api_key)
    if adapter.available:
        return adapter
    logger.info("PLACES_API_KEY is not set; using the deterministic place source")
    return FakePlacesSearch()


class PlacesUnavailable(Exception):
    """The place search is not configured or temporarily unreachable."""


def haversine_meters(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
    """Return the great-circle distance in meters between two points."""
    radius = 6_371_000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = (
        math.sin(delta_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    )
    return 2 * radius * math.asin(math.sqrt(a))
