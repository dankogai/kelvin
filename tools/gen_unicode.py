#!/usr/bin/env python3 -I
"""gen_unicode.py: the C tables of libkUnicodeData from the Unicode
Character Database in tools/ucd/ (#156). Writes runtime/unicode_tables.c,
the properties, decompositions, compositions and case mappings, and
runtime/unicode_names.c, the names. Rerun after replacing the UCD files.

    python3 -I tools/gen_unicode.py
"""
import os, re, sys
here = os.path.dirname(os.path.abspath(__file__))
ucd = os.path.join(here, 'ucd')
out_dir = os.path.join(os.path.dirname(here), 'runtime')
MAX = 0x110000

def lines(name):
    with open(os.path.join(ucd, name), encoding='utf-8') as f:
        for line in f:
            line = line.split('#', 1)[0].strip()
            if line:
                yield [x.strip() for x in line.split(';')]

def ranges(name):
    """the (lo, hi, value) of a property file whose first field is a codepoint or a range"""
    for fields in lines(name):
        cps, val = fields[0], fields[1]
        if '..' in cps:
            lo, hi = cps.split('..')
            yield int(lo, 16), int(hi, 16), val
        else:
            yield int(cps, 16), int(cps, 16), val

version = 'unknown'
with open(os.path.join(ucd, 'ReadMe.txt'), encoding='utf-8') as f:
    m = re.search(r'Unicode (\d+\.\d+\.\d+)', f.read())
    if m: version = m.group(1)
if version == 'unknown':
    with open(os.path.join(ucd, 'DerivedNormalizationProps.txt'), encoding='utf-8') as f:
        m = re.search(r'DerivedNormalizationProps-(\d+\.\d+\.\d+)', f.read(2000))
        if m: version = m.group(1)

# ---------- UnicodeData.txt ----------
categories = ['Cn', 'Lu', 'Ll', 'Lt', 'Lm', 'Lo', 'Mn', 'Mc', 'Me', 'Nd', 'Nl', 'No', 'Pc', 'Pd', 'Ps', 'Pe', 'Pi', 'Pf', 'Po',
              'Sm', 'Sc', 'Sk', 'So', 'Zs', 'Zl', 'Zp', 'Cc', 'Cf', 'Cs', 'Co']
cat_index = {c: i for i, c in enumerate(categories)}
cat = bytearray(MAX)          # Cn
ccc = bytearray(MAX)
upper = {}; lower = {}; title = {}
decomp = {}                   # cp -> (compat, [cps])
names = {}                    # cp -> name
ranged = []                   # (lo, hi, kind)
mirrored = []                 # Bidi_Mirrored (#157)
first = None
for f in lines('UnicodeData.txt'):
    cp = int(f[0], 16); name = f[1]; gc = f[2]
    if name.endswith(', First>'):
        first = (cp, name[1:-8], gc, int(f[3]))
        continue
    if name.endswith(', Last>'):
        lo, kind, gc0, c0 = first
        for x in range(lo, cp + 1):
            cat[x] = cat_index[gc0]; ccc[x] = c0
        ranged.append((lo, cp, kind)); first = None
        continue
    cat[cp] = cat_index[gc]; ccc[cp] = int(f[3])
    if f[5]:
        parts = f[5].split()
        compat = parts[0].startswith('<')
        if compat: parts = parts[1:]
        decomp[cp] = (compat, [int(p, 16) for p in parts])
    if f[12]: upper[cp] = int(f[12], 16)
    if f[13]: lower[cp] = int(f[13], 16)
    if f[14]: title[cp] = int(f[14], 16)
    if f[9] == 'Y': mirrored.append(cp)
    if not name.startswith('<'):
        names[cp] = name

# ---------- case folding: C and S ----------
fold = {}
for f in lines('CaseFolding.txt'):
    if f[1] in ('C', 'S'):
        fold[int(f[0], 16)] = int(f[2], 16)

# ---------- composition exclusions ----------
excluded = set()
for lo, hi, val in ranges('DerivedNormalizationProps.txt'):
    if val == 'Full_Composition_Exclusion':
        excluded.update(range(lo, hi + 1))

