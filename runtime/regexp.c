/* regexp.c - the engine of #import <RegExp> (#157): JS's regular expressions,
   as its u flag reads them, over Kelvin's Strings, codepoint by codepoint,
   with \X for a grapheme cluster. A pattern is parsed to a tree, the tree
   compiled to a program of words held in a Bytes, and the program run by a
   backtracking matcher with an explicit stack: a split pushes where to go
   back to, a save pushes the old value of a group, and a failure pops to the
   last split. Lookarounds run the matcher again on their own sub-program; a
   lookbehind tries each start that could end at the point, the farthest
   first, which prefers the longest as JS's backward matching does.

   The syntax: | ( ) (?: ) (?<name> ) (?= ) (?! ) (?<= ) (?<! ) * + ? {n} {n,}
   {n,m} and their lazy forms; . ^ $ \b \B; [ ] with ranges and ^; \d \w \s
   and their negations; \p{...} and \P{...} by General_Category, Script,
   Script_Extensions and the binary properties, from libkUnicodeData; \1 \k<n>
   backreferences; \n \r \t \v \f \0 \cX \xHH \uHHHH \u{...}; \X; (?ims-ims:...)
   modifiers. The flags: i (by simple case folding), m, s, g, y, u and d, as
   JS has them. */
#include "kelvin_prelude.h"
#include "kUnicodeData.h"
#include "kRegExp.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { RX_I = 1, RX_M = 2, RX_S = 4, RX_G = 8, RX_Y = 16, RX_D = 32, RX_U = 64 };

/* the program: a header of words, the code, the class data, the names */
enum { H_MAGIC, H_FLAGS, H_GROUPS, H_LOOPS, H_CODE, H_CODELEN, H_DATA, H_NAMES, H_NAMESLEN, H_SIZE };
#define RX_MAGIC 0x3145524Bu /* "KRE1" */

enum {
    OP_CHAR, OP_ANY, OP_ANYALL, OP_CLASS, OP_SPLIT, OP_JMP, OP_SAVE, OP_BOL, OP_EOL, OP_WORDB, OP_NWORDB,
    OP_BACKREF, OP_LOOK, OP_MATCH, OP_GRAPHEME, OP_RESET, OP_MARK, OP_CHECK
};
enum { CI_RANGE, CI_ESCAPE, CI_GC, CI_SCRIPT, CI_PROP }; /* the items of a class */
enum { LOOK_AHEAD, LOOK_NAHEAD, LOOK_BEHIND, LOOK_NBEHIND };
#define INF 0x7fffffff
#define MAX_GROUPS 127
#define MAX_CODE (1u << 20)

static void rx_fail(const uint8_t *pattern, const char *what, size_t at) {
    fflush(stdout);
    fprintf(stderr, "kelvin: RegExp: %s in /%s/ at %zu\n", what, (const char *)pattern, at);
    abort();
}

static void *rx_alloc(size_t n) {
    void *p = malloc(n ? n : 1);
    if (!p) {
        fputs("kelvin: out of memory\n", stderr);
        abort();
    }
    memset(p, 0, n);
    return p;
}

static void *rx_grow(void *p, size_t n) {
    p = realloc(p, n);
    if (!p) {
        fputs("kelvin: out of memory\n", stderr);
        abort();
    }
    return p;
}

/* ---------- UTF-8 ---------- */

#define NO_CP 0xFFFFFFFFu

