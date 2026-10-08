/* lexer.c - C's lexical rules, with Kelvin's keywords and punctuators

   Literals are kept verbatim so that C interprets them exactly as it
   always has. */
#include "kelvin.h"

#include <ctype.h>
#include <string.h>

/* C11 keywords plus Kelvin's own: as, the sized types, bool, true, false,
   any (only as any^, C's void *), nullptr, cstr (u8^), let and var (#27),
   and String (shelved until Kelvin has a true string type, #22). C's
   numeric type names stay reserved so they can be rejected with a hint.
   `in` is a keyword only in `for i in ...`. */
static const char *keywords[] = {
    "as", "i8", "i16", "i32", "i64", "i128", "u8", "u16", "u32", "u64", "u128",
    "f32", "f64", "bool", "true", "false", "String", "any", "nullptr", "cstr", "Bytes", "let", "var",
    "auto", "break", "case", "char", "const", "continue", "default", "do",
    "double", "else", "enum", "extern", "float", "for", "goto", "if",
    "inline", "int", "long", "register", "restrict", "return", "short",
    "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
    "unsigned", "void", "volatile", "while", "_Alignas", "_Alignof",
    "_Atomic", "_Bool", "_Complex", "_Generic", "_Imaginary", "_Noreturn",
    "_Static_assert", "_Thread_local", NULL,
};

/* C compiler keywords beyond C11 (GNU extensions and C23). In C they act
   as prefix operators or type specifiers, so `__extension__ * p` would be
   C's prefix dereference and `(typeof(x))-1` a cast. Kelvin rejects them. */
static const struct { const char *word, *hint; } foreign_keywords[] = {
    {"__extension__", NULL}, {"__real__", NULL}, {"__real", NULL}, {"__imag__", NULL},
    {"__imag", NULL}, {"__alignof__", NULL}, {"__alignof", NULL}, {"alignof", NULL},
    {"__typeof__", NULL}, {"__typeof", NULL}, {"typeof", NULL}, {"typeof_unqual", NULL},
    {"__typeof_unqual__", NULL}, {"_BitInt", NULL}, {"__int128", "i128 or u128"},
    {"__auto_type", NULL}, {"__label__", NULL}, {"_Float16", NULL}, {"_Float128", NULL},
    {"__float128", NULL}, {"__fp16", NULL}, {"__bf16", NULL}, {"_Decimal32", NULL},
    {"_Decimal64", NULL}, {"_Decimal128", NULL}, {"__signed__", NULL}, {"__signed", NULL},
    {"__complex__", NULL}, {"__complex", NULL},
};

/* Longest first, for greedy matching. Differences from C:
   `^=` is absent, because `p^ = x` assigns through a pointer; XOR-assign
   is `~=`. `->` is not Kelvin; it is lexed only to point at `p^.m`.
   `:=` assigns references (pointers); `=` assigns values. `..<` and
   `...` make ranges in `for i in ...` (#28); `..` is lexed only to
   point at them. */
static const char *puncts[] = {
    "...", "..<", "<<=", ">>=", "..",
    "->", "++", "--", "<<", ">>", "<=", ">=", "==", "!=", "&&", "||",
    "+=", "-=", "*=", "/=", "%=", "&=", "|=", "~=", ":=",
    "+", "-", "*", "/", "%", "&", "|", "^", "~", "!", "<", ">", "=",
    "?", ":", ";", ",", ".", "(", ")", "[", "]", "{", "}", NULL,
};

typedef struct {
    const char *file;
    const char *src;
    const char *p;
    int line, col;
    Token *toks;
    int len, cap;
    /* template literals (#39): the brace depth at each open ${, innermost
       last, where each ${ and its template began, and the depth now */
    int tpl_braces[64], tpl_top, braces;
    Pos tpl_open[64], tpl_start[64];
} Lexer;

static Pos here(Lexer *lx) { return (Pos){lx->file, lx->line, lx->col}; }

static void step(Lexer *lx) {
    if (*lx->p == '\n') {
        lx->line++;
        lx->col = 1;
    } else {
        lx->col++;
    }
    lx->p++;
}

static void push(Lexer *lx, TokKind kind, Pos pos, const char *start, const char *end) {
    if (lx->len == lx->cap) {
        lx->cap = lx->cap ? lx->cap * 2 : 256;
        lx->toks = xrealloc(lx->toks, (size_t)lx->cap * sizeof(Token));
    }
    lx->toks[lx->len++] = (Token){kind, pos, xstrndup(start, (size_t)(end - start)), lx->line, false, false};
}

