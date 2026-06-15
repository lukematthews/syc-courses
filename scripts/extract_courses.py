import json
import re
from pathlib import Path

import fitz

PDF_PATH = Path("source/SYC-2025-28-Course-Booklet_Rev_0.pdf")
CHART_DIR = Path("public/course-charts")
OUT_JSON = Path("source/extracted-courses.json")


def clean_line(line: str) -> str:
    return " ".join(line.strip().split())


def parse_side_instruction(text: str) -> str:
    lowered = text.lower()
    if "all marks to port" in lowered:
        return "Port"
    if "all marks to stbd" in lowered:
        return "Stbd"
    return ""


def split_mark_side(mark: str, default_side: str) -> tuple[str, str]:
    raw = clean_line(mark)
    side = default_side
    match = re.search(r"\(([^)]+)\)", raw)

    if match:
        explicit = match.group(1).strip().lower()
        if explicit == "pass":
            side = "Pass"
        elif explicit in {"port", "p"}:
            side = "Port"
        elif explicit in {"stbd", "starboard"}:
            side = "Stbd"

        raw = clean_line(re.sub(r"\s*\([^)]*\)", "", raw))

    if raw.upper() == "FINISH":
        side = "Finish"
    if raw.upper() in {"TOTAL", "SUB-TOTAL"}:
        side = ""

    return raw, side


def parse_rows(text: str, default_side: str) -> list[dict[str, str]]:
    tokens = [clean_line(line) for line in text.splitlines() if clean_line(line)]
    rows = []
    i = 0

    while i < len(tokens):
        mark_token = tokens[i]
        upper = mark_token.upper()

        if upper in {"TOTAL", "SUB-TOTAL"}:
            if i + 1 >= len(tokens):
                raise ValueError(f"Missing distance after {mark_token}: {tokens}")

            rows.append(
                {
                    "mark": upper,
                    "side": "",
                    "bearing": "",
                    "distance": tokens[i + 1],
                }
            )
            i += 2
            continue

        if i + 2 >= len(tokens):
            raise ValueError(f"Incomplete row at {mark_token}: {tokens}")

        mark, side = split_mark_side(mark_token, default_side)
        rows.append(
            {
                "mark": mark,
                "side": side,
                "bearing": tokens[i + 1],
                "distance": tokens[i + 2],
            }
        )
        i += 3

    return rows


def extract_courses() -> list[dict]:
    doc = fitz.open(PDF_PATH)
    courses = []
    CHART_DIR.mkdir(parents=True, exist_ok=True)

    for pno in range(3, 37):
        page = doc[pno]
        course_numbers = [2 * (pno - 3) + 1, 2 * (pno - 3) + 2]

        image_rects = []
        for image in page.get_images(full=True):
            xref = image[0]
            for rect in page.get_image_rects(xref):
                if rect.x0 < 80 and rect.width > 150 and rect.height > 150:
                    image_rects.append((rect.y0, rect))

        image_rects.sort(key=lambda item: item[0])
        if len(image_rects) != 2:
            raise RuntimeError(f"Expected 2 chart images on page {pno + 1}, got {len(image_rects)}")

        blocks = page.get_text("blocks")
        for idx, course_number in enumerate(course_numbers):
            is_top = idx == 0
            region_min = 90 if is_top else 420
            region_max = 390 if is_top else 730

            pass_blocks = []
            data_blocks = []
            comparable = ""

            for block in blocks:
                x0, y0, _x1, _y1, text, *_rest = block
                if not (region_min <= y0 <= region_max):
                    continue

                clean = clean_line(text)
                if (
                    x0 < 180
                    and not clean.startswith("All marks")
                    and "TOTAL" not in text
                    and not clean.startswith("Comparable")
                ):
                    continue

                if clean.startswith("All marks"):
                    pass_blocks.append((y0, clean))
                elif "TOTAL" in text:
                    data_blocks.append((y0, text))
                elif clean.startswith("Comparable"):
                    comparable = clean

            if not pass_blocks or not data_blocks:
                raise RuntimeError(f"Missing table data for course {course_number} on page {pno + 1}")

            pass_instruction = sorted(pass_blocks, key=lambda item: item[0])[0][1]
            data_text = sorted(data_blocks, key=lambda item: item[0])[0][1]
            rows = parse_rows(data_text, parse_side_instruction(pass_instruction))
            total = next((row["distance"] for row in reversed(rows) if row["mark"] == "TOTAL"), "")

            _y0, rect = image_rects[idx]
            pix = page.get_pixmap(matrix=fitz.Matrix(3, 3), clip=rect, alpha=False)
            chart_name = f"course-{course_number:02d}.png"
            pix.save(CHART_DIR / chart_name)

            courses.append(
                {
                    "courseNumber": course_number,
                    "passInstruction": pass_instruction,
                    "rows": rows,
                    "totalDistance": f"{total} nm" if total else "",
                    "chartImage": f"/course-charts/{chart_name}",
                    "chartAlt": (
                        f"Course {course_number} chart cropped from SYC 2025-28 "
                        f"course booklet page {pno + 1}."
                    ),
                    "dataStatus": "verified-from-pdf",
                    "sourcePage": pno + 1,
                    "comparableCourseNote": comparable,
                }
            )

    return courses


def main() -> None:
    courses = extract_courses()
    OUT_JSON.write_text(json.dumps(courses, indent=2), encoding="utf-8")
    print(f"Extracted {len(courses)} courses to {OUT_JSON}")


if __name__ == "__main__":
    main()
