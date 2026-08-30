/**
 * Render the build plan markdown into a Word document matching the styling of
 * the existing 01-09 handoff documents (Arial, US Letter, navy headings,
 * pale-blue table headers).
 *
 * One source of truth: edit the .md, re-run this, and both stay in sync.
 *
 *   node scripts/md_to_docx.js input.md "output.docx" "Title" "Subtitle"
 */

const fs = require('fs');
const d = require('docx');
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType,
  Table, TableRow, TableCell, WidthType, ShadingType, BorderStyle, LevelFormat,
} = d;

const FONT = 'Arial';
const MONO = 'Consolas';
const W = 9360;                 // usable width: Letter with 1" margins
const NAVY = '17365d';
const MID = '366091';
const ACCENT = '4f81bd';
const HDR_FILL = 'd9eaf7';
const BOX_FILL = 'eaf2ff';

const [, , mdPath, outPath, docTitle, docSubtitle] = process.argv;
const lines = fs.readFileSync(mdPath, 'utf8').split('\n');

const kids = [];
const push = (...x) => kids.push(...x);

// ---- inline: **bold**, `code`, *italic* -----------------------------------
function runs(text, size = 21, base = {}) {
  const out = [];
  const re = /(\*\*[^*]+\*\*|`[^`]+`|\*[^*]+\*)/g;
  let last = 0, m;
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) {
      out.push(new TextRun({ text: text.slice(last, m.index), font: FONT, size, ...base }));
    }
    const tok = m[0];
    if (tok.startsWith('**')) {
      // Recurse: bold spans routinely contain `code`, and a single pass would
      // render the backticks literally.
      out.push(...runs(tok.slice(2, -2), size, { ...base, bold: true }));
    } else if (tok.startsWith('`')) {
      out.push(new TextRun({
        ...base, text: tok.slice(1, -1), font: MONO, size: size - 2,
        color: base.color || '2a4b6b',
      }));
    } else {
      out.push(...runs(tok.slice(1, -1), size, { ...base, italics: true }));
    }
    last = re.lastIndex;
  }
  if (last < text.length) {
    out.push(new TextRun({ text: text.slice(last), font: FONT, size, ...base }));
  }
  return out.length ? out : [new TextRun({ text: '', font: FONT, size, ...base })];
}

function spacer(after = 140) {
  push(new Paragraph({ spacing: { after }, children: [new TextRun({ text: '', size: 8 })] }));
}

function allBorders(color) {
  const b = { style: BorderStyle.SINGLE, size: 4, color };
  return { top: b, bottom: b, left: b, right: b, insideHorizontal: b, insideVertical: b };
}

function codeBlock(body) {
  const rows = body.map(line => new Paragraph({
    spacing: { line: 240, after: 0 },
    children: [new TextRun({ text: line || ' ', font: MONO, size: 17, color: '1f3348' })],
  }));
  push(new Table({
    width: { size: W, type: WidthType.DXA },
    columnWidths: [W],
    borders: allBorders('c7d9ec'),
    rows: [new TableRow({
      children: [new TableCell({
        width: { size: W, type: WidthType.DXA },
        shading: { type: ShadingType.CLEAR, fill: 'f4f8fc', color: 'auto' },
        margins: { top: 120, bottom: 120, left: 160, right: 160 },
        children: rows,
      })],
    })],
  }));
  spacer();
}

function callout(text) {
  push(new Table({
    width: { size: W, type: WidthType.DXA },
    columnWidths: [W],
    borders: {
      top: { style: BorderStyle.SINGLE, size: 2, color: ACCENT },
      bottom: { style: BorderStyle.SINGLE, size: 2, color: ACCENT },
      left: { style: BorderStyle.SINGLE, size: 18, color: ACCENT },
      right: { style: BorderStyle.SINGLE, size: 2, color: ACCENT },
      insideHorizontal: { style: BorderStyle.NONE, size: 0, color: 'auto' },
      insideVertical: { style: BorderStyle.NONE, size: 0, color: 'auto' },
    },
    rows: [new TableRow({
      children: [new TableCell({
        width: { size: W, type: WidthType.DXA },
        shading: { type: ShadingType.CLEAR, fill: BOX_FILL, color: 'auto' },
        margins: { top: 140, bottom: 140, left: 200, right: 200 },
        children: [new Paragraph({ children: runs(text) })],
      })],
    })],
  }));
  spacer();
}