# ---------- grapheme cluster break, extended pictographic, indic conjunct break ----------
gcb_values = ['Other', 'CR', 'LF', 'Control', 'Extend', 'ZWJ', 'Regional_Indicator', 'Prepend', 'SpacingMark',
              'L', 'V', 'T', 'LV', 'LVT', 'Extended_Pictographic']
gcb_index = {v: i for i, v in enumerate(gcb_values)}
gcb = bytearray(MAX)
for lo, hi, val in ranges('GraphemeBreakProperty.txt'):
    for x in range(lo, hi + 1): gcb[x] = gcb_index[val]
for lo, hi, val in ranges('emoji-data.txt'):
    if val == 'Extended_Pictographic':
        for x in range(lo, hi + 1):
            if gcb[x] == 0: gcb[x] = gcb_index['Extended_Pictographic']
incb_values = ['None', 'Consonant', 'Extend', 'Linker']
incb = bytearray(MAX)
for f in lines('DerivedCoreProperties.txt'):
    if len(f) >= 3 and f[1] == 'InCB':
        cps = f[0]
        lo, hi = (cps.split('..') + [None])[:2]
        lo = int(lo, 16); hi = int(hi, 16) if hi else lo
        for x in range(lo, hi + 1): incb[x] = incb_values.index(f[2])

