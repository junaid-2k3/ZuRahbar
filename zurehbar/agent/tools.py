"""The tool surface ZuRehbar's Qwen model calls.

Three tools, and a hard division of labour: the model decides *which* tool to
call and how to phrase the answer; the tools decide *what is true*. Routes,
transfers and fares are computed from the curated dataset, never generated.

`TOOL_SCHEMAS` is an OpenAI/Qwen-style function-calling spec, so it can be
handed straight to a Qwen chat endpoint. `dispatch` executes a tool call by name
and returns JSON-serialisable results.
"""

from __future__ import annotations

import json
from typing import Any

from zurehbar.graph.network import NetworkData, build_network
from zurehbar.graph.plan import plan_journey

TOOL_SCHEMAS: list[dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "plan_journey",
            "description": (
                "Plan a Zu Peshawar bus trip between two stops. Returns the buses to take, "
                "where to transfer, boarding platform, journey time and the fare. Use this "
                "whenever a rider asks how to get from one place to another."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "origin": {
                        "type": "string",
                        "description": "Where the rider is starting, in any spelling or script.",
                    },
                    "destination": {
                        "type": "string",
                        "description": "Where the rider wants to go, in any spelling or script.",
                    },
                    "time_of_day": {
                        "type": "string",
                        "description": "Optional departure time, e.g. '9:00am' or '21:30'.",
                    },
                    "day_of_week": {
                        "type": "string",
                        "description": "Optional day, used because Friday to Sunday timings differ.",
                    },
                },
                "required": ["origin", "destination"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_fare",
            "description": (
                "Fare for a trip between two stops, or for a given distance in km. Zu charges "
                "by distance travelled, not by number of stops."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "origin": {"type": "string"},
                    "destination": {"type": "string"},
                    "distance_km": {"type": "number"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_knowledge",
            "description": (
                "Search TransPeshawar's published information: fares, Zu Card, operating hours, "
                "bicycles, lost property, rules, route and station details. Use for any question "
                "that is not a point-to-point trip."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "The rider's question."},
                    "doc_type": {
                        "type": "string",
                        "enum": ["faq", "fare", "route", "station", "service", "prose"],
                        "description": "Optional filter to one kind of document.",
                    },
                    "route_id": {
                        "type": "string",
                        "description": "Optional route filter, e.g. 'ER-01'.",
                    },
                    "limit": {"type": "integer", "default": 5},
                },
                "required": ["query"],
            },
        },
    },
]

SYSTEM_PROMPT = """You are Rehbar, an assistant for Zu Peshawar (Peshawar BRT) riders.

Answer in the language the rider used: English, Urdu, Pashto or Roman Urdu.

Never invent a route, a stop, a time or a fare. Every such fact must come from a
tool result. If the tools do not cover something, say so plainly and say what you
do know.

When a plan comes back with warnings, pass them on: a route excluded for missing
data is not the same as a trip being impossible, and a fare marked as an estimate
must be spoken as an estimate, not as a price.

Keep answers short and practical: which bus, where to get on, where to change,
how long, how much.
"""


class Toolbox:
    """Holds the loaded network so repeated calls do not rebuild the graph."""

    def __init__(self, network: NetworkData | None = None):
        self._network = network

    @property
    def network(self) -> NetworkData:
        if self._network is None:
            self._network = build_network()
        return self._network

    def plan_journey(
        self,
        origin: str,
        destination: str,
        time_of_day: str | None = None,
        day_of_week: str | None = None,
    ) -> dict[str, Any]:
        plan = plan_journey(
            origin, destination, time_of_day=time_of_day, day_of_week=day_of_week, network=self.network
        )
        return plan.to_dict()

    def get_fare(
        self,
        origin: str | None = None,
        destination: str | None = None,
        distance_km: float | None = None,
    ) -> dict[str, Any]:
        if origin and destination:
            plan = plan_journey(origin, destination, network=self.network)
            if plan.found and plan.fare:
                return {
                    "found": True,
                    "fare_pkr": plan.fare.total_pkr,
                    "distance_km": plan.fare.distance_km,
                    "is_estimate": plan.fare.is_estimate,
                    "note": plan.fare.note,
                }
            return {"found": False, "message": plan.message, "warnings": plan.warnings}

        fares = self.network.fares
        if distance_km is None:
            return {
                "found": True,
                "bands": fares["bands"],
                "single_journey_ticket_pkr": fares["single_journey_ticket_pkr"],
                "feeder_express_flat_fare_pkr": fares["feeder_express_flat_fare_pkr"],
                "zu_card_price_pkr": fares["zu_card_price_pkr"],
            }
        for band in fares["bands"]:
            upper = band["max_km"]
            if distance_km >= band["min_km"] - 1e-9 and (upper is None or distance_km <= upper + 1e-9):
                return {
                    "found": True,
                    "fare_pkr": band["fare_pkr"],
                    "band_index": band["index"],
                    "distance_km": distance_km,
                    "is_estimate": False,
                }
        return {"found": False, "message": f"No fare band covers {distance_km} km."}

    def search_knowledge(
        self,
        query: str,
        doc_type: str | None = None,
        route_id: str | None = None,
        limit: int = 5,
    ) -> dict[str, Any]:
        from zurehbar.index.qdrant_load import search

        try:
            hits = search(query, limit=limit, doc_type=doc_type, route_id=route_id)
        except Exception as exc:  # noqa: BLE001 - the index may not be running
            return {"found": False, "error": str(exc), "results": []}
        return {"found": bool(hits), "results": hits}

    def dispatch(self, name: str, arguments: dict[str, Any] | str) -> dict[str, Any]:
        if isinstance(arguments, str):
            arguments = json.loads(arguments or "{}")
        handler = {
            "plan_journey": self.plan_journey,
            "get_fare": self.get_fare,
            "search_knowledge": self.search_knowledge,
        }.get(name)
        if handler is None:
            return {"error": f"unknown tool {name!r}"}
        return handler(**arguments)
