#!/usr/bin/env python3 -I
"""gen_ident.py: the codepoints a Kelvin name may hold beyond ASCII (#385),
from the Unicode Character Database in tools/ucd/: UAX #31's XID_Start
and XID_Continue, and emoji, Extended_Pictographic and its components
(U+FE0F, ZWJ, skin tones, keycaps, tags, regional indicators). Writes
src/ident.c, kelvinc's, and selfhost/ident.k, kc's, the same ranges.
Rerun after replacing the UCD files.

    python3 -I tools/gen_ident.py
"""
import os
here = os.path.dirname(os.path.abspath(__file__))
top = os.path.dirname(here)
ucd = os.path.join(here, 'ucd')


def ranges(name, want):
    """the (lo, hi) of a property file's lines whose value is want"""
    out = []
    with open(os.path.join(ucd, name), encoding='utf-8') as f:
        for line in f:
            line = line.split('#', 1)[0].strip()
            if not line:
                continue
            fields = [x.strip() for x in line.split(';')]
            if fields[1] != want:
                continue
            if '..' in fields[0]:
                lo, hi = fields[0].split('..')
                out.append((int(lo, 16), int(hi, 16)))
            else:
                out.append((int(fields[0], 16), int(fields[0], 16)))
    return out


def merge(rs):
    """the ranges past ASCII, sorted, the touching ones joined"""
    out = []
    for lo, hi in sorted((max(lo, 0x80), hi) for lo, hi in rs if hi >= 0x80):
        if out and lo <= out[-1][1] + 1:
            out[-1] = (out[-1][0], max(out[-1][1], hi))
        else:
            out.append((lo, hi))
    return out


pict = ranges('emoji-data.txt', 'Extended_Pictographic')
flags = [(0x1F1E6, 0x1F1FF)]
starts = merge(ranges('DerivedCoreProperties.txt', 'XID_Start') + pict + flags)
conts = merge(ranges('DerivedCoreProperties.txt', 'XID_Continue') + pict + flags +
              ranges('emoji-data.txt', 'Emoji_Component'))


def flat(rs):
    xs = [str(x) for lo, hi in rs for x in (lo, hi)]
    return [', '.join(xs[i:i + 12]) for i in range(0, len(xs), 12)]


c = ['/* src/ident.c - the codepoints a Kelvin name may hold beyond ASCII (#385):',
     '   UAX #31\'s XID_Start and XID_Continue, and emoji. Written by',
     '   tools/gen_ident.py from tools/ucd/; do not edit. */',
     '#include "kelvin.h"', '']
for name, rs in (('starts', starts), ('conts', conts)):
    c.append('static const uint32_t ident_%s[] = {' % name)
    c += ['    %s,' % row for row in flat(rs)]
    c.append('};')
    c.append('')
c += ['/* whether c is in the ranges at[0..2n), lo and hi by turns */',
      'static bool in_ranges(const uint32_t *at, size_t n, uint32_t c) {',
      '    size_t lo = 0, hi = n;',
      '    while (lo < hi) {',
      '        size_t m = (lo + hi) / 2;',
      '        if (at[2 * m + 1] < c)',
      '            lo = m + 1;',
      '        else',
      '            hi = m;',
      '    }',
      '    return lo < n && at[2 * lo] <= c;',
      '}', '',
      '/* whether c, past ASCII, may begin a name, and may go on with one */',
      'bool ident_start(uint32_t c) { return in_ranges(ident_starts, sizeof ident_starts / sizeof ident_starts[0] / 2, c); }',
      'bool ident_continue(uint32_t c) { return in_ranges(ident_conts, sizeof ident_conts / sizeof ident_conts[0] / 2, c); }']
with open(os.path.join(top, 'src', 'ident.c'), 'w') as f:
    f.write('\n'.join(c) + '\n')

k = ['// selfhost/ident.k - the codepoints a Kelvin name may hold beyond ASCII',
     '// (#385): UAX #31\'s XID_Start and XID_Continue, and emoji, as kelvinc\'s',
     '// src/ident.c. Written by tools/gen_ident.py from tools/ucd/; do not edit.', '']
for name, rs in (('starts', starts), ('conts', conts)):
    k.append('let ident_%s:[int64] = [' % name)
    rows = flat(rs)
    k += ['    %s%s' % (row, ',' if i + 1 < len(rows) else '') for i, row in enumerate(rows)]
    k.append(']')
    k.append('')
for name, rs in (('start', starts), ('continue', conts)):
    table = 'ident_starts' if name == 'start' else 'ident_conts'
    k += ['// whether c, past ASCII, may %s a name' % ('begin' if name == 'start' else 'go on with'),
          'let ident_%s(c:int64):bool {' % name,
          '    var lo:int64 = 0',
          '    var hi:int64 = %d' % len(rs),
          '    while lo < hi {',
          '        let m:int64 = (lo + hi) / 2',
          '        if %s[2 * m + 1] < c {' % table,
          '            lo = m + 1',
          '        } else {',
          '            hi = m',
          '        }',
          '    }',
          '    return lo < %d && %s[2 * lo] <= c' % (len(rs), table),
          '}', '']
with open(os.path.join(top, 'selfhost', 'ident.k'), 'w') as f:
    f.write('\n'.join(k))
