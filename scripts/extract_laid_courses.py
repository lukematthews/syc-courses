import json
import re
from pathlib import Path
import fitz

PDF_PATH = Path('source/Club-sailing-Instructions-2025-28_Rev-0.pdf')
CHART_DIR = Path('public/course-charts')
OUT_JSON = Path('source/extracted-laid-courses.json')
CELL_INSET = 1.4

def clean(text):
    return ' '.join(text.replace('–', '-').split())

def route_to_rows(route):
    route = clean(route)
    if route.lower().startswith('start - '):
        body = route
    else:
        body = route
    parts = [part.strip() for part in re.split(r'\s*-\s*', body) if part.strip()]
    rows = []
    for part in parts:
        normalized = part.title() if part.lower() in {'start', 'finish', 'gate'} else part
        if normalized == 'Start':
            side = 'Pass'
        elif normalized == 'Finish':
            side = 'Finish'
        elif normalized == 'Gate':
            side = 'Pass'
        else:
            side = 'Port'
        rows.append({'mark': normalized, 'side': side, 'bearing': '', 'distance': ''})
    return rows

doc=fitz.open(PDF_PATH)
courses=[]
CHART_DIR.mkdir(parents=True, exist_ok=True)

def table_lines(page):
    horizontal = []
    vertical = []
    for drawing in page.get_drawings():
        rect = drawing.get('rect')
        if not rect:
            continue
        if rect.width > 100 and rect.height < 2:
            horizontal.append(rect)
        elif rect.height > 10 and rect.width < 2:
            vertical.append(rect)
    return horizontal, vertical

def diagram_cell(page, title_y, region_end):
    horizontal, vertical = table_lines(page)
    region_vertical = [
        line for line in vertical
        if line.y0 > title_y
        and line.y0 < region_end
        and line.y1 > title_y
        and line.x0 <= 540
    ]
    divider_candidates = [line for line in region_vertical if 180 <= line.x0 <= 260]
    right_candidates = [line for line in region_vertical if 500 <= line.x0 <= 540]
    if not divider_candidates or not right_candidates:
        return fitz.Rect(248, max(80, title_y + 17), 532, region_end - 21)

    def total_height(lines):
        return sum(max(0, min(line.y1, region_end) - max(line.y0, title_y)) for line in lines)

    divider_x = max(
        {round(line.x0, 1) for line in divider_candidates},
        key=lambda x: total_height([line for line in divider_candidates if round(line.x0, 1) == x]),
    )
    right_x = max(
        {round(line.x0, 1) for line in right_candidates},
        key=lambda x: total_height([line for line in right_candidates if round(line.x0, 1) == x]),
    )
    divider = next(line for line in divider_candidates if round(line.x0, 1) == divider_x)
    right = next(line for line in right_candidates if round(line.x0, 1) == right_x)

    cell_lines = [
        line for line in horizontal
        if line.x0 <= divider.x0 + 2
        and line.x1 >= right.x0 - 2
        and line.y0 > title_y + 10
        and line.y0 < region_end
    ]
    if len(cell_lines) < 2:
        return fitz.Rect(divider.x1 + CELL_INSET, max(80, title_y + 17), right.x0 - CELL_INSET, region_end - 21)

    top = min(cell_lines, key=lambda line: line.y0)
    bottom = max(cell_lines, key=lambda line: line.y0)
    return fitz.Rect(
        divider.x1 + CELL_INSET,
        top.y1 + CELL_INSET,
        right.x0 - CELL_INSET,
        bottom.y0 - CELL_INSET,
    )

for pno in range(19, len(doc)):
    page=doc[pno]
    blocks=[]
    for b in page.get_text('blocks'):
        x0,y0,x1,y1,text,*_=b
        c=clean(text)
        if c:
            blocks.append({'x0':x0,'y0':y0,'x1':x1,'y1':y1,'text':c})
    titles=[]
    for b in blocks:
        m=re.fullmatch(r'Course (\d+)', b['text'])
        if m:
            n=int(m.group(1))
            if 80 <= n <= 98:
                titles.append((n,b))
    titles.sort(key=lambda item:item[1]['y0'])
    for idx,(number,title) in enumerate(titles):
        next_y = titles[idx+1][1]['y0'] if idx+1 < len(titles) else None
        region_end = next_y - 18 if next_y is not None else (360 if pno == 28 else 740)
        text_blocks=[b for b in blocks if b['x0'] < 260 and title['y0'] < b['y0'] < region_end]
        text_blocks.sort(key=lambda b:b['y0'])
        route = text_blocks[0]['text'] if text_blocks else ''
        leave = next((b['text'] for b in text_blocks if b['text'].lower().startswith('leave')), '')
        gate_note = next((b['text'] for b in text_blocks if b['text'].lower().startswith('pass through')), '')
        note = next((b['text'] for b in text_blocks if b['text'].lower().startswith('note:')), '')
        nominal = next((b['text'] for b in text_blocks if b['text'].lower().startswith('nominal')), '')
        pass_instruction = ' '.join(part for part in [leave, gate_note, note] if part)
        nominal = nominal.replace('Nominal leg length:', 'Nominal leg length:').replace(' - ', ' - ')
        pix=page.get_pixmap(
            matrix=fitz.Matrix(3,3),
            clip=diagram_cell(page, title['y0'], region_end),
            alpha=False,
        )
        chart_name=f'course-{number}.png'
        pix.save(CHART_DIR/chart_name)
        courses.append({
            'courseNumber': number,
            'route': route,
            'passInstruction': pass_instruction,
            'totalDistance': nominal,
            'chartImage': f'/course-charts/{chart_name}',
            'chartAlt': f'Course {number} laid mark course diagram from Appendix A.4 page {pno+1}.',
            'dataStatus': 'verified-from-pdf',
            'sourcePage': pno+1,
            'rows': route_to_rows(route),
        })
OUT_JSON.write_text(json.dumps(courses, indent=2), encoding='utf-8')
print('laid courses', len(courses), [c['courseNumber'] for c in courses])