static void skip_space(Lexer *lx) {
    for (;;) {
        char c = *lx->p;
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '\f' || c == '\v') {
            step(lx);
        } else if (c == '/' && lx->p[1] == '/') {
            while (*lx->p && *lx->p != '\n')
                step(lx);
        } else if (c == '/' && lx->p[1] == '*') {
            Pos start = here(lx);
            step(lx);
            step(lx);
            while (!(lx->p[0] == '*' && lx->p[1] == '/')) {
                if (!*lx->p)
                    error_at(start, "unterminated comment");
                step(lx);
            }
            step(lx);
            step(lx);
        } else {
            return;
        }
    }
}

/* Kelvin literals carry no size or type hints: C's suffixes (10UL, 10u,
   1.5f, 1.5L) are rejected, and the type goes on the declaration instead,
   as in `x: u64 = 10`. */
static void check_number(Pos pos, const char *s, const char *end) {
    const char *p = s;
    bool hex = p[0] == '0' && (p[1] == 'x' || p[1] == 'X');
    bool bin = p[0] == '0' && (p[1] == 'b' || p[1] == 'B');
    bool floating = false;
    if (hex || bin)
        p += 2;
    while (p < end && (hex ? isxdigit((unsigned char)*p) : isdigit((unsigned char)*p)))
        p++;
    if (!bin && p < end && *p == '.') {
        floating = true;
        for (p++; p < end && (hex ? isxdigit((unsigned char)*p) : isdigit((unsigned char)*p)); p++)
            ;
    }
    if (!bin && p < end && strchr(hex ? "pP" : "eE", *p)) {
        floating = true;
        p++;
        if (p < end && (*p == '+' || *p == '-'))
            p++;
        while (p < end && isdigit((unsigned char)*p))
            p++;
    }
    if (p == end)
        return;
    int n = (int)(end - s);
    if (strspn(p, "uUlLfF") >= (size_t)(end - p)) {
        /* suggest the Kelvin type closest to what the suffix meant */
        bool has_f = memchr(p, 'f', (size_t)(end - p)) || memchr(p, 'F', (size_t)(end - p));
        bool has_u = memchr(p, 'u', (size_t)(end - p)) || memchr(p, 'U', (size_t)(end - p));
        const char *type = floating ? (has_f ? "f32" : "f64") : has_u ? "u64" : "i64";
        error_at(pos, "'%.*s': literals have no suffixes in Kelvin; put the type on the declaration, e.g. 'x:%s = %.*s'",
                 n, s, type, (int)(p - s), s);
    }
    error_at(pos, "malformed number '%.*s'", n, s);
}

/* Does the '.' at `dot` start a method call on the number that began at
   `start`, as in 2.cstr or 1.5.hex? It does not when it
   continues the number: 1.5, 1.e5, or a hex float such as 0x1.f4p+9
   (whose fraction may start with a letter). */
static bool method_after_number(const char *start, const char *dot) {
    char next = dot[1];
    if (!isalpha((unsigned char)next) && next != '_')
        return false;
    bool hex = start[0] == '0' && (start[1] == 'x' || start[1] == 'X');
    if (hex) {
        const char *q = dot + 1;
        while (isxdigit((unsigned char)*q))
            q++;
        return !(*q == 'p' || *q == 'P');
    }
    /* 1.e5, 1.E+3 */
    if ((next == 'e' || next == 'E') && (isdigit((unsigned char)dot[2]) || dot[2] == '+' || dot[2] == '-'))
        return false;
    return true;
}

/* A C "preprocessing number": digits, letters, underscores and dots, plus
   a sign directly after an exponent letter. */
static void lex_number(Lexer *lx) {
    Pos pos = here(lx);
    const char *start = lx->p;
    for (;;) {
        char c = *lx->p;
        if ((c == '+' || c == '-') && strchr("eEpP", lx->p[-1])) {
            step(lx);
        } else if (c == '.' && (method_after_number(start, lx->p) || lx->p[1] == '.')) {
            break; /* `2.cstr`, and `0..<n`: the number ends before them */
        } else if (isalnum((unsigned char)c) || c == '_' || c == '.') {
            step(lx);
        } else {
            break;
        }
    }
    check_number(pos, start, lx->p);
    push(lx, TK_NUMBER, pos, start, lx->p);
}

static void lex_quoted(Lexer *lx, char quote, TokKind kind) {
    Pos pos = here(lx);
    const char *start = lx->p;
    step(lx);
    while (*lx->p != quote) {
        if (!*lx->p || *lx->p == '\n')
            error_at(pos, quote == '"' ? "unterminated string literal" : "unterminated character constant");
        if (*lx->p == '\\' && lx->p[1]) /* not past the end of the text */
            step(lx);
        step(lx);
    }
    step(lx);
    push(lx, kind, pos, start, lx->p);
}

