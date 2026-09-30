/* lexer.c - C's lexical rules, with Kelvin's keywords and punctuators

   Literals are kept verbatim so that C interprets them exactly as it
   always has. */
#include "kelvin.h"

#include <ctype.h>
#include <string.h>

/* C11 keywords plus Kelvin's own: var, as, the sized types, bool, true
   and false. C's numeric type names stay reserved so they can be rejected with
   a hint. */
static const char *keywords[] = {
    "var", "as", "i8", "i16", "i32", "i64", "i128", "u8", "u16", "u32", "u64", "u128",
    "f32", "f64", "bool", "true", "false",
    "auto", "break", "case", "char", "const", "continue", "default", "do",
    "double", "else", "enum", "extern", "float", "for", "goto", "if",
    "inline", "int", "long", "register", "restrict", "return", "short",
    "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
    "unsigned", "void", "volatile", "while", "_Alignas", "_Alignof",
    "_Atomic", "_Bool", "_Complex", "_Generic", "_Imaginary", "_Noreturn",
    "_Static_assert", "_Thread_local", NULL,
};

/* Longest first, for greedy matching. Differences from C:
   `^=` is absent, because `p^ = x` assigns through a pointer; XOR-assign
   is `~=`. `->` is not Kelvin; it is lexed only to point at `p^.m`. */
static const char *puncts[] = {
    "...", "<<=", ">>=",
    "->", "++", "--", "<<", ">>", "<=", ">=", "==", "!=", "&&", "||",
    "+=", "-=", "*=", "/=", "%=", "&=", "|=", "~=",
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
    lx->toks[lx->len++] = (Token){kind, pos, xstrndup(start, (size_t)(end - start))};
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
        error_at(pos, "'%.*s': literals have no suffixes in Kelvin; put the type on the declaration, e.g. 'x: %s = %.*s'",
                 n, s, type, (int)(p - s), s);
    }
    error_at(pos, "malformed number '%.*s'", n, s);
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
        if (*lx->p == '\\')
            step(lx);
        step(lx);
    }
    step(lx);
    push(lx, kind, pos, start, lx->p);
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
   It becomes #include in the generated C, so C's headers are usable. */
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
    if (!accept_word(lx, "as"))
        error_at(here(lx), "expected 'as C' after the header name");
    skip_blanks(lx);
    if (!accept_word(lx, "C"))
        error_at(here(lx), "only 'as C' is supported");
    skip_blanks(lx);
    if (*lx->p && *lx->p != '\n' && !(lx->p[0] == '/' && (lx->p[1] == '/' || lx->p[1] == '*')))
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
        push(&lx, TK_PUNCT, pos, start, lx.p);
    }
    *ntoks = lx.len;
    return lx.toks;
}