/* the codepoint at p[pos], and its length; NO_CP at the end */
static uint32_t cp_at(const uint8_t *p, int64_t n, int64_t pos, int *len) {
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
static uint32_t cp_before(const uint8_t *p, int64_t n, int64_t pos, int *len) {
    if (pos <= 0) {
        *len = 0;
        return NO_CP;
    }
    int64_t k = pos - 1;
    while (k > 0 && (p[k] & 0xC0) == 0x80)
        k--;
    return cp_at(p, n, k, len);
}

static int utf8_put(uint8_t *out, uint32_t cp) {
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

static bool is_line_end(uint32_t c) { return c == '\n' || c == '\r' || c == 0x2028 || c == 0x2029; }
static bool is_word_cp(uint32_t c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
}
static bool is_space_cp(uint32_t c) {
    return c == 9 || c == 10 || c == 11 || c == 12 || c == 13 || c == ' ' || c == 0xA0 || c == 0x1680 ||
           (c >= 0x2000 && c <= 0x200A) || c == 0x2028 || c == 0x2029 || c == 0x202F || c == 0x205F || c == 0x3000 ||
           c == 0xFEFF;
}

/* ---------- the tree ---------- */

typedef struct {
    uint32_t kind, a, b;
} Item;

typedef struct Node Node;
struct Node {
    int kind;
    uint32_t c;           /* N_CHAR */
    int min, max;         /* N_REPEAT */
    bool greedy;
    int group;            /* N_GROUP, N_BACKREF */
    int look;             /* N_LOOK */
    bool negate;          /* N_CLASS */
    Item *items;          /* N_CLASS */
    int nitems, icap;
    Node **kids;          /* N_SEQ, N_ALT; one for N_GROUP, N_REPEAT, N_LOOK */
    int nkids, kcap;
    char *name;           /* N_BACKREF by name */
    size_t at;            /* where in the pattern, for errors */
    uint32_t flags;       /* i, m and s where the node is, after (?ims-ims:...) modifiers */
};

enum {
    N_EMPTY, N_CHAR, N_ANY, N_CLASS, N_SEQ, N_ALT, N_GROUP, N_REPEAT, N_BOL, N_EOL, N_WORDB, N_NWORDB, N_BACKREF,
    N_LOOK, N_GRAPHEME
};

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

static void node_free(Node *n) {
    if (!n)
        return;
    for (int i = 0; i < n->nkids; i++)
        node_free(n->kids[i]);
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

typedef struct {
    const uint8_t *pat;
    size_t len, i;
    uint32_t flags;
    int ngroups;
    char *names[MAX_GROUPS + 1];
    int max_backref;
    size_t max_backref_at;
} Parser;

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
    uint32_t c = cp_at(p->pat, (int64_t)p->len, (int64_t)p->i, &len);
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
            uint32_t mask = ucd_category_mask((const uint8_t *)value);
            if (!mask)
                rx_fail(p->pat, "an unknown General_Category in \\p{...}", at);
            add_item(cls, CI_GC, mask, negate);
            return;
        }
        bool scx = !strcmp(name, "Script_Extensions") || !strcmp(name, "scx");
        if (scx || !strcmp(name, "Script") || !strcmp(name, "sc")) {
            int id = ucd_script_id((const uint8_t *)value);
            if (id < 0)
                rx_fail(p->pat, "an unknown Script in \\p{...}", at);
            add_item(cls, CI_SCRIPT, (uint32_t)id, (negate ? 1u : 0u) | (scx ? 2u : 0u));
            return;
        }
        rx_fail(p->pat, "\\p{name=value} takes General_Category, Script or Script_Extensions", at);
    }
    uint32_t mask = ucd_category_mask((const uint8_t *)name);
    if (mask) {
        add_item(cls, CI_GC, mask, negate);
        return;
    }
    int id = ucd_property_id((const uint8_t *)name);
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
        node_free(cls);
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

/* the groups inside a node, for resetting them each iteration */
static void group_span(Node *n, int *lo, int *hi) {
    if (n->kind == N_GROUP) {
        if (n->group < *lo)
            *lo = n->group;
        if (n->group > *hi)
            *hi = n->group;
    }
    for (int i = 0; i < n->nkids; i++)
        group_span(n->kids[i], lo, hi);
}

/* the most codepoints a node matches, -1 where there is no bound */
static int64_t max_len(Node *n) {
    switch (n->kind) {
    case N_CHAR: case N_ANY: case N_CLASS:
        return 1;
    case N_SEQ: {
        int64_t sum = 0;
        for (int i = 0; i < n->nkids; i++) {
            int64_t k = max_len(n->kids[i]);
            if (k < 0)
                return -1;
            sum += k;
        }
        return sum;
    }
    case N_ALT: {
        int64_t best = 0;
        for (int i = 0; i < n->nkids; i++) {
            int64_t k = max_len(n->kids[i]);
            if (k < 0)
                return -1;
            if (k > best)
                best = k;
        }
        return best;
    }
    case N_GROUP:
        return max_len(n->kids[0]);
    case N_REPEAT: {
        if (n->max == INF)
            return -1;
        int64_t k = max_len(n->kids[0]);
        return k < 0 ? -1 : k * n->max;
    }
    case N_BACKREF: case N_GRAPHEME:
        return -1;
    default:
        return 0;
    }
}

/* ---------- the compiler ---------- */

typedef struct {
    uint32_t *code;
    size_t n, cap;
    uint32_t *data;
    size_t dn, dcap;
    Parser *p;
    int nloops;
} Emitter;

static void emit(Emitter *e, uint32_t w) {
    if (e->n == e->cap) {
        e->cap = e->cap ? e->cap * 2 : 256;
        e->code = rx_grow(e->code, e->cap * sizeof *e->code);
    }
    if (e->n >= MAX_CODE)
        rx_fail(e->p->pat, "a pattern too large once its quantifiers are unrolled", 0);
    e->code[e->n++] = w;
}

static void emit_data(Emitter *e, uint32_t w) {
    if (e->dn == e->dcap) {
        e->dcap = e->dcap ? e->dcap * 2 : 64;
        e->data = rx_grow(e->data, e->dcap * sizeof *e->data);
    }
    e->data[e->dn++] = w;
}

static void emit_node(Emitter *e, Node *n);

static void emit_reset(Emitter *e, Node *body) {
    int lo = MAX_GROUPS + 1, hi = 0;
    group_span(body, &lo, &hi);
    if (hi) {
        emit(e, OP_RESET);
        emit(e, (uint32_t)lo);
        emit(e, (uint32_t)hi);
    }
}

static void emit_node(Emitter *e, Node *n) {
    switch (n->kind) {
    case N_EMPTY:
        break;
    case N_CHAR:
        emit(e, OP_CHAR);
        emit(e, (n->flags & RX_I) ? ucd_to_fold(n->c) : n->c);
        emit(e, n->flags & RX_I);
        break;
    case N_ANY:
        emit(e, (n->flags & RX_S) ? OP_ANYALL : OP_ANY);
        break;
    case N_CLASS:
        emit(e, OP_CLASS);
        emit(e, (uint32_t)e->dn);
        emit(e, n->flags & RX_I);
        emit_data(e, n->negate);
        emit_data(e, (uint32_t)n->nitems);
        for (int i = 0; i < n->nitems; i++) {
            emit_data(e, n->items[i].kind);
            emit_data(e, n->items[i].a);
            emit_data(e, n->items[i].b);
        }
        break;
    case N_SEQ:
        for (int i = 0; i < n->nkids; i++)
            emit_node(e, n->kids[i]);
        break;
    case N_ALT: {
        size_t *jumps = rx_alloc((size_t)n->nkids * sizeof *jumps);
        for (int i = 0; i < n->nkids; i++) {
            if (i < n->nkids - 1) {
                size_t split = e->n;
                emit(e, OP_SPLIT);
                emit(e, (uint32_t)(e->n + 2));
                emit(e, 0);
                emit_node(e, n->kids[i]);
                jumps[i] = e->n;
                emit(e, OP_JMP);
                emit(e, 0);
                e->code[split + 2] = (uint32_t)e->n;
            } else {
                emit_node(e, n->kids[i]);
            }
        }
        for (int i = 0; i < n->nkids - 1; i++)
            e->code[jumps[i] + 1] = (uint32_t)e->n;
        free(jumps);
        break;
    }
    case N_GROUP:
        emit(e, OP_SAVE);
        emit(e, (uint32_t)(2 * n->group));
        emit_node(e, n->kids[0]);
        emit(e, OP_SAVE);
        emit(e, (uint32_t)(2 * n->group + 1));
        break;
    case N_REPEAT: {
        Node *body = n->kids[0];
        for (int k = 0; k < n->min; k++) {
            emit_reset(e, body);
            emit_node(e, body);
        }
        if (n->max == INF) {
            int slot = e->nloops++;
            size_t top = e->n;
            emit(e, OP_SPLIT);
            emit(e, 0);
            emit(e, 0);
            size_t body_at = e->n;
            emit(e, OP_MARK);
            emit(e, (uint32_t)slot);
            emit_reset(e, body);
            emit_node(e, body);
            emit(e, OP_CHECK);
            emit(e, (uint32_t)slot);
            emit(e, OP_JMP);
            emit(e, (uint32_t)top);
            e->code[top + 1] = n->greedy ? (uint32_t)body_at : (uint32_t)e->n;
            e->code[top + 2] = n->greedy ? (uint32_t)e->n : (uint32_t)body_at;
        } else if (n->max > n->min) {
            size_t *splits = rx_alloc((size_t)(n->max - n->min) * sizeof *splits);
            for (int k = 0; k < n->max - n->min; k++) {
                splits[k] = e->n;
                emit(e, OP_SPLIT);
                emit(e, 0);
                emit(e, 0);
                size_t body_at = e->n;
                emit_reset(e, body);
                emit_node(e, body);
                e->code[splits[k] + (n->greedy ? 1 : 2)] = (uint32_t)body_at;
            }
            for (int k = 0; k < n->max - n->min; k++)
                e->code[splits[k] + (n->greedy ? 2 : 1)] = (uint32_t)e->n;
            free(splits);
        }
        break;
    }
    case N_BOL:
        emit(e, OP_BOL);
        emit(e, n->flags & RX_M);
        break;
    case N_EOL:
        emit(e, OP_EOL);
        emit(e, n->flags & RX_M);
        break;
    case N_WORDB:
        emit(e, OP_WORDB);
        break;
    case N_NWORDB:
        emit(e, OP_NWORDB);
        break;
    case N_BACKREF:
        emit(e, OP_BACKREF);
        emit(e, (uint32_t)n->group);
        emit(e, n->flags & RX_I);
        break;
    case N_LOOK: {
        int64_t m = max_len(n->kids[0]);
        size_t at = e->n;
        emit(e, OP_LOOK);
        emit(e, (uint32_t)n->look);
        emit(e, 0);
        emit(e, m < 0 ? UINT32_MAX : (uint32_t)m);
        emit_node(e, n->kids[0]);
        emit(e, OP_MATCH);
        e->code[at + 2] = (uint32_t)(e->n - (at + 4));
        break;
    }
    case N_GRAPHEME:
        emit(e, OP_GRAPHEME);
        break;
    }
}

kv_bytes rx_compile(const uint8_t *pattern, const uint8_t *flags) {
    Parser p = {0};
    p.pat = pattern ? pattern : (const uint8_t *)"";
    p.len = strlen((const char *)p.pat);
    for (const uint8_t *f = flags ? flags : (const uint8_t *)""; *f; f++) {
        uint32_t bit = *f == 'i' ? RX_I : *f == 'm' ? RX_M : *f == 's' ? RX_S : *f == 'g' ? RX_G : *f == 'y' ? RX_Y
                     : *f == 'd' ? RX_D : *f == 'u' ? RX_U : 0;
        if (!bit)
            rx_fail(p.pat, *f == 'v' ? "the v flag is not here yet: the flags are dgimsuy" : "a flag that is not one of dgimsuy", 0);
        if (p.flags & bit)
            rx_fail(p.pat, "a flag twice", 0);
        p.flags |= bit;
    }
    node_flags = p.flags;
    Node *tree = parse_alt(&p);
    if (p.i < p.len)
        rx_fail(p.pat, "unmatched )", p.i);
    if (p.max_backref > p.ngroups)
        rx_fail(p.pat, "a backreference to a group there is none of", p.max_backref_at);
    resolve_names(&p, tree);

    Emitter e = {0};
    e.p = &p;
    emit(&e, OP_SAVE);
    emit(&e, 0);
    emit_node(&e, tree);
    emit(&e, OP_SAVE);
    emit(&e, 1);
    emit(&e, OP_MATCH);
    node_free(tree);

    size_t names_len = 0;
    for (int g = 1; g <= p.ngroups; g++)
        names_len += (p.names[g] ? strlen(p.names[g]) : 0) + 1;
    uint32_t header[H_SIZE];
    header[H_MAGIC] = RX_MAGIC;
    header[H_FLAGS] = p.flags;
    header[H_GROUPS] = (uint32_t)p.ngroups;
    header[H_LOOPS] = (uint32_t)e.nloops;
    header[H_CODE] = H_SIZE;
    header[H_CODELEN] = (uint32_t)e.n;
    header[H_DATA] = (uint32_t)(H_SIZE + e.n);
    header[H_NAMES] = (uint32_t)(H_SIZE + e.n + e.dn);
    header[H_NAMESLEN] = (uint32_t)names_len;
    kv_bytes b = kv_bytes_new();
    kv_bytes_append(&b, header, sizeof header);
    kv_bytes_append(&b, e.code, e.n * sizeof *e.code);
    if (e.dn)
        kv_bytes_append(&b, e.data, e.dn * sizeof *e.data);
    for (int g = 1; g <= p.ngroups; g++) {
        kv_bytes_append_text(&b, p.names[g] ? p.names[g] : "");
        kv_bytes_push(&b, 0);
        free(p.names[g]);
    }
    free(e.code);
    free(e.data);
    return b;
}

/* ---------- the program ---------- */

static const uint32_t *prog_words(const kv_bytes *prog) {
    if (!prog || prog->count < H_SIZE * sizeof(uint32_t) || ((const uint32_t *)(const void *)prog->at)[H_MAGIC] != RX_MAGIC) {
        fflush(stdout);
        fputs("kelvin: RegExp: a Bytes that is not a program of RegExp.compile\n", stderr);
        abort();
    }
    return (const uint32_t *)(const void *)prog->at;
}

int64_t rx_groups(const kv_bytes *prog) { return prog_words(prog)[H_GROUPS]; }

const uint8_t *rx_group_name(const kv_bytes *prog, int64_t i) {
    const uint32_t *w = prog_words(prog);
    const uint8_t *names = prog->at + (size_t)w[H_NAMES] * sizeof(uint32_t);
    if (i < 1 || i > (int64_t)w[H_GROUPS])
        return (const uint8_t *)"";
    for (int64_t g = 1; g < i; g++)
        names += strlen((const char *)names) + 1;
    return names;
}

int64_t rx_group_named(const kv_bytes *prog, const uint8_t *name) {
    const uint32_t *w = prog_words(prog);
    const uint8_t *names = prog->at + (size_t)w[H_NAMES] * sizeof(uint32_t);
    for (int64_t g = 1; g <= (int64_t)w[H_GROUPS]; g++) {
        if (*names && !strcmp((const char *)names, (const char *)name))
            return g;
        names += strlen((const char *)names) + 1;
    }
    return -1;
}

bool rx_flag(const kv_bytes *prog, uint8_t flag) {
    uint32_t f = prog_words(prog)[H_FLAGS];
    switch (flag) {
    case 'i': return f & RX_I;
    case 'm': return f & RX_M;
    case 's': return f & RX_S;
    case 'g': return f & RX_G;
    case 'y': return f & RX_Y;
    case 'd': return f & RX_D;
    case 'u': return f & RX_U;
    default: return false;
    }
}

/* ---------- the matcher ---------- */

typedef struct {
    uint32_t kind; /* 0 a branch (pc, pos), 1 a group's old value (slot, old), 2 a loop's (slot, old) */
    uint32_t a;
    int64_t b;
} Frame;

typedef struct {
    const uint8_t *s;
    int64_t n;
    uint32_t flags;
    const uint32_t *code;
    const uint32_t *data;
    int64_t *caps;
    int ncaps;
    int64_t *loops;
    int nloops;
    Frame *stack;
    size_t top, cap;
} Ctx;

static void push(Ctx *c, uint32_t kind, uint32_t a, int64_t b) {
    if (c->top == c->cap) {
        c->cap = c->cap ? c->cap * 2 : 64;
        c->stack = rx_grow(c->stack, c->cap * sizeof *c->stack);
    }
    c->stack[c->top++] = (Frame){kind, a, b};
}

static bool item_matches(const uint32_t *it, uint32_t x) {
    switch (it[0]) {
    case CI_RANGE:
        return x >= it[1] && x <= it[2];
    case CI_ESCAPE: {
        bool m = it[1] == 'd' ? (x >= '0' && x <= '9') : it[1] == 'w' ? is_word_cp(x) : is_space_cp(x);
        return m != (bool)it[2];
    }
    case CI_GC:
        return (bool)((it[1] >> kv_ud_cat(x)) & 1) != (bool)it[2];
    case CI_SCRIPT: {
        bool m = (it[2] & 2) ? ucd_scx_has(x, (int)it[1]) : kv_ud_script(x) == it[1];
        return m != (bool)(it[2] & 1);
    }
    case CI_PROP:
        return ucd_has_property(x, (int)it[1]) != (bool)it[2];
    }
    return false;
}

static bool class_has(const uint32_t *cls, uint32_t x) {
    uint32_t n = cls[1];
    for (uint32_t i = 0; i < n; i++)
        if (item_matches(cls + 2 + 3 * i, x))
            return true;
    return false;
}

static bool class_matches(const uint32_t *cls, uint32_t x, bool ci) {
    bool m = class_has(cls, x);
    if (!m && ci) {
        uint32_t f = ucd_to_fold(x), u = ucd_to_upper(x), l = ucd_to_lower(x);
        m = (f != x && class_has(cls, f)) || (u != x && class_has(cls, u)) || (l != x && class_has(cls, l));
    }
    return m != (bool)cls[0];
}

static bool run(Ctx *c, uint32_t pc, int64_t pos, int64_t must_end, int64_t *end_out);

/* the start of the codepoint count codepoints before pos, or 0 */
static int64_t back_cps(const uint8_t *s, int64_t pos, uint32_t count) {
    while (count-- && pos > 0) {
        pos--;
        while (pos > 0 && (s[pos] & 0xC0) == 0x80)
            pos--;
    }
    return pos;
}

static bool look(Ctx *c, uint32_t kind, uint32_t sub, uint32_t maxlen, int64_t pos) {
    int64_t *snap = rx_alloc((size_t)(c->ncaps + c->nloops) * sizeof *snap);
    memcpy(snap, c->caps, (size_t)c->ncaps * sizeof *snap);
    memcpy(snap + c->ncaps, c->loops, (size_t)c->nloops * sizeof *snap);
    bool ok = false;
    int64_t end;
    if (kind == LOOK_AHEAD || kind == LOOK_NAHEAD) {
        ok = run(c, sub, pos, -1, &end);
    } else {
        int64_t k = maxlen == UINT32_MAX ? 0 : back_cps(c->s, pos, maxlen);
        for (; k <= pos && !ok; k++) {
            if (k < pos && (c->s[k] & 0xC0) == 0x80)
                continue;
            ok = run(c, sub, k, pos, &end);
        }
    }
    bool negative = kind == LOOK_NAHEAD || kind == LOOK_NBEHIND;
    bool keep = ok && !negative;
    for (int i = 0; i < c->ncaps; i++) {
        if (keep) {
            if (c->caps[i] != snap[i])
                push(c, 1, (uint32_t)i, snap[i]);
        } else {
            c->caps[i] = snap[i];
        }
    }
    memcpy(c->loops, snap + c->ncaps, (size_t)c->nloops * sizeof *snap);
    free(snap);
    return ok != negative;
}

static bool run(Ctx *c, uint32_t pc, int64_t pos, int64_t must_end, int64_t *end_out) {
    const uint32_t *code = c->code;
    size_t base = c->top;
    for (;;) {
        int len;
        uint32_t x;
        switch (code[pc]) {
        case OP_CHAR:
            x = cp_at(c->s, c->n, pos, &len);
            if (x == NO_CP || (code[pc + 2] ? ucd_to_fold(x) : x) != code[pc + 1])
                goto fail;
            pos += len;
            pc += 3;
            continue;
        case OP_ANY:
            x = cp_at(c->s, c->n, pos, &len);
            if (x == NO_CP || is_line_end(x))
                goto fail;
            pos += len;
            pc++;
            continue;
        case OP_ANYALL:
            x = cp_at(c->s, c->n, pos, &len);
            if (x == NO_CP)
                goto fail;
            pos += len;
            pc++;
            continue;
        case OP_CLASS:
            x = cp_at(c->s, c->n, pos, &len);
            if (x == NO_CP || !class_matches(c->data + code[pc + 1], x, code[pc + 2]))
                goto fail;
            pos += len;
            pc += 3;
            continue;
        case OP_SPLIT:
            push(c, 0, code[pc + 2], pos);
            pc = code[pc + 1];
            continue;
        case OP_JMP:
            pc = code[pc + 1];
            continue;
        case OP_SAVE:
            push(c, 1, code[pc + 1], c->caps[code[pc + 1]]);
            c->caps[code[pc + 1]] = pos;
            pc += 2;
            continue;
        case OP_BOL:
            if (!(pos == 0 || (code[pc + 1] && is_line_end(cp_before(c->s, c->n, pos, &len)))))
                goto fail;
            pc += 2;
            continue;
        case OP_EOL:
            if (!(pos == c->n || (code[pc + 1] && is_line_end(cp_at(c->s, c->n, pos, &len)))))
                goto fail;
            pc += 2;
            continue;
        case OP_WORDB:
        case OP_NWORDB: {
            uint32_t before = cp_before(c->s, c->n, pos, &len), after = cp_at(c->s, c->n, pos, &len);
            bool a = before != NO_CP && is_word_cp(before), b = after != NO_CP && is_word_cp(after);
            if ((a != b) != (code[pc] == OP_WORDB))
                goto fail;
            pc++;
            continue;
        }
        case OP_BACKREF: {
            uint32_t g = code[pc + 1];
            int64_t lo = c->caps[2 * g], hi = c->caps[2 * g + 1];
            if (lo < 0 || hi < 0) {
                pc += 3;
                continue;
            }
            if (code[pc + 2]) {
                int64_t k = lo;
                while (k < hi) {
                    int l2;
                    uint32_t a = cp_at(c->s, c->n, k, &len), b = cp_at(c->s, c->n, pos, &l2);
                    if (b == NO_CP || ucd_to_fold(a) != ucd_to_fold(b))
                        goto fail;
                    k += len;
                    pos += l2;
                }
            } else {
                if (pos + (hi - lo) > c->n || memcmp(c->s + lo, c->s + pos, (size_t)(hi - lo)))
                    goto fail;
                pos += hi - lo;
            }
            pc += 3;
            continue;
        }
        case OP_LOOK: {
            uint32_t kind = code[pc + 1], sublen = code[pc + 2], maxlen = code[pc + 3];
            if (!look(c, kind, pc + 4, maxlen, pos))
                goto fail;
            pc += 4 + sublen;
            continue;
        }
        case OP_MATCH:
            if (must_end >= 0 && pos != must_end)
                goto fail;
            *end_out = pos;
            c->top = base;
            return true;
        case OP_GRAPHEME:
            if (pos >= c->n)
                goto fail;
            pos += (int64_t)ucd_grapheme_len(c->s + pos, (size_t)(c->n - pos));
            pc++;
            continue;
        case OP_RESET:
            for (uint32_t g = code[pc + 1]; g <= code[pc + 2]; g++)
                for (uint32_t slot = 2 * g; slot <= 2 * g + 1; slot++)
                    if (c->caps[slot] != -1) {
                        push(c, 1, slot, c->caps[slot]);
                        c->caps[slot] = -1;
                    }
            pc += 3;
            continue;
        case OP_MARK:
            push(c, 2, code[pc + 1], c->loops[code[pc + 1]]);
            c->loops[code[pc + 1]] = pos;
            pc += 2;
            continue;
        case OP_CHECK:
            if (pos == c->loops[code[pc + 1]])
                goto fail;
            pc += 2;
            continue;
        default:
            fputs("kelvin: RegExp: a broken program\n", stderr);
            abort();
        }
    fail:
        for (;;) {
            if (c->top == base)
                return false;
            Frame f = c->stack[--c->top];
            if (f.kind == 1) {
                c->caps[f.a] = f.b;
            } else if (f.kind == 2) {
                c->loops[f.a] = f.b;
            } else {
                pc = f.a;
                pos = f.b;
                break;
            }
        }
    }
}

bool rx_search(const kv_bytes *prog, const kv_string *s, int64_t from, bool sticky, int64_t *caps) {
    const uint32_t *w = prog_words(prog);
    Ctx c = {0};
    c.s = s->b.at ? s->b.at : (const uint8_t *)"";
    c.n = (int64_t)s->b.count;
    c.flags = w[H_FLAGS];
    c.code = w + w[H_CODE];
    c.data = w + w[H_DATA];
    c.ncaps = 2 * ((int)w[H_GROUPS] + 1);
    c.caps = caps;
    c.nloops = (int)w[H_LOOPS];
    c.loops = rx_alloc((size_t)(c.nloops ? c.nloops : 1) * sizeof *c.loops);
    if (from < 0)
        from = 0;
    bool found = false;
    /* a pattern that starts with a character, not folded, is sought by its first byte */
    uint8_t first[4];
    int first_len = 0;
    if (c.code[2] == OP_CHAR && !c.code[4])
        first_len = utf8_put(first, c.code[3]);
    for (int64_t start = from; start <= c.n; ) {
        if (first_len && !sticky) {
            const uint8_t *q = memchr(c.s + start, first[0], (size_t)(c.n - start));
            if (!q)
                break;
            start = q - c.s;
        }
        for (int i = 0; i < c.ncaps; i++)
            caps[i] = -1;
        for (int i = 0; i < c.nloops; i++)
            c.loops[i] = -1;
        int64_t end;
        c.top = 0;
        if (run(&c, 0, start, -1, &end)) {
            found = true;
            break;
        }
        if (sticky || start >= c.n)
            break;
        int len;
        cp_at(c.s, c.n, start, &len);
        start += len;
    }
    free(c.stack);
    free(c.loops);
    return found;
}

/* ---------- the replacement, bytes and codepoints ---------- */

static void append_bytes(kv_string *out, const uint8_t *p, int64_t lo, int64_t hi) {
    if (hi > lo) {
        kv_bytes_append(&out->b, p + lo, (size_t)(hi - lo));
        for (int64_t k = lo; k < hi; k++)
            if ((p[k] & 0xC0) != 0x80)
                out->count++;
    }
}

void rx_expand(const kv_bytes *prog, const kv_string *s, const int64_t *caps, const uint8_t *with, kv_string *out) {
    int64_t ngroups = rx_groups(prog);
    const uint8_t *p = s->b.at ? s->b.at : (const uint8_t *)"";
    int64_t n = (int64_t)s->b.count;
    for (const uint8_t *t = with; *t; t++) {
        if (*t != '$' || !t[1]) {
            int len;
            cp_at(t, 4, 0, &len); /* the bytes of this codepoint, as written */
            append_bytes(out, t, 0, len);
            t += len - 1;
            continue;
        }
        if (t[1] == '$') {
            kv_string_append_cp(out, '$');
            t++;
        } else if (t[1] == '&') {
            append_bytes(out, p, caps[0], caps[1]);
            t++;
        } else if (t[1] == '`') {
            append_bytes(out, p, 0, caps[0]);
            t++;
        } else if (t[1] == '\'') {
            append_bytes(out, p, caps[1], n);
            t++;
        } else if (t[1] >= '0' && t[1] <= '9') {
            int g = t[1] - '0', used = 1;
            if (t[2] >= '0' && t[2] <= '9' && g * 10 + (t[2] - '0') <= ngroups && g * 10 + (t[2] - '0') >= 1) {
                g = g * 10 + (t[2] - '0');
                used = 2;
            }
            if (g >= 1 && g <= ngroups) {
                if (caps[2 * g] >= 0)
                    append_bytes(out, p, caps[2 * g], caps[2 * g + 1]);
                t += used;
            } else {
                kv_string_append_cp(out, '$');
            }
        } else if (t[1] == '<') {
            const uint8_t *close = (const uint8_t *)strchr((const char *)t + 2, '>');
            if (!close) {
                kv_string_append_cp(out, '$');
                continue;
            }
            char name[128];
            size_t len = (size_t)(close - (t + 2));
            if (len >= sizeof name)
                len = sizeof name - 1;
            memcpy(name, t + 2, len);
            name[len] = 0;
            int64_t g = rx_group_named(prog, (const uint8_t *)name);
            if (g > 0 && caps[2 * g] >= 0)
                append_bytes(out, p, caps[2 * g], caps[2 * g + 1]);
            t = close;
        } else {
            kv_string_append_cp(out, '$');
        }
    }
}

kv_string rx_slice(const kv_string *s, int64_t lo, int64_t hi) {
    kv_string out = kv_string_new();
    if (lo < 0)
        lo = 0;
    if (hi > (int64_t)s->b.count)
        hi = (int64_t)s->b.count;
    if (s->b.at)
        append_bytes(&out, s->b.at, lo, hi);
    return out;
}

int64_t rx_cp_index(const kv_string *s, int64_t byte) {
    int64_t k = 0;
    if (byte > (int64_t)s->b.count)
        byte = (int64_t)s->b.count;
    for (int64_t i = 0; i < byte; i++)
        if ((s->b.at[i] & 0xC0) != 0x80)
            k++;
    return k;
}

int64_t rx_byte_index(const kv_string *s, int64_t cp) {
    int64_t n = (int64_t)s->b.count, i = 0;
    while (cp > 0 && i < n) {
        int len;
        cp_at(s->b.at, n, i, &len);
        i += len;
        cp--;
    }
    return i;
}

int64_t rx_next(const kv_string *s, int64_t byte) {
    int len;
    if (byte >= (int64_t)s->b.count)
        return (int64_t)s->b.count;
    cp_at(s->b.at, (int64_t)s->b.count, byte, &len);
    return byte + len;
}
