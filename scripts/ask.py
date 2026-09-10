#!/usr/bin/env python
"""End-to-end check: rider question -> tools -> grounded context.

    python scripts/ask.py "How do I get from University Town to Saddar Bazaar?"
    python scripts/ask.py --demo

Prints exactly the context ZuRehbar's Qwen model would receive. No model is
called here: the point is to prove the tools and the index answer correctly
before any generation layer is attached, so that a wrong answer can only come
from phrasing, never from the facts.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from zurehbar.agent.tools import Toolbox  # noqa: E402

DEMO_QUESTIONS = [
    "How do I get from University Town to Saddar Bazaar?",
    "chamkani se hayatabad kaise jaon",
    "How much does a Zu card cost?",
    "کیا زو کارڈ سائیکل پر چلتا ہے",
    "When does the last ER-01 bus leave Chamkani?",
    "Can I get from Board Bazar to Regi Model Town?",
]

TRIP_PATTERN = re.compile(
    r"(?:from|se)\s+(?P<origin>.+?)\s+(?:to|tak|kaise|jaon|jana)\b|"
    r"(?P<origin2>.+?)\s+(?:to|se)\s+(?P<destination>.+)",
    re.IGNORECASE,
)


def looks_like_a_trip(question: str) -> tuple[str, str] | None:
    lowered = question.lower()
    if " to " in lowered:
        left, _, right = question.partition(" to ")
        origin = re.sub(r"^.*?\bfrom\s+", "", left, flags=re.IGNORECASE).strip(" ?.,")
        return origin, right.strip(" ?.,")
    if " se " in lowered:
        left, _, right = lowered.partition(" se ")
        destination = re.sub(r"\s+(kaise|kese)\s+(jaon|jaun|jana).*$", "", right).strip(" ?.,")
        return left.strip(" ?.,"), destination
    return None


def answer(question: str, tools: Toolbox) -> dict:
    trip = looks_like_a_trip(question)
    context: dict = {"question": question, "tool_calls": []}

    if trip:
        origin, destination = trip
        plan = tools.dispatch("plan_journey", {"origin": origin, "destination": destination})
        context["tool_calls"].append({"tool": "plan_journey", "result": plan})
        if plan.get("found"):
            return context

    search = tools.dispatch("search_knowledge", {"query": question, "limit": 3})
    context["tool_calls"].append({"tool": "search_knowledge", "result": search})
    return context


def render(context: dict) -> None:
    print(f"\nQ: {context['question']}")
    for call in context["tool_calls"]:
        result = call["result"]
        if call["tool"] == "plan_journey":
            if not result.get("found"):
                print(f"  plan_journey: {result.get('message')}")
                for warning in result.get("warnings", []):
                    print(f"    ! {warning}")
                continue
            for leg in result["legs"]:
                platform = f", platform {leg['platform']}" if leg["platform"] else ""
                print(
                    f"  take {leg['route_id']} from {leg['board_station']} to "
                    f"{leg['alight_station']} ({leg['stop_count']} stops, "
                    f"~{leg['ride_time_min']:.0f} min{platform})"
                )
            if result["transfers"]:
                print(f"  change at: {', '.join(result['transfers'])}")
            fare = result["fare"]
            estimate = " (estimate)" if fare["is_estimate"] else ""
            print(f"  about {result['total_time_min']:.0f} min, Rs. {fare['total_pkr']}{estimate}")
            for warning in result.get("warnings", []):
                print(f"    ! {warning}")
        else:
            if result.get("error"):
                print(f"  search_knowledge unavailable: {result['error']}")
                continue
            for hit in result.get("results", []):
                print(f"  [{hit['doc_type']}] {hit['title']}")
                print(f"      {hit['text'][:180]}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Ask ZuRehbar's tools a question")
    parser.add_argument("question", nargs="*", help="the rider's question")
    parser.add_argument("--demo", action="store_true", help="run the built-in question set")
    parser.add_argument("--json", action="store_true", help="print raw tool output")
    args = parser.parse_args()

    tools = Toolbox()
    questions = DEMO_QUESTIONS if args.demo or not args.question else [" ".join(args.question)]

    for question in questions:
        context = answer(question, tools)
        if args.json:
            print(json.dumps(context, ensure_ascii=False, indent=2))
        else:
            render(context)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