/* A template literal's text from the cursor (after its backquote, or
   after the } that ends a ${...}) up to its closing backquote or the next
   ${, as a C string literal: a new line is \n, \` is a backquote and \$
   a dollar sign, a backslash before a new line joins the lines, and other
   escapes are C's (#39). A template with no ${ is a string literal. */
static void lex_template(Lexer *lx, Pos pos, Pos start, bool head) {
    Buf lit = {0};
    buf_puts(&lit, "\"");
    TokKind kind;
    for (;;) {
        char c = *lx->p;
        if (!c)
            error_at(start, "unterminated template literal: it ends with a backquote");
        if (c == '`') {
            step(lx);
            kind = head ? TK_STRING : TK_TPL_TAIL;
            break;
        }
        if (c == '$' && lx->p[1] == '{') {
            step(lx);
            step(lx);
            if (lx->tpl_top == (int)(sizeof lx->tpl_braces / sizeof lx->tpl_braces[0]))
                error_at(pos, "template literals are nested too deeply");
            lx->tpl_open[lx->tpl_top] = (Pos){lx->file, lx->line, lx->col - 2};
            lx->tpl_start[lx->tpl_top] = start;
            lx->tpl_braces[lx->tpl_top++] = lx->braces;
            kind = head ? TK_TPL_HEAD : TK_TPL_MIDDLE;
            break;
        }
        if (c == '\\' && (lx->p[1] == '`' || lx->p[1] == '$' || lx->p[1] == '{' || lx->p[1] == '}')) {
            buf_putn(&lit, lx->p + 1, 1);
            step(lx);
        } else if (c == '\\' && lx->p[1] == '\n') {
            step(lx);
        } else if (c == '\\' && lx->p[1] == '\r' && lx->p[2] == '\n') {
            step(lx);
            step(lx);
        } else if (c == '\\' && lx->p[1]) {
            buf_putn(&lit, lx->p, 2);
            step(lx);
        } else if (c == '"') {
            buf_puts(&lit, "\\\"");
        } else if (c == '\n') {
            buf_puts(&lit, "\\n");
        } else if (c == '\r' && lx->p[1] == '\n') { /* a CRLF line end is a new line */
            buf_puts(&lit, "\\n");
            step(lx);
        } else if (c == '\r') {
            buf_puts(&lit, "\\r");
        } else if (c == '?') { /* never a C trigraph */
            buf_puts(&lit, "\\?");
        } else {
            buf_putn(&lit, lx->p, 1);
        }
        step(lx);
    }
    buf_puts(&lit, "\"");
    push(lx, kind, pos, lit.buf, lit.buf + lit.len);
    lx->toks[lx->len - 1].tpl = kind == TK_STRING;
}

static void skip_blanks(Lexer *lx) {
    while (*lx->p == ' ' || *lx->p == '\t')
        step(lx);
}

static bool accept_word(Lexer *lx, const char *w) {
    size_t n = strlen(w);
    if (strncmp(lx->p, w, n) != 0 || isalnum((unsigned char)lx->p[n]) || lx->p[n] == '_')
        return false;
    for (size_t i = 0; i < n; i++)
        step(lx);
    return true;
}

/* The only directive so far:  #import <header.h> as C  (or "header.h").
   It becomes #include in the generated C, so C's headers are usable.
   #import <x.k> or "x.k", without `as C`, brings in a Kelvin file
   (#40). */
