import json
import re
from pathlib import Path
import fitz

PDF_PATH = Path('source/Club-sailing-Instructions-2025-28_Rev-0.pdf')
CHART_DIR = Path('public/course-charts')
OUT_JSON = Path('source/extracted-laid-courses.json')

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
        crop_top=max(80, title['y0']-4)
        crop_bottom=region_end+8
        pix=page.get_pixmap(matrix=fitz.Matrix(3,3), clip=fitz.Rect(60, crop_top, 535, crop_bottom), alpha=False)
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
