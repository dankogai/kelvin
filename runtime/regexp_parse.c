/* regexp_parse.c - the parser of a pattern of #import <RegExp> (#157): JS's
   syntax with the u flag, read into a tree that runtime/regexp.c compiles
   and runs. On its own, with the Unicode tables, it checks a pattern:
   kelvinc links it to read a $/.../ literal at compile time (#163), where
   an error returns to the caller instead of ending the program. */
#include "regexp_internal.h"
#include "kUnicodeData.h"
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* where rx_check waits for an error, and what it was */
static jmp_buf *rx_catch;
static char rx_msg[256];
static size_t rx_at;

void rx_fail(const uint8_t *pattern, const char *what, size_t at) {
    if (rx_catch) {
        snprintf(rx_msg, sizeof rx_msg, "%s", what);
        rx_at = at;
        longjmp(*rx_catch, 1);
    }
    fflush(stdout);
    fprintf(stderr, "kelvin: RegExp: %s in /%s/ at %zu\n", what, (const char *)pattern, at);
    abort();
}

void *rx_alloc(size_t n) {
    void *p = malloc(n ? n : 1);
    if (!p) {
        fputs("kelvin: out of memory\n", stderr);
        abort();
    }
    memset(p, 0, n);
    return p;
}

void *rx_grow(void *p, size_t n) {
    p = realloc(p, n);
    if (!p) {
        fputs("kelvin: out of memory\n", stderr);
        abort();
    }
    return p;
}

/* ---------- UTF-8 ---------- */

/* the codepoint at p[pos], and its length; NO_CP at the end */
uint32_t rx_cp_at(const uint8_t *p, int64_t n, int64_t pos, int *len) {
    if (pos >= n) {
        *len = 0;
        return NO_CP;
    }
    uint8_t c = p[pos];
    if (c < 0x80) {
        *len = 1;
        return c;
    }
    int l = c < 0xE0 ? 2 : c < 0xF0 ? 3 : 4;
    if (pos + l > n)
        l = (int)(n - pos);
    uint32_t cp = c & (l == 2 ? 0x1F : l == 3 ? 0x0F : 0x07);
    for (int k = 1; k < l; k++)
        cp = (cp << 6) | (p[pos + k] & 0x3F);
    *len = l;
    return cp;
}

/* the codepoint before p[pos], and its length; NO_CP at the start */
uint32_t rx_cp_before(const uint8_t *p, int64_t n, int64_t pos, int *len) {
    if (pos <= 0) {
        *len = 0;
        return NO_CP;
    }
    int64_t k = pos - 1;
    while (k > 0 && (p[k] & 0xC0) == 0x80)
        k--;
    return rx_cp_at(p, n, k, len);
}

int rx_utf8_put(uint8_t *out, uint32_t cp) {
    if (cp < 0x80) {
        out[0] = (uint8_t)cp;
        return 1;
    }
    if (cp < 0x800) {
        out[0] = (uint8_t)(0xC0 | (cp >> 6));
        out[1] = (uint8_t)(0x80 | (cp & 0x3F));
        return 2;
    }
    if (cp < 0x10000) {
        out[0] = (uint8_t)(0xE0 | (cp >> 12));
        out[1] = (uint8_t)(0x80 | ((cp >> 6) & 0x3F));
        out[2] = (uint8_t)(0x80 | (cp & 0x3F));
        return 3;
    }
    out[0] = (uint8_t)(0xF0 | (cp >> 18));
    out[1] = (uint8_t)(0x80 | ((cp >> 12) & 0x3F));
    out[2] = (uint8_t)(0x80 | ((cp >> 6) & 0x3F));
    out[3] = (uint8_t)(0x80 | (cp & 0x3F));
    return 4;
}

/* ---------- the tree ---------- */

static uint32_t node_flags; /* the flags where parsing is, for new nodes */

static Node *node_new(int kind, size_t at) {
    Node *n = rx_alloc(sizeof *n);
    n->kind = kind;
    n->at = at;
    n->max = 1;
    n->min = 1;
    n->greedy = true;
    n->flags = node_flags;
    return n;
}

void rx_node_free(Node *n) {
    if (!n)
        return;
    for (int i = 0; i < n->nkids; i++)
        rx_node_free(n->kids[i]);
    free(n->kids);
    free(n->items);
    free(n->name);
    free(n);
}

