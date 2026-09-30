/* lexer.c - turn source text into tokens */
#include "kelvin.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

static const char *keywords[] = {
    "fn",     "extern", "struct", "let",   "var",   "if",    "else",
    "while",  "for",    "in",     "return", "break", "continue", "defer",
    "as",     "true",   "false",  "null",  "sizeof", NULL,
};

/* Longest spellings first so that greedy matching works. */
static const char *puncts[] = {
    "...", "+%=", "-%=", "*%=", "<<=", ">>=",
    "->", "..", "==", "!=", "<=", ">=", "&&", "||", "<<", ">>",
    "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "+%", "-%", "*%",
    "+", "-", "*", "/", "%", "&", "|", "^", "~", "!", "<", ">", "=",
    "(", ")", "{", "}", "[", "]", ",", ";", ":", ".", NULL,
};

typedef struct {
    const char *file;
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

static Token *push(Lexer *lx, TokKind kind, Pos pos) {
    if (lx->len == lx->cap) {
        lx->cap = lx->cap ? lx->cap * 2 : 256;
        lx->toks = xrealloc(lx->toks, (size_t)lx->cap * sizeof(Token));
    }
    Token *t = &lx->toks[lx->len++];
    memset(t, 0, sizeof *t);
    t->kind = kind;
    t->pos = pos;
    return t;
}

static void skip_space(Lexer *lx) {
    for (;;) {
        char c = *lx->p;
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
            step(lx);
        } else if (c == '/' && lx->p[1] == '/') {
            while (*lx->p && *lx->p != '\n')
                step(lx);
        } else if (c == '/' && lx->p[1] == '*') {
            /* block comments nest, so commenting out code always works */
            Pos start = here(lx);
            int depth = 0;
            do {
                if (!*lx->p)
                    error_at(start, "unterminated block comment");
                if (lx->p[0] == '/' && lx->p[1] == '*') {
                    depth++;
                    step(lx);
                } else if (lx->p[0] == '*' && lx->p[1] == '/') {
                    depth--;
                    step(lx);
                }
                step(lx);
            } while (depth > 0);
        } else {
            return;
        }
    }
}

static int digit_value(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return 99;
}

static void lex_number(Lexer *lx) {
    Pos pos = here(lx);
    const char *start = lx->p;
    int base = 10;
    if (lx->p[0] == '0' && (lx->p[1] == 'x' || lx->p[1] == 'X')) base = 16;
    if (lx->p[0] == '0' && (lx->p[1] == 'b' || lx->p[1] == 'B')) base = 2;
    if (lx->p[0] == '0' && (lx->p[1] == 'o' || lx->p[1] == 'O')) base = 8;
    if (base != 10) {
        step(lx);
        step(lx);
    }

    bool is_float = false;
    if (base == 10) {
        const char *q = lx->p;
        while (isdigit((unsigned char)*q) || *q == '_')
            q++;
        /* "1..2" is a range, "1.5" is a float */
        if (q[0] == '.' && isdigit((unsigned char)q[1]))
            is_float = true;
        else if (q[0] == 'e' || q[0] == 'E')
            is_float = true;
    }

    if (is_float) {
        Buf b = {0};
        while (isdigit((unsigned char)*lx->p) || *lx->p == '_' || *lx->p == '.' ||
               *lx->p == 'e' || *lx->p == 'E' ||
               ((*lx->p == '+' || *lx->p == '-') && (lx->p[-1] == 'e' || lx->p[-1] == 'E'))) {
            if (*lx->p != '_')
                buf_putn(&b, lx->p, 1);
            step(lx);
        }
        char *end;
        double v = strtod(b.buf, &end);
        if (*end)
            error_at(pos, "malformed float literal");
        Token *t = push(lx, TK_FLOAT, pos);
        t->fval = v;
        t->text = xstrndup(start, (size_t)(lx->p - start));
        free(b.buf);
        return;
    }

    uint64_t v = 0;
    int ndigits = 0;
    while (isalnum((unsigned char)*lx->p) || *lx->p == '_') {
        if (*lx->p == '_') {
            step(lx);
            continue;
        }
        int d = digit_value(*lx->p);
        if (d >= base)
            error_at(here(lx), "invalid digit '%c' in base-%d literal", *lx->p, base);
        if (v > (UINT64_MAX - (uint64_t)d) / (uint64_t)base)
            error_at(pos, "integer literal is too large for 64 bits");
        v = v * (uint64_t)base + (uint64_t)d;
        ndigits++;
        step(lx);
    }
    if (ndigits == 0)
        error_at(pos, "integer literal has no digits");
    Token *t = push(lx, TK_INT, pos);
    t->ival = v;
    t->text = xstrndup(start, (size_t)(lx->p - start));
}

