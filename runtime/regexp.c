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
   JS has them. The parser is runtime/regexp_parse.c, shared with kelvinc (#163). */
#include "kelvin_prelude.h"
#include "kUnicodeData.h"
#include "kRegExp.h"
#include "regexp_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* the program: a header of words, the code, the class data, the names */
enum { H_MAGIC, H_FLAGS, H_GROUPS, H_LOOPS, H_CODE, H_CODELEN, H_DATA, H_NAMES, H_NAMESLEN, H_SIZE };
#define RX_MAGIC 0x3145524Bu /* "KRE1" */

enum {
    OP_CHAR, OP_ANY, OP_ANYALL, OP_CLASS, OP_SPLIT, OP_JMP, OP_SAVE, OP_BOL, OP_EOL, OP_WORDB, OP_NWORDB,
    OP_BACKREF, OP_LOOK, OP_MATCH, OP_GRAPHEME, OP_RESET, OP_MARK, OP_CHECK
};
#define MAX_CODE (1u << 20)

static bool is_line_end(uint32_t c) { return c == '\n' || c == '\r' || c == 0x2028 || c == 0x2029; }
static bool is_word_cp(uint32_t c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
}
static bool is_space_cp(uint32_t c) {
    return c == 9 || c == 10 || c == 11 || c == 12 || c == 13 || c == ' ' || c == 0xA0 || c == 0x1680 ||
           (c >= 0x2000 && c <= 0x200A) || c == 0x2028 || c == 0x2029 || c == 0x202F || c == 0x205F || c == 0x3000 ||
           c == 0xFEFF;
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
    Parser p;
    Node *tree = rx_parse_pattern(&p, pattern, flags);

    Emitter e = {0};
    e.p = &p;
    emit(&e, OP_SAVE);
    emit(&e, 0);
    emit_node(&e, tree);
    emit(&e, OP_SAVE);
    emit(&e, 1);
    emit(&e, OP_MATCH);
    rx_node_free(tree);

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
    bool bytewise; /* a Bytes (#168): each byte a codepoint of its value */
} Ctx;

/* the codepoint at pos, and before it: of the text, or a byte of a Bytes */
static uint32_t cp_here(Ctx *c, int64_t pos, int *len) {
    if (!c->bytewise)
        return rx_cp_at(c->s, c->n, pos, len);
    *len = pos < c->n ? 1 : 0;
    return pos < c->n ? c->s[pos] : NO_CP;
}

static uint32_t cp_prev(Ctx *c, int64_t pos, int *len) {
    if (!c->bytewise)
        return rx_cp_before(c->s, c->n, pos, len);
    *len = pos > 0 ? 1 : 0;
    return pos > 0 ? c->s[pos - 1] : NO_CP;
}

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
        int64_t k = maxlen == UINT32_MAX ? 0 : c->bytewise ? (pos > maxlen ? pos - maxlen : 0) : back_cps(c->s, pos, maxlen);
        for (; k <= pos && !ok; k++) {
            if (k < pos && !c->bytewise && (c->s[k] & 0xC0) == 0x80)
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
            x = cp_here(c, pos, &len);
            if (x == NO_CP || (code[pc + 2] ? ucd_to_fold(x) : x) != code[pc + 1])
                goto fail;
            pos += len;
            pc += 3;
            continue;
        case OP_ANY:
            x = cp_here(c, pos, &len);
            if (x == NO_CP || is_line_end(x))
                goto fail;
            pos += len;
            pc++;
            continue;
        case OP_ANYALL:
            x = cp_here(c, pos, &len);
            if (x == NO_CP)
                goto fail;
            pos += len;
            pc++;
            continue;
        case OP_CLASS:
            x = cp_here(c, pos, &len);
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
            if (!(pos == 0 || (code[pc + 1] && is_line_end(cp_prev(c, pos, &len)))))
                goto fail;
            pc += 2;
            continue;
        case OP_EOL:
            if (!(pos == c->n || (code[pc + 1] && is_line_end(cp_here(c, pos, &len)))))
                goto fail;
            pc += 2;
            continue;
        case OP_WORDB:
        case OP_NWORDB: {
            uint32_t before = cp_prev(c, pos, &len), after = cp_here(c, pos, &len);
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
                    uint32_t a = cp_here(c, k, &len), b = cp_here(c, pos, &l2);
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
            pos += c->bytewise ? 1 : (int64_t)ucd_grapheme_len(c->s + pos, (size_t)(c->n - pos));
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

static bool search_in(const kv_bytes *prog, const uint8_t *s, int64_t n, bool bytewise, int64_t from, bool sticky,
                      int64_t *caps) {
    const uint32_t *w = prog_words(prog);
    Ctx c = {0};
    c.s = s ? s : (const uint8_t *)"";
    c.n = n;
    c.bytewise = bytewise;
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
    if (c.code[2] == OP_CHAR && !c.code[4]) {
        if (!bytewise)
            first_len = rx_utf8_put(first, c.code[3]);
        else if (c.code[3] < 256)
            first_len = (int)(first[0] = (uint8_t)c.code[3], 1);
        else
            first_len = -1; /* a codepoint no byte is: no match */
    }
    if (first_len < 0) {
        free(c.loops);
        return false;
    }
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
        cp_here(&c, start, &len);
        start += len;
    }
    free(c.stack);
    free(c.loops);
    return found;
}

bool rx_search(const kv_bytes *prog, const kv_string *s, int64_t from, bool sticky, int64_t *caps) {
    return search_in(prog, s->b.at, (int64_t)s->b.count, false, from, sticky, caps);
}

/* a Bytes (#168): matched byte by byte, each byte the codepoint of its
   value, so that \xHH and [\x80-\xFF] mean bytes; \X is one byte */
bool rx_search_bytes(const kv_bytes *prog, const kv_bytes *b, int64_t from, bool sticky, int64_t *caps) {
    return search_in(prog, b->at, (int64_t)b->count, true, from, sticky, caps);
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
            rx_cp_at(t, 4, 0, &len); /* the bytes of this codepoint, as written */
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
        rx_cp_at(s->b.at, n, i, &len);
        i += len;
        cp--;
    }
    return i;
}

int64_t rx_next(const kv_string *s, int64_t byte) {
    int len;
    if (byte >= (int64_t)s->b.count)
        return (int64_t)s->b.count;
    rx_cp_at(s->b.at, (int64_t)s->b.count, byte, &len);
    return byte + len;
}

/* s.escape(&re) (#164): the text with each codepoint of each match as
   \u{...}, and a backslash as \\ anywhere, so that unescape reads it back */
kv_string rx_escape(const kv_bytes *prog, const kv_string *s) {
    kv_string out = kv_string_new();
    const uint8_t *p = s->b.at ? s->b.at : (const uint8_t *)"";
    int64_t n = (int64_t)s->b.count, from = 0, copied = 0;
    int64_t ngroups = rx_groups(prog);
    int64_t *caps = rx_alloc((size_t)(2 * (ngroups + 1)) * sizeof *caps);
    while (from <= n && rx_search(prog, s, from, false, caps)) {
        for (int64_t k = copied; k < caps[0];) {
            int len;
            uint32_t cp = rx_cp_at(p, n, k, &len);
            if (cp == '\\')
                kv_string_append_text(&out, "\\\\");
            else
                kv_string_append_cp(&out, cp);
            k += len;
        }
        for (int64_t k = caps[0]; k < caps[1];) {
            int len;
            uint32_t cp = rx_cp_at(p, n, k, &len);
            char buf[16];
            snprintf(buf, sizeof buf, "\\u{%X}", (unsigned)cp);
            kv_string_append_text(&out, buf);
            k += len;
        }
        copied = caps[1];
        if (caps[1] > caps[0]) {
            from = caps[1];
        } else {
            if (caps[1] >= n)
                break;
            from = rx_next(s, caps[1]);
        }
    }
    free(caps);
    for (int64_t k = copied; k < n;) {
        int len;
        uint32_t cp = rx_cp_at(p, n, k, &len);
        if (cp == '\\')
            kv_string_append_text(&out, "\\\\");
        else
            kv_string_append_cp(&out, cp);
        k += len;
    }
    return out;
}

/* s.unescape(&re) (#165): the escapes read back where the pattern matches,
   each match unescaped as s.unescape() does the whole, the rest as it is */
kv_string rx_unescape(const kv_bytes *prog, const kv_string *s) {
    kv_string out = kv_string_new();
    int64_t n = (int64_t)s->b.count, from = 0, copied = 0;
    int64_t ngroups = rx_groups(prog);
    int64_t *caps = rx_alloc((size_t)(2 * (ngroups + 1)) * sizeof *caps);
    while (from <= n && rx_search(prog, s, from, false, caps)) {
        kv_string_append_owned(&out, rx_slice(s, copied, caps[0]));
        kv_string piece = rx_slice(s, caps[0], caps[1]);
        kv_string_append_owned(&out, kv_string_unescape(&piece));
        kv_string_free(&piece);
        copied = caps[1];
        if (caps[1] > caps[0]) {
            from = caps[1];
        } else {
            if (caps[1] >= n)
                break;
            from = rx_next(s, caps[1]);
        }
    }
    free(caps);
    kv_string_append_owned(&out, rx_slice(s, copied, n));
    return out;
}

/* b.escape(&re) (#168): the bytes as text, each byte the pattern matches as
   \xHH, and so every byte that is not printable ASCII, since a String holds
   text; a backslash as \\ */
static void escape_byte(kv_string *out, uint8_t c) {
    char buf[8];
    snprintf(buf, sizeof buf, "\\x%02X", c);
    kv_string_append_text(out, buf);
}

kv_string rx_escape_bytes(const kv_bytes *prog, const kv_bytes *b) {
    kv_string out = kv_string_new();
    int64_t n = (int64_t)b->count, from = 0, copied = 0;
    int64_t ngroups = rx_groups(prog);
    int64_t *caps = rx_alloc((size_t)(2 * (ngroups + 1)) * sizeof *caps);
    while (from <= n && rx_search_bytes(prog, b, from, false, caps)) {
        for (int64_t k = copied; k < caps[0]; k++) {
            uint8_t c = b->at[k];
            if (c == '\\')
                kv_string_append_text(&out, "\\\\");
            else if (c >= 0x20 && c < 0x7F)
                kv_string_append_cp(&out, c);
            else
                escape_byte(&out, c);
        }
        for (int64_t k = caps[0]; k < caps[1]; k++)
            escape_byte(&out, b->at[k]);
        copied = caps[1];
        if (caps[1] > caps[0]) {
            from = caps[1];
        } else {
            if (caps[1] >= n)
                break;
            from = caps[1] + 1;
        }
    }
    free(caps);
    for (int64_t k = copied; k < n; k++) {
        uint8_t c = b->at[k];
        if (c == '\\')
            kv_string_append_text(&out, "\\\\");
        else if (c >= 0x20 && c < 0x7F)
            kv_string_append_cp(&out, c);
        else
            escape_byte(&out, c);
    }
    return out;
}

/* Bytes.unescape(text, &re) (#168): the bytes of the text, with the escapes
   read back where the pattern matches the text alone */
kv_bytes rx_unescape_bytes(const kv_bytes *prog, const uint8_t *text, size_t len) {
    kv_bytes out = kv_bytes_new();
    kv_string s = {kv_bytes_from(text, len), 0};
    s.count = (size_t)rx_cp_index(&s, (int64_t)len);
    int64_t n = (int64_t)len, from = 0, copied = 0;
    int64_t ngroups = rx_groups(prog);
    int64_t *caps = rx_alloc((size_t)(2 * (ngroups + 1)) * sizeof *caps);
    while (from <= n && rx_search(prog, &s, from, false, caps)) {
        kv_bytes_append(&out, text + copied, (size_t)(caps[0] - copied));
        kv_bytes_append_owned(&out, kv_bytes_unescape(text + caps[0], (size_t)(caps[1] - caps[0])));
        copied = caps[1];
        if (caps[1] > caps[0]) {
            from = caps[1];
        } else {
            if (caps[1] >= n)
                break;
            from = rx_next(&s, caps[1]);
        }
    }
    free(caps);
    kv_bytes_append(&out, text + copied, (size_t)(n - copied));
    kv_string_free(&s);
    return out;
}

/* bytes lo..<hi of a Bytes, a new Bytes (#169) */
kv_bytes rx_bytes_slice(const kv_bytes *b, int64_t lo, int64_t hi) {
    if (lo < 0)
        lo = 0;
    if (hi > (int64_t)b->count)
        hi = (int64_t)b->count;
    return hi > lo ? kv_bytes_from(b->at + lo, (size_t)(hi - lo)) : kv_bytes_new();
}

/* the replacement of one match in a Bytes (#170), JS's patterns over bytes:
   $$, $&, $1..$99, $<name>, $` and $', appended to out */
void rx_expand_bytes(const kv_bytes *prog, const kv_bytes *b, const int64_t *caps, const uint8_t *with, size_t len,
                     kv_bytes *out) {
    int64_t ngroups = rx_groups(prog);
    const uint8_t *p = b->at ? b->at : (const uint8_t *)"";
    int64_t n = (int64_t)b->count;
    for (size_t i = 0; i < len; i++) {
        const uint8_t *t = with + i;
        if (*t != '$' || i + 1 >= len) {
            kv_bytes_push(out, *t);
            continue;
        }
        if (t[1] == '$') {
            kv_bytes_push(out, '$');
            i++;
        } else if (t[1] == '&') {
            kv_bytes_append(out, p + caps[0], (size_t)(caps[1] - caps[0]));
            i++;
        } else if (t[1] == '`') {
            kv_bytes_append(out, p, (size_t)caps[0]);
            i++;
        } else if (t[1] == '\'') {
            kv_bytes_append(out, p + caps[1], (size_t)(n - caps[1]));
            i++;
        } else if (t[1] >= '0' && t[1] <= '9') {
            int g = t[1] - '0', used = 1;
            if (i + 2 < len && t[2] >= '0' && t[2] <= '9' && g * 10 + (t[2] - '0') <= ngroups && g * 10 + (t[2] - '0') >= 1) {
                g = g * 10 + (t[2] - '0');
                used = 2;
            }
            if (g >= 1 && g <= ngroups) {
                if (caps[2 * g] >= 0)
                    kv_bytes_append(out, p + caps[2 * g], (size_t)(caps[2 * g + 1] - caps[2 * g]));
                i += (size_t)used;
            } else {
                kv_bytes_push(out, '$');
            }
        } else if (t[1] == '<') {
            const uint8_t *close = memchr(t + 2, '>', len - i - 2);
            if (!close) {
                kv_bytes_push(out, '$');
                continue;
            }
            char name[128];
            size_t nl = (size_t)(close - (t + 2));
            if (nl >= sizeof name)
                nl = sizeof name - 1;
            memcpy(name, t + 2, nl);
            name[nl] = 0;
            int64_t g = rx_group_named(prog, (const uint8_t *)name);
            if (g > 0 && caps[2 * g] >= 0)
                kv_bytes_append(out, p + caps[2 * g], (size_t)(caps[2 * g + 1] - caps[2 * g]));
            i = (size_t)(close - with);
        } else {
            kv_bytes_push(out, '$');
        }
    }
}
