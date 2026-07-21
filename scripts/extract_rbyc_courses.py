#!/usr/bin/env python3
import json
import re
from pathlib import Path
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / "reference-course-books/RBYC-Keelboat-Sailing-Instructions-2025-2026-v6.pdf"
OUTPUT = ROOT / "course-packs/rbyc-2025-2026"


def page_text(reader, *page_indexes):
    text = "\n".join(reader.pages[index].extract_text() or "" for index in page_indexes)
    return text.replace("–", "-").replace("’", "'").replace("  ", " ")


def route_rows(sequence, default_side):
    sequence = re.sub(r"\s*-\s*", " - ", sequence.strip())
    sequence = re.sub(r"\b([^\s-]+)\s+Finish$", r"\1 - Finish", sequence)
    tokens = [token.strip() for token in re.split(r"\s+-\s+", sequence) if token.strip()]
    rows = []
    for token in tokens:
        lower = token.lower()
        if lower.startswith("start"):
            side = "start"
        elif lower.startswith("finish"):
            side = "finish"
        elif lower in {"gate", "3p/s", "3s/p"}:
            side = "gate"
        else:
            side = default_side
        rows.append({"mark": token, "side": side, "bearing": "", "distance": ""})
    return rows


def course(number, group_id, route, sequence, distance, source_page, kind, identity_suffix=None, note=None, default_side="port"):
    value = {
        "courseNumber": number,
        "groupId": group_id,
        "route": route,
        "passInstruction": "All marks are left to %s except gate marks." % default_side,
        "rows": route_rows(sequence, default_side),
        "totalDistance": distance,
        "chartImage": "",
        "chartAlt": "",
        "dataStatus": "verified-from-official-pdf-v6" if kind == "fixed" else "verified-from-official-pdf-v6-race-day-positions-required",
        "sourcePage": source_page,
        "comparableCourseNote": note,
    }
    if identity_suffix:
        value["identitySuffix"] = identity_suffix
    return value


reader = PdfReader(str(PDF))

laid_specs = [
    ("boat-boat-etchells-dragon", "Etchells & Dragon", [
        (1, "Start - 1 - 2 - Finish"),
        (2, "Start - 1 - 2 - 3p/s - 1 - 2 - Finish"),
        (3, "Start - 1 - 2 - 3p/s - 1 - 2 - 3p/s - 1 - 2 - Finish"),
    ]),
    ("boat-boat-vx-one", "VX One", [
        (1, "Start - 1 - 2 - Finish"),
        (2, "Start - 1b - 2b - 3p/s - 1b - 2b - Finish"),
        (3, "Start - 1 - 2 - 3p/s - 1 - 2 - Finish"),
    ]),
    ("boat-boat-24mr", "2.4mR", [
        (1, "Start - 1b - Finish"),
        (2, "Start - 1b - 3p/s - 1b - Finish"),
        (3, "Start - 1b - 3p/s - 1b - 3p/s - 1b - Finish"),
    ]),
    ("boat-boat-other", "Other Keelboats", [
        (1, "Start - 1a - Finish"),
        (2, "Start - 1a - 4 - 1a - Finish"),
        (3, "Start - 1a - 4 - 1a - 4 - 1a - Finish"),
    ]),
]

laid = []
for group_id, class_name, specs in laid_specs:
    suffix = group_id.removeprefix("boat-boat-")
    for number, sequence in specs:
        laid.append(course(
            number, group_id, f"Boat Start/Boat Finish - {class_name}", sequence, "", 8, "laid",
            identity_suffix=suffix,
            note="Temporary laid-mark positions and committee-vessel lines are race-day values.",
        ))

boat_tower_text = page_text(reader, 8, 9)
boat_tower_pattern = re.compile(
    r"(?m)^(\d+)\s+(N|NW|W|SW|S|SE|E|NE)\s+(\d+)\s+(Port|Stbd)\s+(Start.*?Finish)\s*$"
)
boat_tower_matches = boat_tower_pattern.findall(boat_tower_text)
assert [int(match[0]) for match in boat_tower_matches] == list(range(4, 50))

fixed = []
for number, wind, distance, leave_to, sequence in boat_tower_matches:
    side = "starboard" if leave_to == "Stbd" else "port"
    fixed.append(course(
        int(number), "boat-tower", f"Boat Start/Tower Finish - {wind} wind/start", sequence,
        f"{distance} nm", 9 if int(number) <= 36 else 10, "fixed", default_side=side,
        note="The weather gate is a temporary pink inflatable gate laid to weather of the start.",
    ))

tower_text = page_text(reader, 10, 11)
tower_pattern = re.compile(
    r"(?m)^(\d+)\s+(E|NE|N|NW|SE|S|SW|W/NW)\s+(\d+)\s+(Nth|Sth)\s+(Port|Stbd)\s+(Start.*?Finish(?: \(northerly direction\))?)\s*$"
)
tower_matches = tower_pattern.findall(tower_text)
assert [int(match[0]) for match in tower_matches] == list(range(50, 100))

for number, wind, distance, start_direction, leave_to, sequence in tower_matches:
    side = "starboard" if leave_to == "Stbd" else "port"
    fixed.append(course(
        int(number), "tower-tower", f"Tower Start/Tower Finish - {wind} wind, {start_direction} start",
        sequence, f"{distance} nm", 11 if int(number) <= 77 else 12, "fixed", default_side=side,
    ))

OUTPUT.mkdir(parents=True, exist_ok=True)
(OUTPUT / "fixed-courses.json").write_text(json.dumps(fixed, indent=2) + "\n")
(OUTPUT / "laid-courses.json").write_text(json.dumps(laid, indent=2) + "\n")
print(f"Wrote {len(fixed)} fixed/hybrid routes and {len(laid)} laid class variants.")