static void add_kid(Node *n, Node *k) {
    if (n->nkids == n->kcap) {
        n->kcap = n->kcap ? n->kcap * 2 : 4;
        n->kids = rx_grow(n->kids, (size_t)n->kcap * sizeof *n->kids);
    }
    n->kids[n->nkids++] = k;
}

static void add_item(Node *n, uint32_t kind, uint32_t a, uint32_t b) {
    if (n->nitems == n->icap) {
        n->icap = n->icap ? n->icap * 2 : 4;
        n->items = rx_grow(n->items, (size_t)n->icap * sizeof *n->items);
    }
    n->items[n->nitems++] = (Item){kind, a, b};
}

/* ---------- the parser ---------- */

/* the names of \p{...}, looked up in the tables of libkUnicodeData, which
   are data alone, so that kelvinc links them to check a literal (#163) */
static uint32_t category_mask(const char *name) {
    for (size_t i = 0; i < kv_ud_gc_name_count; i++)
        if (!strcmp(name, kv_ud_gc_names[i].name))
            return kv_ud_gc_names[i].mask;
    return 0;
}

static int script_id(const char *name) {
    for (size_t i = 0; i < kv_ud_script_count; i++)
        if (!strcmp(name, kv_ud_script_names[i][0]) || !strcmp(name, kv_ud_script_names[i][1]))
            return (int)i;
    return -1;
}

static int property_id(const char *name) {
    for (size_t i = 0; i < kv_ud_prop_count; i++)
        if (!strcmp(name, kv_ud_props[i].name) || (*kv_ud_props[i].alias && !strcmp(name, kv_ud_props[i].alias)))
            return (int)i;
    return -1;
}

static Node *parse_alt(Parser *p);

static int peekc(Parser *p) { return p->i < p->len ? p->pat[p->i] : -1; }
static int peekc2(Parser *p) { return p->i + 1 < p->len ? p->pat[p->i + 1] : -1; }
static bool accept(Parser *p, int c) {
    if (peekc(p) == c) {
        p->i++;
        return true;
    }
    return false;
}

static uint32_t next_cp(Parser *p) {
    int len;
    uint32_t c = rx_cp_at(p->pat, (int64_t)p->len, (int64_t)p->i, &len);
    p->i += (size_t)len;
    return c;
}