static void lex_import(Lexer *lx) {
    Pos pos = here(lx);
    for (const char *q = lx->p; q > lx->src && q[-1] != '\n'; q--)
        if (q[-1] != ' ' && q[-1] != '\t')
            error_at(pos, "'#' must start a line");
    step(lx);
    skip_blanks(lx);
    if (!accept_word(lx, "import"))
        error_at(pos, "only '#import <header.h> as C' is supported; the rest of the preprocessor is TODO");
    skip_blanks(lx);
    char close = *lx->p == '<' ? '>' : *lx->p == '"' ? '"' : 0;
    if (!close)
        error_at(here(lx), "expected a header name like <stdio.h> or \"mylib.h\"");
    const char *start = lx->p;
    step(lx);
    while (*lx->p != close) {
        if (!*lx->p || *lx->p == '\n')
            error_at(pos, "unterminated header name");
        step(lx);
    }
    step(lx);
    const char *end = lx->p;
    skip_blanks(lx);
    bool kelvin = end - start > 4 && !strncmp(end - 3, ".k", 2);
    if (kelvin) {
        if (accept_word(lx, "as"))
            error_at(pos, "a Kelvin file is imported as it is: write '#import %.*s' without 'as C'",
                     (int)(end - start), start);
        if (*lx->p && *lx->p != '\n' && !(lx->p[0] == '\r' && lx->p[1] == '\n') &&
            !(lx->p[0] == '/' && (lx->p[1] == '/' || lx->p[1] == '*')))
            error_at(here(lx), "unexpected text after '#import %.*s'", (int)(end - start), start);
        push(lx, TK_IMPORT_K, pos, start, end);
        return;
    }
    if (!accept_word(lx, "as"))
        error_at(here(lx), "expected 'as C' after the header name");
    skip_blanks(lx);
    if (!accept_word(lx, "C"))
        error_at(here(lx), "only 'as C' is supported");
    skip_blanks(lx);
    if (*lx->p && *lx->p != '\n' && !(lx->p[0] == '\r' && lx->p[1] == '\n') &&
        !(lx->p[0] == '/' && (lx->p[1] == '/' || lx->p[1] == '*')))
        error_at(here(lx), "unexpected text after '#import ... as C'");
    push(lx, TK_IMPORT, pos, start, end);
}

Token *lex(const char *file, const char *src, int *ntoks) {
    Lexer lx = {.file = file, .src = src, .p = src, .line = 1, .col = 1};
    for (;;) {
        skip_space(&lx);
        char c = *lx.p;
        Pos pos = here(&lx);
        if (!c) {
            static const char eof[] = "end of file";
            push(&lx, TK_EOF, pos, eof, eof + sizeof eof - 1);
            break;
        }
        if (c == '#') {
            lex_import(&lx);
            continue;
        }
        if (isalpha((unsigned char)c) || c == '_') {
            const char *start = lx.p;
            while (isalnum((unsigned char)*lx.p) || *lx.p == '_')
                step(&lx);
            push(&lx, TK_IDENT, pos, start, lx.p);
            Token *t = &lx.toks[lx.len - 1];
            for (int i = 0; keywords[i]; i++)
                if (!strcmp(t->text, keywords[i]))
                    t->kind = TK_KEYWORD;
            for (size_t i = 0; i < sizeof foreign_keywords / sizeof foreign_keywords[0]; i++)
                if (!strcmp(t->text, foreign_keywords[i].word)) {
                    if (foreign_keywords[i].hint)
                        error_at(pos, "'%s' is a C compiler keyword; use %s", t->text, foreign_keywords[i].hint);
                    error_at(pos, "'%s' is a C compiler keyword, not available in Kelvin", t->text);
                }
            continue;
        }
        if (isdigit((unsigned char)c) || (c == '.' && isdigit((unsigned char)lx.p[1]))) {
            lex_number(&lx);
            continue;
        }
        if (c == '"') {
            lex_quoted(&lx, '"', TK_STRING);
            continue;
        }
        if (c == '\'') {
            lex_quoted(&lx, '\'', TK_CHAR);
            continue;
        }
        if (c == '`') {
            step(&lx);
            lex_template(&lx, pos, pos, true);
            continue;
        }
        if (c == '$') {
            /* $0, $1, ... and $ (for $[k]): the parameters of an
               anonymous function (#32) */
            const char *start = lx.p;
            step(&lx);
            while (isdigit((unsigned char)*lx.p))
                step(&lx);
            push(&lx, TK_PUNCT, pos, start, lx.p);
            continue;
        }
        const char *match = NULL;
        for (int i = 0; puncts[i]; i++)
            if (!strncmp(lx.p, puncts[i], strlen(puncts[i]))) {
                match = puncts[i];
                break;
            }
        if (!match)
            error_at(pos, "unexpected character '%c'", c);
        const char *start = lx.p;
        for (size_t i = 0; i < strlen(match); i++)
            step(&lx);
        /* the } that ends a template's ${...} goes on with its text */
        if (!strcmp(match, "}") && lx.tpl_top && lx.braces == lx.tpl_braces[lx.tpl_top - 1]) {
            lx.tpl_top--;
            lex_template(&lx, pos, lx.tpl_start[lx.tpl_top], false);
            continue;
        }
        lx.braces += !strcmp(match, "{") - !strcmp(match, "}");
        push(&lx, TK_PUNCT, pos, start, lx.p);
    }
    if (lx.tpl_top)
        error_at(lx.tpl_open[lx.tpl_top - 1], "unterminated ${...} in a template literal: it ends with '}'");
    *ntoks = lx.len;
    return lx.toks;
}
