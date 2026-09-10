"""The Zu network as a graph.

A plain station-to-station graph cannot express the cost that dominates a real
BRT trip: waiting for the next bus, and waiting again after a transfer. So the
graph is built over *route-stop* nodes instead of stations:

    station S --board(wait)--> (route R, direction D, station S)
                                      | ride (travel time)
                                      v
                              (route R, direction D, station T) --alight(0)--> station T

Boarding an edge costs the expected wait, taken as half the route's headway.
Staying on the bus costs only ride time, so a shortest path naturally prefers a
one-seat ride over a transfer unless the transfer genuinely saves time.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import networkx as nx

from zurehbar.paths import CURATED_DIR

# Time a rider spends walking between platforms and clearing the gate.
TRANSFER_PENALTY_SEC = 90
# Used when a route publishes no headway (map-only routes).
DEFAULT_HEADWAY_MIN = 15.0


@dataclass
class NetworkData:
    graph: nx.DiGraph
    routes: dict[str, dict[str, Any]]
    stations: dict[str, dict[str, Any]]
    fares: dict[str, Any]
    service_hours: dict[str, Any]

    def station_node(self, station_id: str) -> str:
        return f"station:{station_id}"

    def has_station(self, station_id: str) -> bool:
        return self.station_node(station_id) in self.graph


def _load(name: str, curated_dir: Path) -> Any:
    return json.loads((curated_dir / f"{name}.json").read_text(encoding="utf-8"))


def build_network(curated_dir: Path | str = CURATED_DIR) -> NetworkData:
    curated_dir = Path(curated_dir)
    routes = _load("routes", curated_dir)
    stations = _load("stations", curated_dir)
    fares = _load("fares", curated_dir)
    service_hours = _load("service_hours", curated_dir)

    graph = nx.DiGraph()
    for station in stations:
        graph.add_node(f"station:{station['station_id']}", kind="station", **station)

    for route in routes:
        if not route.get("routable"):
            # Routes whose stop sequence could not be read reliably are still in
            # the dataset and still searchable as text, but they must never carry
            # a rider through a turn-by-turn plan.
            continue
        headway = route.get("mean_headway_min") or _mean_headway(route) or DEFAULT_HEADWAY_MIN
        wait_sec = int(headway * 60 / 2)

        for direction_index, direction in enumerate(route.get("directions", [])):
            stops = direction.get("stops", [])
            for stop in stops:
                node = _stop_node(route["route_id"], direction_index, stop["station_id"])
                graph.add_node(
                    node,
                    kind="route_stop",
                    route_id=route["route_id"],
                    direction=direction_index,
                    direction_label=direction.get("label"),
                    station_id=stop["station_id"],
                    platform=stop.get("platform"),
                    first_bus_mon_thu=stop.get("first_bus_mon_thu"),
                    first_bus_fri_sun=stop.get("first_bus_fri_sun"),
                    last_bus_mon_thu=stop.get("last_bus_mon_thu"),
                    last_bus_fri_sun=stop.get("last_bus_fri_sun"),
                )
                station_node = f"station:{stop['station_id']}"
                if station_node not in graph:
                    graph.add_node(station_node, kind="station", station_id=stop["station_id"])
                graph.add_edge(station_node, node, kind="board", weight=wait_sec + TRANSFER_PENALTY_SEC)
                graph.add_edge(node, station_node, kind="alight", weight=0)

            for current, following in zip(stops, stops[1:]):
                ride = current.get("travel_time_to_next_sec")
                if ride is None:
                    ride = _fallback_ride_time(route, len(stops))
                graph.add_edge(
                    _stop_node(route["route_id"], direction_index, current["station_id"]),
                    _stop_node(route["route_id"], direction_index, following["station_id"]),
                    kind="ride",
                    weight=int(ride),
                    distance_km=current.get("distance_to_next_km") or 0.0,
                    route_id=route["route_id"],
                )

    return NetworkData(
        graph=graph,
        routes={route["route_id"]: route for route in routes},
        stations={station["station_id"]: station for station in stations},
        fares=fares,
        service_hours=service_hours,
    )


def _stop_node(route_id: str, direction: int, station_id: str) -> str:
    return f"stop:{route_id}:{direction}:{station_id}"


def _mean_headway(route: dict[str, Any]) -> float | None:
    low, high = route.get("headway_min_low"), route.get("headway_min_high")
    if low is None:
        return None
    return (low + (high or low)) / 2


def _fallback_ride_time(route: dict[str, Any], stop_count: int) -> int:
    """Map-only routes carry no timings; assume the published length at 20 km/h."""
    length_km = route.get("length_km") or 0
    legs = max(stop_count - 1, 1)
    if not length_km:
        return 180
    return int((length_km / legs) / 20 * 3600)


def transfer_stations(network: NetworkData) -> dict[str, list[str]]:
    """Stations where a rider can change between two or more routable routes."""
    result: dict[str, list[str]] = {}
    for station_id, station in network.stations.items():
        routes = [
            route_id
            for route_id in station.get("served_by", [])
            if network.routes.get(route_id, {}).get("routable")
        ]
        if len(routes) > 1:
            result[station_id] = sorted(routes)
    return result