# ---------- two-level tables ----------
def two_level(table, name, ctype='uint8_t'):
    blocks = {}; index = []; data = []
    for b in range(MAX // 256):
        chunk = bytes(table[b * 256:(b + 1) * 256])
        if chunk not in blocks:
            blocks[chunk] = len(blocks); data.append(chunk)
        index.append(blocks[chunk])
    s = [f'static const uint16_t {name}_index[{len(index)}] = {{']
    s.append(','.join(str(i) for i in index))
    s.append('};')
    s.append(f'static const {ctype} {name}_data[{len(data)}][256] = {{')
    for chunk in data:
        s.append('{' + ','.join(str(x) for x in chunk) + '},')
    s.append('};')
    return '\n'.join(s), len(data)

src = [f'/* unicode_tables.c - the Unicode Character Database {version}, as tables (#156): made by',
       '   tools/gen_unicode.py from tools/ucd/; do not edit */',
       '#include <stdint.h>', '#include <stddef.h>', '#include "kUnicodeData.h"', '',
       f'const char *const kv_ud_version = "{version}";', '']
for table, name in ((cat, 'kv_ud_cat'), (ccc, 'kv_ud_ccc'), (gcb, 'kv_ud_gcb'), (incb, 'kv_ud_incb')):
    text, n = two_level(table, name)
    src.append(text)
    src.append(f'uint8_t {name}(uint32_t cp) {{ return cp < 0x110000 ? {name}_data[{name}_index[cp >> 8]][cp & 255] : 0; }}')
    src.append('')
src.append('const char *const kv_ud_categories[%d] = {%s};' % (len(categories), ','.join('"%s"' % c for c in categories)))
src.append('const char *const kv_ud_gcb_names[%d] = {%s};' % (len(gcb_values), ','.join('"%s"' % c for c in gcb_values)))

# decompositions: sorted entries (cp, offset, len, compat), a pool of codepoints
pool = []; entries = []
for cp in sorted(decomp):
    compat, cps = decomp[cp]
    entries.append((cp, len(pool), len(cps), 1 if compat else 0))
    pool.extend(cps)
src.append(f'const uint32_t kv_ud_decomp_pool[{len(pool)}] = {{' + ','.join(str(x) for x in pool) + '};')
src.append(f'const kv_ud_decomp kv_ud_decomps[{len(entries)}] = {{' + ','.join('{%d,%d,%d,%d}' % e for e in entries) + '};')
src.append(f'const size_t kv_ud_decomp_count = {len(entries)};')

# compositions: canonical pairs not excluded
pairs = []
for cp, (compat, cps) in decomp.items():
    if compat or len(cps) != 2 or cp in excluded: continue
    pairs.append((cps[0], cps[1], cp))
pairs.sort()
src.append(f'const kv_ud_pair kv_ud_pairs[{len(pairs)}] = {{' + ','.join('{%d,%d,%d}' % p for p in pairs) + '};')
src.append(f'const size_t kv_ud_pair_count = {len(pairs)};')

def mapping(name, m):
    items = sorted(m.items())
    src.append(f'const kv_ud_map {name}[{len(items)}] = {{' + ','.join('{%d,%d}' % kv for kv in items) + '};')
    src.append(f'const size_t {name}_count = {len(items)};')
mapping('kv_ud_upper', upper); mapping('kv_ud_lower', lower); mapping('kv_ud_title', title); mapping('kv_ud_fold', fold)

# ---------- scripts, script extensions and the binary properties (#157, for \p{...}) ----------
sc_long = {}; sc_short = {}; gc_names = []
for f in lines('PropertyValueAliases.txt'):
    if f[0] == 'sc': sc_long[f[1]] = f[2]; sc_short[f[2]] = f[1]
    if f[0] == 'gc': gc_names.append(f[1:])
script_names = ['Unknown'] + sorted(n for n in sc_short if n != 'Unknown')
script_index = {n: i for i, n in enumerate(script_names)}
assert len(script_names) < 256
script = bytearray(MAX)
for lo, hi, val in ranges('Scripts.txt'):
    for x in range(lo, hi + 1): script[x] = script_index[val]
text, n = two_level(script, 'kv_ud_script')
src.append(text)
src.append('uint8_t kv_ud_script(uint32_t cp) { return cp < 0x110000 ? kv_ud_script_data[kv_ud_script_index[cp >> 8]][cp & 255] : 0; }')
src.append('const char *const kv_ud_script_names[%d][2] = {%s};' % (len(script_names), ','.join('{"%s","%s"}' % (n, sc_short[n]) for n in script_names)))
src.append(f'const size_t kv_ud_script_count = {len(script_names)};')
scx_sets = []; scx_ranges = []
for lo, hi, val in ranges('ScriptExtensions.txt'):
    ids = sorted(script_index[sc_long[x]] for x in val.split())
    if ids not in scx_sets: scx_sets.append(ids)
    scx_ranges.append((lo, hi, scx_sets.index(ids)))
scx_ranges.sort()
scx_pool = []; scx_entries = []
for ids in scx_sets:
    scx_entries.append((len(scx_pool), len(ids))); scx_pool.extend(ids)
src.append(f'const uint8_t kv_ud_scx_pool[{len(scx_pool)}] = {{' + ','.join(str(x) for x in scx_pool) + '};')
src.append(f'const kv_ud_scx_range kv_ud_scx_ranges[{len(scx_ranges)}] = {{' + ','.join('{%d,%d,%d,%d}' % (lo, hi, scx_entries[k][0], scx_entries[k][1]) for lo, hi, k in scx_ranges) + '};')
src.append(f'const size_t kv_ud_scx_range_count = {len(scx_ranges)};')

props = {}
def add_prop(name, lo, hi): props.setdefault(name, []).append((lo, hi))
for lo, hi, val in ranges('PropList.txt'): add_prop(val, lo, hi)
for lo, hi, val in ranges('emoji-data.txt'): add_prop(val, lo, hi)
for f in lines('DerivedCoreProperties.txt'):
    if len(f) == 2:
        lo, hi = (f[0].split('..') + [None])[:2]
        add_prop(f[1], int(lo, 16), int(hi, 16) if hi else int(lo, 16))
for f in lines('DerivedNormalizationProps.txt'):
    if len(f) == 2 and f[1] == 'Changes_When_NFKC_Casefolded':
        lo, hi = (f[0].split('..') + [None])[:2]
        add_prop(f[1], int(lo, 16), int(hi, 16) if hi else int(lo, 16))
for cp in mirrored: add_prop('Bidi_Mirrored', cp, cp)
add_prop('ASCII', 0, 0x7F); add_prop('Any', 0, 0x10FFFF)
start = None
for x in range(MAX + 1):
    assigned = x < MAX and cat[x] != 0
    if assigned and start is None: start = x
    if not assigned and start is not None: add_prop('Assigned', start, x - 1); start = None
# ECMA-262's binary properties, with their aliases
js_binary = [('ASCII', ''), ('ASCII_Hex_Digit', 'AHex'), ('Alphabetic', 'Alpha'), ('Any', ''), ('Assigned', ''),
    ('Bidi_Control', 'Bidi_C'), ('Bidi_Mirrored', 'Bidi_M'), ('Case_Ignorable', 'CI'), ('Cased', ''),
    ('Changes_When_Casefolded', 'CWCF'), ('Changes_When_Casemapped', 'CWCM'), ('Changes_When_Lowercased', 'CWL'),
    ('Changes_When_NFKC_Casefolded', 'CWKCF'), ('Changes_When_Titlecased', 'CWT'), ('Changes_When_Uppercased', 'CWU'),
    ('Dash', ''), ('Default_Ignorable_Code_Point', 'DI'), ('Deprecated', 'Dep'), ('Diacritic', 'Dia'), ('Emoji', ''),
    ('Emoji_Component', 'EComp'), ('Emoji_Modifier', 'EMod'), ('Emoji_Modifier_Base', 'EBase'), ('Emoji_Presentation', 'EPres'),
    ('Extended_Pictographic', 'ExtPict'), ('Extender', 'Ext'), ('Grapheme_Base', 'Gr_Base'), ('Grapheme_Extend', 'Gr_Ext'),
    ('Hex_Digit', 'Hex'), ('IDS_Binary_Operator', 'IDSB'), ('IDS_Trinary_Operator', 'IDST'), ('ID_Continue', 'IDC'),
    ('ID_Start', 'IDS'), ('Ideographic', 'Ideo'), ('Join_Control', 'Join_C'), ('Logical_Order_Exception', 'LOE'),
    ('Lowercase', 'Lower'), ('Math', ''), ('Noncharacter_Code_Point', 'NChar'), ('Pattern_Syntax', 'Pat_Syn'),
    ('Pattern_White_Space', 'Pat_WS'), ('Quotation_Mark', 'QMark'), ('Radical', ''), ('Regional_Indicator', 'RI'),
    ('Sentence_Terminal', 'STerm'), ('Soft_Dotted', 'SD'), ('Terminal_Punctuation', 'Term'), ('Unified_Ideograph', 'UIdeo'),
    ('Uppercase', 'Upper'), ('Variation_Selector', 'VS'), ('White_Space', 'space'), ('XID_Continue', 'XIDC'), ('XID_Start', 'XIDS')]
prop_ranges = []; prop_entries = []
for name, alias in js_binary:
    rs = sorted(props[name]); merged = []
    for lo, hi in rs:
        if merged and lo <= merged[-1][1] + 1: merged[-1] = (merged[-1][0], max(hi, merged[-1][1]))
        else: merged.append((lo, hi))
    prop_entries.append((name, alias, len(prop_ranges), len(merged))); prop_ranges.extend(merged)
src.append(f'const kv_ud_span kv_ud_prop_ranges[{len(prop_ranges)}] = {{' + ','.join('{%d,%d}' % r for r in prop_ranges) + '};')
src.append(f'const kv_ud_prop kv_ud_props[{len(prop_entries)}] = {{' + ','.join('{"%s","%s",%d,%d}' % e for e in prop_entries) + '};')
src.append(f'const size_t kv_ud_prop_count = {len(prop_entries)};')
# the general category by its names: each value, and the groups, as masks over kv_ud_categories
gc_groups = {'L': 'Lu Ll Lt Lm Lo', 'LC': 'Lu Ll Lt', 'M': 'Mn Mc Me', 'N': 'Nd Nl No', 'P': 'Pc Pd Ps Pe Pi Pf Po',
             'S': 'Sm Sc Sk So', 'Z': 'Zs Zl Zp', 'C': 'Cc Cf Cs Co Cn'}
gc_entries = []
for f in gc_names:
    short = f[0]
    members = gc_groups[short].split() if short in gc_groups else [short]
    mask = sum(1 << cat_index[m] for m in members)
    for nm in f:
        gc_entries.append((nm, mask))
src.append(f'const kv_ud_gc_name kv_ud_gc_names[{len(gc_entries)}] = {{' + ','.join('{"%s",%du}' % e for e in gc_entries) + '};')
src.append(f'const size_t kv_ud_gc_name_count = {len(gc_entries)};')

with open(os.path.join(out_dir, 'unicode_tables.c'), 'w') as f:
    f.write('\n'.join(src) + '\n')

# ---------- names ----------
npool = bytearray(); nentries = []
for cp in sorted(names):
    nentries.append((cp, len(npool)))
    npool += names[cp].encode('ascii') + b'\0'
ns = [f'/* unicode_names.c - the names of the Unicode Character Database {version} (#156): made by',
      '   tools/gen_unicode.py from tools/ucd/; do not edit. Its own file, so that a program that',
      '   never asks a name does not link it */',
      '#include <stdint.h>', '#include <stddef.h>', '#include "kUnicodeData.h"', '']
ns.append(f'static const char kv_ud_name_pool[{len(npool) + 1}] = "' + ''.join('\\%03o' % b if b < 32 or b > 126 or b in (34, 92) else chr(b) for b in npool) + '";')
ns.append(f'static const kv_ud_name_entry kv_ud_name_entries[{len(nentries)}] = {{' + ','.join('{%d,%d}' % e for e in nentries) + '};')
ns.append(f'static const size_t kv_ud_name_count = {len(nentries)};')
ns.append('static const kv_ud_range kv_ud_name_ranges[%d] = {%s};' % (len(ranged), ','.join('{%d,%d,"%s"}' % r for r in ranged)))
ns.append(f'static const size_t kv_ud_name_range_count = {len(ranged)};')
ns.append('''
/* the name of a codepoint: from the table, or by the rule of a range, Hangul
   syllables and the ideographs; "" where there is none */
#include <stdio.h>
#include <string.h>
static const char *jamo_l[] = {"G","GG","N","D","DD","R","M","B","BB","S","SS","","J","JJ","C","K","T","P","H"};
static const char *jamo_v[] = {"A","AE","YA","YAE","EO","E","YEO","YE","O","WA","WAE","OE","YO","U","WEO","WE","WI","YU","EU","YI","I"};
static const char *jamo_t[] = {"","G","GG","GS","N","NJ","NH","D","L","LG","LM","LB","LS","LT","LP","LH","M","B","BS","S","SS","NG","J","C","K","T","P","H"};
const char *kv_ud_name(uint32_t cp, char *buf, size_t max) {
    size_t lo = 0, hi = kv_ud_name_count;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        if (kv_ud_name_entries[mid].cp < cp) lo = mid + 1; else hi = mid;
    }
    if (lo < kv_ud_name_count && kv_ud_name_entries[lo].cp == cp)
        return kv_ud_name_pool + kv_ud_name_entries[lo].offset;
    if (cp >= 0xAC00 && cp <= 0xD7A3) {
        uint32_t s = cp - 0xAC00;
        snprintf(buf, max, "HANGUL SYLLABLE %s%s%s", jamo_l[s / 588], jamo_v[(s % 588) / 28], jamo_t[s % 28]);
        return buf;
    }
    for (size_t i = 0; i < kv_ud_name_range_count; i++) {
        if (cp < kv_ud_name_ranges[i].lo || cp > kv_ud_name_ranges[i].hi) continue;
        const char *k = kv_ud_name_ranges[i].kind;
        if (!strncmp(k, "CJK Ideograph", 13)) snprintf(buf, max, "CJK UNIFIED IDEOGRAPH-%04X", cp);
        else if (!strncmp(k, "Tangut Ideograph", 16)) snprintf(buf, max, "TANGUT IDEOGRAPH-%04X", cp);
        else if (!strncmp(k, "Nushu", 5)) snprintf(buf, max, "NUSHU CHARACTER-%04X", cp);
        else if (!strncmp(k, "Khitan", 6)) snprintf(buf, max, "KHITAN SMALL SCRIPT CHARACTER-%04X", cp);
        else return "";
        return buf;
    }
    return "";
}''')
with open(os.path.join(out_dir, 'unicode_names.c'), 'w') as f:
    f.write('\n'.join(ns) + '\n')
print('Unicode', version, 'names', len(names), 'decomps', len(entries), 'pairs', len(pairs), 'fold', len(fold), 'ranges', len(ranged),
      'scripts', len(script_names), 'scx', len(scx_ranges), 'props', len(prop_entries), 'gc names', len(gc_entries))