function splitRow(line) {
  return line.replace(/^\||\|$/g, '').split('|').map(c => c.trim());
}

function renderTable(block) {
  const header = splitRow(block[0]);
  const aligns = splitRow(block[1]).map(spec => {
    if (/^-+:$/.test(spec)) return 'r';
    if (/^:-+:$/.test(spec)) return 'c';
    return 'l';
  });
  const body = block.slice(2).map(splitRow);

  // Weight columns by their widest cell so text tables do not collapse.
  const cols = header.length;
  const weights = new Array(cols).fill(1);
  for (let i = 0; i < cols; i++) {
    const widest = Math.max(
      (header[i] || '').length,
      ...body.map(r => (r[i] || '').length),
    );
    weights[i] = Math.max(6, Math.min(widest, 60));
  }
  const total = weights.reduce((a, b) => a + b, 0);
  const widths = weights.map(w => Math.round(W * w / total));
  widths[cols - 1] = W - widths.slice(0, -1).reduce((a, b) => a + b, 0);

  const cell = (text, i, isHeader) => new TableCell({
    width: { size: widths[i], type: WidthType.DXA },
    shading: { type: ShadingType.CLEAR, fill: isHeader ? HDR_FILL : 'ffffff', color: 'auto' },
    margins: { top: 70, bottom: 70, left: 110, right: 110 },
    children: [new Paragraph({
      alignment: aligns[i] === 'r' ? AlignmentType.RIGHT
        : aligns[i] === 'c' ? AlignmentType.CENTER : AlignmentType.LEFT,
      spacing: { after: 0 },
      children: runs(text || '', 19, isHeader ? { bold: true, color: NAVY } : {}),
    })],
  });

  push(new Table({
    width: { size: W, type: WidthType.DXA },
    columnWidths: widths,
    borders: allBorders('b8cce4'),
    rows: [
      new TableRow({ tableHeader: true, children: header.map((t, i) => cell(t, i, true)) }),
      ...body.map(r => new TableRow({
        children: Array.from({ length: cols }, (_, i) => cell(r[i], i, false)),
      })),
    ],
  }));
  spacer();
}

// ---- title block ----------------------------------------------------------
push(new Paragraph({
  spacing: { after: 40 },
  children: [new TextRun({ text: 'SukaSeafood', font: FONT, size: 44, bold: true, color: NAVY })],
}));
push(new Paragraph({
  spacing: { after: 40 },
  children: [new TextRun({ text: docTitle, font: FONT, size: 30, color: MID })],
}));
push(new Paragraph({
  spacing: { after: 220 },
  children: [new TextRun({ text: docSubtitle, font: FONT, size: 21, italics: true, color: '555555' })],
}));

// ---- walk the markdown ----------------------------------------------------
let i = 0;
let seenTitle = false;
let pendingPara = [];

function flushPara() {
  if (!pendingPara.length) return;
  push(new Paragraph({ spacing: { after: 120 }, children: runs(pendingPara.join(' ')) }));
  pendingPara = [];
}

