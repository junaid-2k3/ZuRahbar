"""Typed records for the curated Zu dataset.

Every record carries its provenance -- which URL or image it came from, how it
was extracted, and when. When Rehbar quotes a fare or a first-bus time to a
rider it must be able to say where the number came from and how stale it is.
"""

from __future__ import annotations

from datetime import date
from typing import Literal

from pydantic import BaseModel, Field, field_validator

SourceType = Literal["html_table", "html_prose", "vision_verified", "vision_medium", "derived"]
ServiceType = Literal["express", "super_express", "standard", "direct", "unknown"]
Confidence = Literal["high", "medium", "needs_human"]


class Provenance(BaseModel):
    source_url: str
    source_type: SourceType
    retrieved_at: str
    verified_by: str | None = None
    note: str | None = None


class Station(BaseModel):
    station_id: str
    name: str
    aliases: list[str] = Field(default_factory=list)
    urdu: list[str] = Field(default_factory=list)
    pashto: list[str] = Field(default_factory=list)
    served_by: list[str] = Field(default_factory=list)
    is_corridor_station: bool = False
    provenance: Provenance


class RouteStop(BaseModel):
    seq: int
    station_id: str
    name_source: str
    first_bus_mon_thu: str | None = None
    first_bus_fri_sun: str | None = None
    last_bus_mon_thu: str | None = None
    last_bus_fri_sun: str | None = None
    platform: str | None = None
    travel_time_to_next_sec: int | None = None
    distance_to_next_km: float | None = None

    @field_validator("first_bus_mon_thu", "first_bus_fri_sun", "last_bus_mon_thu", "last_bus_fri_sun")
    @classmethod
    def _hhmm(cls, value: str | None) -> str | None:
        if value is None:
            return None
        hour, _, minute = value.partition(":")
        if not (hour.isdigit() and minute.isdigit() and 0 <= int(hour) <= 23 and 0 <= int(minute) <= 59):
            raise ValueError(f"not a 24h HH:MM time: {value!r}")
        return value


class RouteDirection(BaseModel):
    label: str
    origin_id: str
    destination_id: str
    stops: list[RouteStop]

    @property
    def total_travel_sec(self) -> int:
        return sum(stop.travel_time_to_next_sec or 0 for stop in self.stops)


class Route(BaseModel):
    route_id: str
    map_label: str | None = None
    service_type: ServiceType
    length_km: float | None = None
    headway_min_low: int | None = None
    headway_min_high: int | None = None
    has_timetable: bool = False
    stop_confidence: Confidence = "high"
    routable: bool = False
    endpoints: list[str] = Field(default_factory=list)
    directions: list[RouteDirection] = Field(default_factory=list)
    provenance: Provenance

    @property
    def mean_headway_min(self) -> float | None:
        if self.headway_min_low is None:
            return None
        return (self.headway_min_low + (self.headway_min_high or self.headway_min_low)) / 2


class FareBand(BaseModel):
    index: int
    min_km: float
    max_km: float | None
    fare_pkr: int
    previous_fare_pkr: int | None = None

    def covers(self, km: float) -> bool:
        if km < self.min_km - 1e-9:
            return False
        return self.max_km is None or km <= self.max_km + 1e-9


class FareRules(BaseModel):
    currency: str = "PKR"
    basis: Literal["distance_km"] = "distance_km"
    effective_from: date
    bands: list[FareBand]
    single_journey_ticket_pkr: int
    feeder_express_flat_fare_pkr: int
    zu_card_price_pkr: int
    zu_card_price_note: str | None = None
    zu_card_price_source: str | None = None
    provenance: Provenance

    def fare_for_km(self, km: float) -> int:
        for band in self.bands:
            if band.covers(km):
                return band.fare_pkr
        return self.bands[-1].fare_pkr


class ServiceHours(BaseModel):
    opens: str
    closes: str
    days: str
    note: str | None = None
    provenance: Provenance


class ProseDoc(BaseModel):
    doc_id: str
    title: str
    section: str | None = None
    text: str
    lang: str = "en"
    source_url: str
    retrieved_at: str
    doc_type: str = "prose"


class Dataset(BaseModel):
    stations: list[Station]
    routes: list[Route]
    fares: FareRules
    service_hours: ServiceHours
    anomalies: list[str] = Field(default_factory=list)