static int hexval(int c) {
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

static bool parse_hex(Parser *p, int digits, uint32_t *out) {
    uint32_t v = 0;
    for (int k = 0; k < digits; k++) {
        int h = hexval(peekc(p));
        if (h < 0)
            return false;
        v = v * 16 + (uint32_t)h;
        p->i++;
    }
    *out = v;
    return true;
}

/* \u{...} and \uHHHH, a surrogate pair joined; after the 'u' */
static uint32_t parse_unicode_escape(Parser *p, size_t at) {
    uint32_t v;
    if (accept(p, '{')) {
        size_t start = p->i;
        v = 0;
        while (hexval(peekc(p)) >= 0) {
            v = v * 16 + (uint32_t)hexval(peekc(p));
            if (v > 0x10FFFF)
                rx_fail(p->pat, "a \\u{...} escape beyond U+10FFFF", at);
            p->i++;
        }
        if (p->i == start || !accept(p, '}'))
            rx_fail(p->pat, "a \\u{...} escape needs hex digits and '}'", at);
        return v;
    }
    if (!parse_hex(p, 4, &v))
        rx_fail(p->pat, "a \\u escape needs four hex digits, or \\u{...}", at);
    if (v >= 0xD800 && v <= 0xDBFF && peekc(p) == '\\' && peekc2(p) == 'u') {
        size_t save = p->i;
        uint32_t lo;
        p->i += 2;
        if (parse_hex(p, 4, &lo) && lo >= 0xDC00 && lo <= 0xDFFF)
            return 0x10000 + ((v - 0xD800) << 10) + (lo - 0xDC00);
        p->i = save;
    }
    return v;
}

/* \p{...} after the 'p' or 'P': a class item */
static void parse_property(Parser *p, Node *cls, bool negate, size_t at) {
    if (!accept(p, '{'))
        rx_fail(p->pat, "\\p needs {...}: \\p{Letter}, \\p{Script=Greek}", at);
    char name[64], value[64];
    size_t n = 0;
    bool has_value = false;
    size_t v = 0;
    for (;;) {
        int c = peekc(p);
        if (c < 0)
            rx_fail(p->pat, "unterminated \\p{...}", at);
        p->i++;
        if (c == '}')
            break;
        if (c == '=' && !has_value) {
            has_value = true;
            continue;
        }
        if (has_value) {
            if (v + 1 >= sizeof value)
                rx_fail(p->pat, "a property value too long", at);
            value[v++] = (char)c;
        } else {
            if (n + 1 >= sizeof name)
                rx_fail(p->pat, "a property name too long", at);
            name[n++] = (char)c;
        }
    }
    name[n] = 0;
    value[v] = 0;
    if (has_value) {
        if (!strcmp(name, "General_Category") || !strcmp(name, "gc")) {
            uint32_t mask = category_mask(value);
            if (!mask)
                rx_fail(p->pat, "an unknown General_Category in \\p{...}", at);
            add_item(cls, CI_GC, mask, negate);
            return;
        }
        bool scx = !strcmp(name, "Script_Extensions") || !strcmp(name, "scx");
        if (scx || !strcmp(name, "Script") || !strcmp(name, "sc")) {
            int id = script_id(value);
            if (id < 0)
                rx_fail(p->pat, "an unknown Script in \\p{...}", at);
            add_item(cls, CI_SCRIPT, (uint32_t)id, (negate ? 1u : 0u) | (scx ? 2u : 0u));
            return;
        }
        rx_fail(p->pat, "\\p{name=value} takes General_Category, Script or Script_Extensions", at);
    }
    uint32_t mask = category_mask(name);
    if (mask) {
        add_item(cls, CI_GC, mask, negate);
        return;
    }
    int id = property_id(name);
    if (id < 0)
        rx_fail(p->pat, "an unknown property in \\p{...}", at);
    add_item(cls, CI_PROP, (uint32_t)id, negate);
}

/* an escape after the backslash, in a class or out of it: 0 and *cp a
   character, 1 an item added to cls, 2 a node in *out */
static int parse_escape(Parser *p, bool in_class, Node *cls, uint32_t *cp, Node **out, size_t at) {
    int c = peekc(p);
    if (c < 0)
        rx_fail(p->pat, "a '\\' at the end", at);
    p->i++;
    switch (c) {
    case 'd': case 'D': case 'w': case 'W': case 's': case 'S':
        add_item(cls, CI_ESCAPE, (uint32_t)(c | 0x20), c < 'a');
        return 1;
    case 'p': case 'P':
        parse_property(p, cls, c == 'P', at);
        return 1;
    case 'n': *cp = '\n'; return 0;
    case 'r': *cp = '\r'; return 0;
    case 't': *cp = '\t'; return 0;
    case 'v': *cp = '\v'; return 0;
    case 'f': *cp = '\f'; return 0;
    case '0':
        if (peekc(p) >= '0' && peekc(p) <= '9')
            rx_fail(p->pat, "\\0 followed by a digit: octal escapes are not JS's with u", at);
        *cp = 0;
        return 0;
    case 'c': {
        int l = peekc(p);
        if (!((l >= 'a' && l <= 'z') || (l >= 'A' && l <= 'Z')))
            rx_fail(p->pat, "\\c needs a letter", at);
        p->i++;
        *cp = (uint32_t)(l % 32);
        return 0;
    }
    case 'x':
        if (!parse_hex(p, 2, cp))
            rx_fail(p->pat, "\\x needs two hex digits", at);
        return 0;
    case 'u':
        *cp = parse_unicode_escape(p, at);
        return 0;
    case 'b':
        if (in_class) {
            *cp = 8;
            return 0;
        }
        *out = node_new(N_WORDB, at);
        return 2;
    case 'B':
        if (in_class)
            rx_fail(p->pat, "\\B in a class", at);
        *out = node_new(N_NWORDB, at);
        return 2;
    case 'X':
        if (in_class)
            rx_fail(p->pat, "\\X in a class: it is a grapheme cluster, outside one", at);
        *out = node_new(N_GRAPHEME, at);
        return 2;
    case 'k': {
        if (in_class)
            rx_fail(p->pat, "\\k in a class", at);
        if (!accept(p, '<'))
            rx_fail(p->pat, "\\k needs <name>", at);
        size_t start = p->i;
        while (peekc(p) >= 0 && peekc(p) != '>')
            p->i++;
        if (p->i == start || !accept(p, '>'))
            rx_fail(p->pat, "\\k<name> needs a name and '>'", at);
        Node *n = node_new(N_BACKREF, at);
        n->name = rx_alloc(p->i - start);
        memcpy(n->name, p->pat + start, p->i - 1 - start);
        *out = n;
        return 2;
    }
    case '-':
        if (!in_class)
            rx_fail(p->pat, "\\- outside a class", at);
        *cp = '-';
        return 0;
    default:
        if (c >= '1' && c <= '9') {
            if (in_class)
                rx_fail(p->pat, "a backreference in a class", at);
            int g = c - '0';
            while (peekc(p) >= '0' && peekc(p) <= '9' && g < 1000)
                g = g * 10 + (p->pat[p->i++] - '0');
            Node *n = node_new(N_BACKREF, at);
            n->group = g;
            if (g > p->max_backref) {
                p->max_backref = g;
                p->max_backref_at = at;
            }
            *out = n;
            return 2;
        }
        if (strchr("^$\\.*+?()[]{}|/", c)) {
            *cp = (uint32_t)c;
            return 0;
        }
        rx_fail(p->pat, "an escape that is not JS's with u: only \\^$\\.*+?()[]{}|/ and the named ones", at);
    }
    return 0;
}

/* [...] after the '[' */
static Node *parse_class(Parser *p, size_t at) {
    Node *cls = node_new(N_CLASS, at);
    cls->negate = accept(p, '^');
    for (;;) {
        int c = peekc(p);
        if (c < 0)
            rx_fail(p->pat, "unterminated [...]", at);
        if (c == ']') {
            p->i++;
            break;
        }
        size_t here = p->i;
        uint32_t lo;
        int kind;
        if (c == '\\') {
            p->i++;
            Node *dummy = NULL;
            kind = parse_escape(p, true, cls, &lo, &dummy, here);
        } else {
            lo = next_cp(p);
            kind = 0;
        }
        if (kind == 1)
            continue;
        if (peekc(p) == '-' && peekc2(p) != ']' && peekc2(p) >= 0) {
            p->i++;
            size_t there = p->i;
            uint32_t hi;
            int k2;
            if (peekc(p) == '\\') {
                p->i++;
                Node *dummy = NULL;
                Node probe = {0};
                k2 = parse_escape(p, true, &probe, &hi, &dummy, there);
                free(probe.items);
            } else {
                hi = next_cp(p);
                k2 = 0;
            }
            if (k2 != 0)
                rx_fail(p->pat, "a class escape as the end of a range", there);
            if (hi < lo)
                rx_fail(p->pat, "a range out of order in [...]", here);
            add_item(cls, CI_RANGE, lo, hi);
        } else {
            add_item(cls, CI_RANGE, lo, lo);
        }
    }
    return cls;
}

static Node *parse_atom(Parser *p) {
    size_t at = p->i;
    int c = peekc(p);
    switch (c) {
    case '(': {
        p->i++;
        if (accept(p, '?')) {
            if (accept(p, ':')) {
                Node *n = parse_alt(p);
                if (!accept(p, ')'))
                    rx_fail(p->pat, "unmatched (", at);
                return n;
            }
            int look = -1;
            if (accept(p, '='))
                look = LOOK_AHEAD;
            else if (accept(p, '!'))
                look = LOOK_NAHEAD;
            else if (peekc(p) == '<' && peekc2(p) == '=') {
                p->i += 2;
                look = LOOK_BEHIND;
            } else if (peekc(p) == '<' && peekc2(p) == '!') {
                p->i += 2;
                look = LOOK_NBEHIND;
            }
            if (look >= 0) {
                Node *n = node_new(N_LOOK, at);
                n->look = look;
                add_kid(n, parse_alt(p));
                if (!accept(p, ')'))
                    rx_fail(p->pat, "unmatched (", at);
                return n;
            }
            if (peekc(p) == 'i' || peekc(p) == 'm' || peekc(p) == 's' || peekc(p) == '-') {
                /* (?ims-ims:...) modifiers: the flags inside the group */
                uint32_t on = 0, off = 0;
                bool minus = false;
                for (;;) {
                    int m = peekc(p);
                    uint32_t bit = m == 'i' ? RX_I : m == 'm' ? RX_M : m == 's' ? RX_S : 0;
                    if (m == '-' && !minus) {
                        minus = true;
                        p->i++;
                        continue;
                    }
                    if (!bit)
                        break;
                    if (((on | off) & bit))
                        rx_fail(p->pat, "a modifier twice in (?...:)", at);
                    *(minus ? &off : &on) |= bit;
                    p->i++;
                }
                if (!accept(p, ':') || (minus && !off) || !(on | off))
                    rx_fail(p->pat, "(?ims-ims:...) takes i, m and s to turn on, and after '-' to turn off, then ':'", at);
                uint32_t saved = p->flags;
                p->flags = (p->flags | on) & ~off;
                node_flags = p->flags;
                Node *n = parse_alt(p);
                p->flags = saved;
                node_flags = saved;
                if (!accept(p, ')'))
                    rx_fail(p->pat, "unmatched (", at);
                return n;
            }
            if (!accept(p, '<'))
                rx_fail(p->pat, "(? is followed by :, =, !, <=, <! or <name>", at);
            size_t start = p->i;
            while (peekc(p) >= 0 && peekc(p) != '>')
                p->i++;
            if (p->i == start || !accept(p, '>'))
                rx_fail(p->pat, "(?<name> needs a name and '>'", at);
            if (p->ngroups >= MAX_GROUPS)
                rx_fail(p->pat, "more than 127 groups", at);
            int g = ++p->ngroups;
            p->names[g] = rx_alloc(p->i - start);
            memcpy(p->names[g], p->pat + start, p->i - 1 - start);
            for (int k = 1; k < g; k++)
                if (p->names[k] && !strcmp(p->names[k], p->names[g]))
                    rx_fail(p->pat, "two groups of one name", at);
            Node *n = node_new(N_GROUP, at);
            n->group = g;
            add_kid(n, parse_alt(p));
            if (!accept(p, ')'))
                rx_fail(p->pat, "unmatched (", at);
            return n;
        }
        if (p->ngroups >= MAX_GROUPS)
            rx_fail(p->pat, "more than 127 groups", at);
        Node *n = node_new(N_GROUP, at);
        n->group = ++p->ngroups;
        add_kid(n, parse_alt(p));
        if (!accept(p, ')'))
            rx_fail(p->pat, "unmatched (", at);
        return n;
    }
    case '[':
        p->i++;
        return parse_class(p, at);
    case '.':
        p->i++;
        return node_new(N_ANY, at);
    case '^':
        p->i++;
        return node_new(N_BOL, at);
    case '$':
        p->i++;
        return node_new(N_EOL, at);
    case '*': case '+': case '?':
        rx_fail(p->pat, "nothing to repeat", at);
        break;
    case '{':
        rx_fail(p->pat, "a '{' that is not a quantifier: write \\{", at);
        break;
    case '}': case ']':
        rx_fail(p->pat, "a lone '}' or ']': write \\} or \\]", at);
        break;
    case '\\': {
        p->i++;
        uint32_t cp = 0;
        Node *out = NULL;
        Node *cls = node_new(N_CLASS, at);
        int kind = parse_escape(p, false, cls, &cp, &out, at);
        if (kind == 1)
            return cls;
        rx_node_free(cls);
        if (kind == 2)
            return out;
        Node *n = node_new(N_CHAR, at);
        n->c = cp;
        return n;
    }
    default: {
        Node *n = node_new(N_CHAR, at);
        n->c = next_cp(p);
        return n;
    }
    }
    return NULL;
}

static bool is_assertion(Node *n) {
    return n->kind == N_BOL || n->kind == N_EOL || n->kind == N_WORDB || n->kind == N_NWORDB || n->kind == N_LOOK;
}

static int parse_int(Parser *p) {
    int v = 0;
    bool any = false;
    while (peekc(p) >= '0' && peekc(p) <= '9') {
        if (v < 100000)
            v = v * 10 + (peekc(p) - '0');
        p->i++;
        any = true;
    }
    return any ? v : -1;
}

static Node *parse_term(Parser *p) {
    Node *atom = parse_atom(p);
    size_t at = p->i;
    int c = peekc(p);
    int min, max;
    if (c == '*') {
        min = 0;
        max = INF;
        p->i++;
    } else if (c == '+') {
        min = 1;
        max = INF;
        p->i++;
    } else if (c == '?') {
        min = 0;
        max = 1;
        p->i++;
    } else if (c == '{') {
        p->i++;
        min = parse_int(p);
        if (min < 0)
            rx_fail(p->pat, "a quantifier {n}, {n,} or {n,m} needs a number", at);
        if (accept(p, ',')) {
            max = peekc(p) == '}' ? INF : parse_int(p);
            if (max < 0)
                rx_fail(p->pat, "a quantifier {n,m} needs a number after the comma", at);
        } else {
            max = min;
        }
        if (!accept(p, '}'))
            rx_fail(p->pat, "a quantifier {...} needs '}'", at);
        if (max < min)
            rx_fail(p->pat, "a quantifier {n,m} with m less than n", at);
        if (min > 100000 || (max != INF && max > 100000))
            rx_fail(p->pat, "a quantifier beyond 100000", at);
    } else {
        return atom;
    }
    if (is_assertion(atom))
        rx_fail(p->pat, "nothing to repeat: an assertion is not repeated", at);
    Node *r = node_new(N_REPEAT, at);
    r->min = min;
    r->max = max;
    r->greedy = !accept(p, '?');
    add_kid(r, atom);
    return r;
}

static Node *parse_seq(Parser *p) {
    Node *seq = node_new(N_SEQ, p->i);
    while (peekc(p) >= 0 && peekc(p) != '|' && peekc(p) != ')')
        add_kid(seq, parse_term(p));
    return seq;
}

static Node *parse_alt(Parser *p) {
    Node *first = parse_seq(p);
    if (peekc(p) != '|')
        return first;
    Node *alt = node_new(N_ALT, first->at);
    add_kid(alt, first);
    while (accept(p, '|'))
        add_kid(alt, parse_seq(p));
    return alt;
}

/* \k<name> to its group, now that every group is read */
static void resolve_names(Parser *p, Node *n) {
    if (n->kind == N_BACKREF && n->name) {
        int g = 0;
        for (int k = 1; k <= p->ngroups; k++)
            if (p->names[k] && !strcmp(p->names[k], n->name))
                g = k;
        if (!g)
            rx_fail(p->pat, "\\k<name> of a group there is none of", n->at);
        n->group = g;
    }
    for (int i = 0; i < n->nkids; i++)
        resolve_names(p, n->kids[i]);
}


/* the tree of a pattern with its flags (#157): the flags read, the pattern
   parsed, the backreferences checked against the groups, the names
   resolved; an error ends the program, or returns to rx_check */
Node *rx_parse_pattern(Parser *p, const uint8_t *pattern, const uint8_t *flags) {
    memset(p, 0, sizeof *p);
    p->pat = pattern ? pattern : (const uint8_t *)"";
    p->len = strlen((const char *)p->pat);
    for (const uint8_t *f = flags ? flags : (const uint8_t *)""; *f; f++) {
        uint32_t bit = *f == 'i' ? RX_I : *f == 'm' ? RX_M : *f == 's' ? RX_S : *f == 'g' ? RX_G : *f == 'y' ? RX_Y
                     : *f == 'd' ? RX_D : *f == 'u' ? RX_U : 0;
        if (!bit)
            rx_fail(p->pat, *f == 'v' ? "the v flag is not here yet: the flags are dgimsuy" : "a flag that is not one of dgimsuy", p->len);
        if (p->flags & bit)
            rx_fail(p->pat, "a flag twice", p->len);
        p->flags |= bit;
    }
    node_flags = p->flags;
    Node *tree = parse_alt(p);
    if (p->i < p->len)
        rx_fail(p->pat, "unmatched )", p->i);
    if (p->max_backref > p->ngroups)
        rx_fail(p->pat, "a backreference to a group there is none of", p->max_backref_at);
    resolve_names(p, tree);
    return tree;
}

/* Is the pattern with the flags one JS reads? NULL, or what is wrong, with
   *at where in the pattern (its length for a flag). For kelvinc (#163). */
const char *rx_check(const char *pattern, const char *flags, size_t *at) {
    jmp_buf jb;
    Parser p;
    rx_catch = &jb;
    if (setjmp(jb)) {
        rx_catch = NULL;
        *at = rx_at;
        return rx_msg;
    }
    Node *tree = rx_parse_pattern(&p, (const uint8_t *)pattern, (const uint8_t *)flags);
    rx_catch = NULL;
    rx_node_free(tree);
    for (int g = 1; g <= p.ngroups; g++)
        free(p.names[g]);
    return NULL;
}