static int lex_escape(Lexer *lx) {
    Pos pos = here(lx);
    step(lx); /* backslash */
    char c = *lx->p;
    step(lx);
    switch (c) {
    case 'n': return '\n';
    case 't': return '\t';
    case 'r': return '\r';
    case '0': return '\0';
    case '\\': return '\\';
    case '\'': return '\'';
    case '"': return '"';
    case 'x': {
        int hi = digit_value(lx->p[0]), lo = digit_value(lx->p[1]);
        if (hi > 15 || lo > 15)
            error_at(pos, "\\x escape needs exactly two hex digits");
        step(lx);
        step(lx);
        return hi * 16 + lo;
    }
    default:
        error_at(pos, "unknown escape sequence '\\%c'", c);
    }
}

static void lex_string(Lexer *lx) {
    Pos pos = here(lx);
    step(lx);
    Buf b = {0};
    buf_puts(&b, "");
    while (*lx->p != '"') {
        if (!*lx->p || *lx->p == '\n')
            error_at(pos, "unterminated string literal");
        if (*lx->p == '\\') {
            char c = (char)lex_escape(lx);
            buf_putn(&b, &c, 1);
        } else {
            buf_putn(&b, lx->p, 1);
            step(lx);
        }
    }
    step(lx);
    Token *t = push(lx, TK_STR, pos);
    t->sval = b.buf;
    t->slen = b.len;
    t->text = "string literal";
}

static void lex_char(Lexer *lx) {
    Pos pos = here(lx);
    step(lx);
    int c;
    if (*lx->p == '\\') {
        c = lex_escape(lx);
    } else {
        if (!*lx->p || *lx->p == '\'' || *lx->p == '\n')
            error_at(pos, "empty character literal");
        if ((unsigned char)*lx->p >= 0x80)
            error_at(pos, "character literals must be ASCII; use a string for UTF-8");
        c = (unsigned char)*lx->p;
        step(lx);
    }
    if (*lx->p != '\'')
        error_at(pos, "unterminated character literal");
    step(lx);
    Token *t = push(lx, TK_INT, pos);
    t->ival = (uint64_t)c;
    t->text = "character literal";
}

Token *lex(const char *file, const char *src, int *ntoks) {
    Lexer lx = {.file = file, .p = src, .line = 1, .col = 1};
    for (;;) {
        skip_space(&lx);
        char c = *lx.p;
        Pos pos = here(&lx);
        if (!c) {
            push(&lx, TK_EOF, pos)->text = "end of file";
            break;
        }
        if (isalpha((unsigned char)c) || c == '_') {
            const char *start = lx.p;
            while (isalnum((unsigned char)*lx.p) || *lx.p == '_')
                step(&lx);
            char *word = xstrndup(start, (size_t)(lx.p - start));
            TokKind kind = TK_IDENT;
            for (int i = 0; keywords[i]; i++)
                if (!strcmp(word, keywords[i]))
                    kind = TK_KEYWORD;
            if (kind == TK_IDENT && !strncmp(word, "kv_", 3))
                error_at(pos, "identifiers beginning with 'kv_' are reserved");
            push(&lx, kind, pos)->text = word;
            continue;
        }
        if (isdigit((unsigned char)c)) {
            lex_number(&lx);
            continue;
        }
        if (c == '"') {
            lex_string(&lx);
            continue;
        }
        if (c == '\'') {
            lex_char(&lx);
            continue;
        }
        const char *match = NULL;
        for (int i = 0; puncts[i]; i++) {
            size_t n = strlen(puncts[i]);
            if (!strncmp(lx.p, puncts[i], n)) {
                match = puncts[i];
                break;
            }
        }
        if (!match)
            error_at(pos, "unexpected character '%c'", c);
        for (size_t i = 0; i < strlen(match); i++)
            step(&lx);
        push(&lx, TK_PUNCT, pos)->text = (char *)match;
    }
    *ntoks = lx.len;
    return lx.toks;
}