while (i < lines.length) {
  const line = lines[i];
  const trimmed = line.trim();

  // fenced code
  if (trimmed.startsWith('```')) {
    flushPara();
    const body = [];
    i++;
    while (i < lines.length && !lines[i].trim().startsWith('```')) body.push(lines[i++]);
    i++;
    codeBlock(body);
    continue;
  }

  // table
  if (trimmed.startsWith('|') && i + 1 < lines.length && /^\|[\s:|-]+\|$/.test(lines[i + 1].trim())) {
    flushPara();
    const block = [];
    while (i < lines.length && lines[i].trim().startsWith('|')) block.push(lines[i++].trim());
    renderTable(block);
    continue;
  }

  // headings
  if (/^#{1,4}\s/.test(trimmed)) {
    flushPara();
    const level = trimmed.match(/^#+/)[0].length;
    const text = trimmed.replace(/^#+\s*/, '');
    if (level === 1 && !seenTitle) {
      // The title block is already rendered above. Consume the lines of
      // front matter that follow it (subtitle, status, date) and show them
      // as a compact metadata strip rather than as body prose.
      seenTitle = true;
      i++;
      const meta = [];
      while (i < lines.length && !/^---+$/.test(lines[i].trim())) {
        if (lines[i].trim()) meta.push(lines[i].trim());
        i++;
      }
      if (meta.length) {
        // Drop the first line: it restates the title.
        for (const line of meta.slice(1)) {
          push(new Paragraph({
            spacing: { after: 40 },
            children: runs(line, 19, { color: '555555' }),
          }));
        }
        spacer(200);
      }
      continue;
    }
    const big = level <= 2;
    push(new Paragraph({
      heading: big ? HeadingLevel.HEADING_1 : HeadingLevel.HEADING_2,
      spacing: { before: big ? 360 : 260, after: big ? 140 : 100 },
      children: runs(text, big ? 30 : 24, { bold: true, color: big ? NAVY : MID }),
    }));
    i++;
    continue;
  }

  // blockquote -> callout
  if (trimmed.startsWith('> ')) {
    flushPara();
    const body = [];
    while (i < lines.length && lines[i].trim().startsWith('>')) {
      body.push(lines[i++].trim().replace(/^>\s?/, ''));
    }
    callout(body.join(' '));
    continue;
  }

  // horizontal rule -> ignore (headings already carry the separation)
  if (/^---+$/.test(trimmed)) { flushPara(); i++; continue; }

  // A list item may wrap over several source lines. Everything up to the next
  // blank line or block marker belongs to the same item — otherwise the tail of
  // a wrapped bullet escapes the list and renders as a stray paragraph.
  const isBlockStart = (t) =>
    t === '' || /^#{1,4}\s/.test(t) || t.startsWith('```') || t.startsWith('|') ||
    t.startsWith('> ') || /^---+$/.test(t) || /^[-*]\s+/.test(t) || /^\d+\.\s+/.test(t);

  const bulletMatch = /^[-*]\s+/.test(trimmed);
  const numberMatch = /^\d+\.\s+/.test(trimmed);
  if (bulletMatch || numberMatch) {
    flushPara();
    const indent = line.match(/^\s*/)[0].length;
    const parts = [trimmed.replace(bulletMatch ? /^[-*]\s+/ : /^\d+\.\s+/, '')];
    i++;
    while (i < lines.length && !isBlockStart(lines[i].trim())) {
      parts.push(lines[i].trim());
      i++;
    }
    push(new Paragraph({
      numbering: {
        reference: bulletMatch ? 'suka-bullets' : 'suka-numbers',
        level: bulletMatch && indent >= 2 ? 1 : 0,
      },
      spacing: { after: 60 },
      children: runs(parts.join(' ')),
    }));
    continue;
  }

  if (trimmed === '') { flushPara(); i++; continue; }

  pendingPara.push(trimmed);
  i++;
}
flushPara();

// ---- build ----------------------------------------------------------------
const doc = new Document({
  creator: 'SukaSeafood I1',
  title: docTitle,
  description: docSubtitle,
  numbering: {
    config: [
      {
        reference: 'suka-bullets',
        levels: [
          { level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 400, hanging: 220 } }, run: { font: FONT, size: 21 } } },
          { level: 1, format: LevelFormat.BULLET, text: '◦', alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 760, hanging: 220 } }, run: { font: FONT, size: 21 } } },
        ],
      },
      {
        reference: 'suka-numbers',
        levels: [
          { level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 400, hanging: 260 } }, run: { font: FONT, size: 21 } } },
        ],
      },
    ],
  },
  styles: {
    default: {
      document: {
        run: { font: FONT, size: 21, color: '1a1a1a' },
        paragraph: { spacing: { line: 276 } },
      },
    },
  },
  sections: [{
    properties: {
      page: {
        size: { width: 12240, height: 15840 },
        margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
      },
    },
    children: kids,
  }],
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync(outPath, buf);
  console.log(`wrote ${outPath} (${buf.length.toLocaleString()} bytes)`);
});
