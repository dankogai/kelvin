/* lexer.c - C's lexical rules, with Kelvin's keywords and punctuators

   Literals are kept verbatim so that C interprets them exactly as it
   always has. */
#include "kelvin.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

/* C11 keywords plus Kelvin's own: as, the sized types, bool, true, false,
   any (only as any^, C's void *), nullptr, cstr (u8^), let and var (#27),
   and String (shelved until Kelvin has a true string type, #22); Task,
   async and await, its threads (#312). C's
   numeric type names stay reserved so they can be rejected with a hint.
   `in` is a keyword only in `for i in ...`. */
static const char *keywords[] = {
    "as", "i8", "i16", "i32", "i64", "i128", "u8", "u16", "u32", "u64", "u128",
    "f32", "f64", "bool", "true", "false", "String", "any", "nullptr", "cstr", "Bytes", "uchr", "Array", "Dictionary", "Set", "Optional", "Result", "IO", "OS", "SYS", "try", "let", "var",
    "Task", "async", "await",
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
    "...", "..<", "<<=", ">>=", "?\?=", "!!=", "..",
    "->", "++", "--", "<<", ">>", "<=", ">=", "==", "!=", "&&", "||",
    "+=", "-=", "*=", "/=", "%=", "&=", "|=", "~=", ":=", "??", "!!",
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
    lx->toks[lx->len++] = (Token){kind, pos, xstrndup(start, (size_t)(end - start)), lx->line, false, false, false};
}

/* s[0..n) with a backslash before each '?' that follows a '?': Kelvin has
   no trigraphs (#220), which C11 reads before anything else, in a string,
   a character or a comment, as it reads two '?' and a '!' as a '|'. \? is
   C's escape of ?, so the text is the same */
static char *untrigraphed(const char *s, size_t n) {
    Buf b = {0};
    for (size_t i = 0; i < n; i++) {
        if (s[i] == '?' && i > 0 && s[i - 1] == '?')
            buf_puts(&b, "\\");
        buf_putn(&b, s + i, 1);
    }
    return b.buf ? b.buf : xstrdup("");
}

/* runtime/regexp_parse.c, linked into kelvinc: is the pattern one? (#163) */
const char *rx_check(const char *pattern, const char *flags, size_t *at);

/* a token kelvinc writes itself, for a literal that becomes a call (#157) */
static void push_text(Lexer *lx, TokKind kind, Pos pos, const char *text) {
    push(lx, kind, pos, text, text + strlen(text));
}

/* $/pattern/flags (#157): a regular expression, as JS writes one, which
   becomes RegExp.compile("pattern", "flags") and so needs #import <RegExp>.
   The pattern ends at the first '/' that is not escaped and not in [...],
   on the same line, and is written into the C literal as it is, with \,
   " and ? escaped (?? would start a trigraph); the flags are the letters
   after it. */
static void lex_regexp(Lexer *lx, Pos pos) {
    step(lx);
    step(lx);
    const char *start = lx->p;
    bool in_class = false;
    for (;;) {
        char d = *lx->p;
        if (!d || d == '\n')
            error_at(pos, "unterminated $/.../: a regular expression ends with '/' on its line");
        if (d == '\\' && lx->p[1] && lx->p[1] != '\n') {
            step(lx);
            step(lx);
            continue;
        }
        if (d == '[')
            in_class = true;
        else if (d == ']')
            in_class = false;
        else if (d == '/' && !in_class)
            break;
        step(lx);
    }
    const char *end = lx->p;
    step(lx);
    const char *fstart = lx->p;
    while (isalpha((unsigned char)*lx->p))
        step(lx);
    char *lit = xmalloc(2 * (size_t)(end - start) + 3), *q = lit;
    *q++ = '"';
    for (const char *s = start; s < end; s++) {
        if (*s == '\\' || *s == '"' || *s == '?')
            *q++ = '\\';
        *q++ = *s;
    }
    *q++ = '"';
    *q = 0;
    char *flags = strfmt("\"%.*s\"", (int)(lx->p - fstart), fstart);
    /* the pattern checked now, by the parser of RegExp linked into kelvinc (#163) */
    char *pattern = xstrndup(start, (size_t)(end - start)), *bare = xstrndup(fstart, (size_t)(lx->p - fstart));
    size_t at = 0;
    const char *wrong = rx_check(pattern, bare, &at);
    if (wrong) {
        Pos where = pos;
        where.col += 2 + (int)at;
        error_at(where, "a $/.../ literal that is not a regular expression: %s", wrong);
    }
    free(pattern);
    free(bare);
    push_text(lx, TK_IDENT, pos, "RegExp");
    lx->toks[lx->len - 1].regexp = true;
    push_text(lx, TK_PUNCT, pos, ".");
    push_text(lx, TK_IDENT, pos, "compile");
    push_text(lx, TK_PUNCT, pos, "(");
    push_text(lx, TK_STRING, pos, lit);
    push_text(lx, TK_PUNCT, pos, ",");
    push_text(lx, TK_STRING, pos, flags);
    push_text(lx, TK_PUNCT, pos, ")");
    free(lit);
    free(flags);
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

/* The \u escapes of a C string literal's text (#292): \u{...}, \uXXXX and
   \UXXXXXXXX, each a codepoint, as its UTF-8 bytes in octal, three digits
   each, which C takes for any codepoint, where its own universal character
   names refuse a control character, U+0000 to U+009F; a surrogate, or one
   past 10FFFF, is an error. Every other escape stays C's */
static char *ucn_text(Pos pos, const char *text) {
    Buf out = {0};
    buf_puts(&out, "");
    for (const char *p = text; *p;) {
        if (p[0] != '\\' || !p[1]) {
            buf_putn(&out, p, 1);
            p++;
            continue;
        }
        if (p[1] != 'u' && p[1] != 'U') {
            buf_putn(&out, p, 2); /* \\, \n, \x41: C's, the u of \\u included */
            p += 2;
            continue;
        }
        const char *q = p + 2;
        unsigned long cp = 0;
        int digits = 0;
        bool braced = p[1] == 'u' && *q == '{';
        int want = braced ? 0 : p[1] == 'u' ? 4 : 8;
        if (braced)
            q++;
        while (isxdigit((unsigned char)*q) && (braced ? digits < 8 : digits < want)) {
            cp = cp * 16 + (unsigned long)(isdigit((unsigned char)*q) ? *q - '0' : tolower((unsigned char)*q) - 'a' + 10);
            q++;
            digits++;
        }
        if (braced ? (!digits || *q != '}') : digits != want)
            error_at(pos, "a \\u escape is \\u{X}, \\uXXXX or \\UXXXXXXXX: a codepoint in hex digits (#292)");
        if (braced)
            q++;
        if (cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF))
            error_at(pos, "\\u{%lX} is no codepoint: a surrogate, D800 to DFFF, or past 10FFFF (#292)", cp);
        unsigned char u[4];
        int n = cp < 0x80 ? 1 : cp < 0x800 ? 2 : cp < 0x10000 ? 3 : 4;
        if (n == 1) {
            u[0] = (unsigned char)cp;
        } else {
            for (int i = n - 1; i > 0; i--, cp >>= 6)
                u[i] = (unsigned char)(0x80 | (cp & 0x3F));
            u[0] = (unsigned char)((n == 2 ? 0xC0 : n == 3 ? 0xE0 : 0xF0) | cp);
        }
        for (int i = 0; i < n; i++) {
            char oct[5];
            snprintf(oct, sizeof oct, "\\%03o", u[i]);
            buf_puts(&out, oct);
        }
        p = q;
    }
    return out.buf;
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
    char *text = untrigraphed(start, (size_t)(lx->p - start)); /* never a C trigraph (#220) */
    if (quote == '"') { /* \u{7f} too (#292) */
        char *t = ucn_text(pos, text);
        free(text);
        text = t;
    }
    push(lx, kind, pos, text, text + strlen(text));
    free(text);
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
    char *text = ucn_text(start, lit.buf); /* \u{7f} too (#292) */
    push(lx, kind, pos, text, text + strlen(text));
    free(text);
    free(lit.buf);
    lx->toks[lx->len - 1].tpl = kind == TK_STRING;
}

/* """text""" (#115, #118): the text between the quotes as it is, over any
   number of lines, with no escapes and no ${...}, as a C string literal.
   The delimiter is a run of three or more quotes, closed by a run as
   long, so a longer one holds a """; the extra quotes of a longer closing
   run are text. In the form with the text on its own lines, the line
   break after the opening run and the one before the closing run are
   not text, and the closing run's own indentation is taken off each
   line. A new line is \n, and a backslash, a quote and a ? are escaped
   for C. A string literal, a cstr, as any other; adjacent ones join */
static void lex_triple(Lexer *lx) {
    Pos pos = here(lx);
    int n = 0;
    while (*lx->p == '"') {
        step(lx);
        n++;
    }
    Buf raw = {0};
    buf_puts(&raw, "");
    for (;;) {
        if (!*lx->p)
            error_at(pos, "unterminated \"\"\" string: it ends with %d quotes, as it began", n);
        if (*lx->p == '"') {
            int run = 0;
            while (*lx->p == '"') {
                step(lx);
                run++;
            }
            if (run >= n) { /* the last n close it; the rest are text */
                for (int k = 0; k < run - n; k++)
                    buf_puts(&raw, "\"");
                break;
            }
            for (int k = 0; k < run; k++)
                buf_puts(&raw, "\"");
            continue;
        }
        if (*lx->p == '\r' && lx->p[1] == '\n') /* a CRLF line end is a new line */
            step(lx);
        buf_putn(&raw, lx->p, 1);
        step(lx);
    }
    /* the form on its own lines: the first line break is not text, nor
       the last one and the indentation before the closing quotes, which
       comes off the start of every line that has it */
    char *text = raw.buf;
    size_t len = raw.len;
    const char *indent = NULL;
    size_t indent_len = 0;
    if (len && text[0] == '\n') {
        text++;
        len--;
        size_t last = len;
        while (last > 0 && (text[last - 1] == ' ' || text[last - 1] == '\t'))
            last--;
        if (last > 0 && text[last - 1] == '\n') {
            indent = text + last;
            indent_len = len - last;
            len = last - 1;
        } else if (last == 0) {
            indent = text;
            indent_len = len;
            len = 0;
        }
    }
    Buf lit = {0};
    buf_puts(&lit, "\"");
    bool at_line_start = true;
    for (size_t i = 0; i < len; i++) {
        if (at_line_start && indent_len && len - i >= indent_len && !memcmp(text + i, indent, indent_len)) {
            i += indent_len - 1;
            at_line_start = false;
            continue;
        }
        char c = text[i];
        at_line_start = c == '\n';
        if (c == '\\')
            buf_puts(&lit, "\\\\");
        else if (c == '"')
            buf_puts(&lit, "\\\"");
        else if (c == '\n')
            buf_puts(&lit, "\\n");
        else if (c == '\r')
            buf_puts(&lit, "\\r");
        else if (c == '?') /* never a C trigraph */
            buf_puts(&lit, "\\?");
        else
            buf_putn(&lit, &c, 1);
    }
    buf_puts(&lit, "\"");
    push(lx, TK_STRING, pos, lit.buf, lit.buf + lit.len);
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

/* nothing but blanks and a comment to the end of the line */
static bool line_ends(Lexer *lx) {
    return !*lx->p || *lx->p == '\n' || (lx->p[0] == '\r' && lx->p[1] == '\n') ||
           (lx->p[0] == '/' && (lx->p[1] == '/' || lx->p[1] == '*'));
}

/* #inline C { ... } (#197): C, written into the generated C where it
   stands. The C ends at the '}' that matches the '{', counted as C
   counts them, outside its strings, characters and comments. It holds
   no line of C's preprocessor, and no Kelvin directive nests in it
   (#296): a '#' that begins a line is an error that says which. */
static void lex_inline_c(Lexer *lx, Pos pos) {
    skip_blanks(lx);
    if (!accept_word(lx, "C"))
        error_at(here(lx), "expected 'C' after '#inline': #inline C { ... }");
    skip_blanks(lx);
    if (*lx->p != '{')
        error_at(here(lx), "expected '{' after '#inline C', on the same line");
    step(lx);
    const char *start = lx->p;
    int depth = 1;
    bool line_start = true; /* only blanks since the '{' or a new line */
    for (;;) {
        char c = *lx->p;
        if (!c)
            error_at(pos, "unterminated '#inline C {': it ends with the '}' that matches its '{'");
        if (c == '#' && line_start) {
            const char *w = lx->p + 1;
            while (*w == ' ' || *w == '\t')
                w++;
            size_t n = 0;
            while (isalpha((unsigned char)w[n]))
                n++;
            if ((n == 6 && !strncmp(w, "import", 6)) || (n == 6 && !strncmp(w, "inline", 6)))
                error_at(here(lx), "'#%.*s' does not nest in '#inline C': Kelvin's directives stand at the top level, "
                                   "or among a function's statements (#296)",
                         (int)n, w);
            error_at(here(lx), "'#%.*s' in '#inline C' is C's preprocessor, which Kelvin leaves out (#296): import a "
                               "header with '#import <x.h> as C' outside it, and write a constant as an enum's or a "
                               "Kelvin let",
                     (int)n, w);
        }
        if (c == '\n')
            line_start = true;
        else if (c != ' ' && c != '\t' && c != '\r' && !(c == '/' && (lx->p[1] == '/' || lx->p[1] == '*')))
            line_start = false;
        if (c == '/' && lx->p[1] == '/') {
            while (*lx->p && *lx->p != '\n')
                step(lx);
            continue;
        }
        if (c == '/' && lx->p[1] == '*') {
            Pos at = here(lx);
            step(lx);
            step(lx);
            while (!(lx->p[0] == '*' && lx->p[1] == '/')) {
                if (!*lx->p)
                    error_at(at, "unterminated comment in '#inline C'");
                step(lx);
            }
            step(lx);
            step(lx);
            continue;
        }
        if (c == '"' || c == '\'') {
            Pos at = here(lx);
            step(lx);
            while (*lx->p != c) {
                if (!*lx->p || *lx->p == '\n')
                    error_at(at, "unterminated %s in '#inline C'", c == '"' ? "string" : "character");
                if (*lx->p == '\\' && lx->p[1])
                    step(lx);
                step(lx);
            }
            step(lx);
            continue;
        }
        if (c == '{')
            depth++;
        if (c == '}' && --depth == 0)
            break;
        if (c == '?' && lx->p[1] == '?')
            error_at(here(lx), "'?\?' in '#inline C' is a trigraph of C, which Kelvin does not have (#220): write what it "
                               "stands for");
        step(lx);
    }
    const char *end = lx->p;
    step(lx);
    skip_blanks(lx);
    if (!line_ends(lx))
        error_at(here(lx), "unexpected text after the '}' of '#inline C'");
    /* its strings, characters and comments have no trigraph either (#220) */
    char *text = untrigraphed(start, (size_t)(end - start));
    push(lx, TK_INLINE_C, pos, text, text + strlen(text));
    free(text);
}

/* The directives: #import <header.h> as C (or "header.h"), which becomes
   #include in the generated C, so C's headers are usable; #import <x.k>
   or "x.k", without `as C`, which brings in a Kelvin file (#40); and
   #inline C { ... }, C of the program's own (#197). */
static void lex_import(Lexer *lx) {
    Pos pos = here(lx);
    for (const char *q = lx->p; q > lx->src && q[-1] != '\n'; q--)
        if (q[-1] != ' ' && q[-1] != '\t')
            error_at(pos, "'#' must start a line");
    step(lx);
    skip_blanks(lx);
    if (accept_word(lx, "inline")) {
        lex_inline_c(lx, pos);
        return;
    }
    if (!accept_word(lx, "import"))
        error_at(pos, "only '#import <header.h> as C' and '#inline C { ... }' are supported; C's preprocessor "
                      "Kelvin leaves out (#296)");
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
    /* a Kelvin file ends with .k, or has no extension at all: <JSON> is <JSON.k> (#112) */
    bool kelvin = (end - start > 4 && !strncmp(end - 3, ".k", 2)) ||
                  (end - start > 5 && !strncmp(end - 4, ".kh", 3)) || /* a module's header (#143) */
                  !memchr(start + 1, '.', (size_t)(end - start - 2));
    if (kelvin) {
        if (accept_word(lx, "as"))
            error_at(pos, "a Kelvin file is imported as it is: write '#import %.*s' without 'as C'",
                     (int)(end - start), start);
        if (!line_ends(lx))
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
    if (!line_ends(lx))
        error_at(here(lx), "unexpected text after '#import ... as C'");
    for (const char *q = start; q + 1 < end; q++) /* a header name has no escapes to break one with */
        if (q[0] == '?' && q[1] == '?')
            error_at(pos, "a header name with '?\?' is a trigraph of C, which Kelvin does not have (#220)");
    push(lx, TK_IMPORT, pos, start, end);
}

/* the length of the valid UTF-8 sequence at p, or 0: no overlong form, no
   surrogate, nothing past 10FFFF */
static int utf8_length(const unsigned char *p) {
    unsigned char c = p[0];
    if (c < 0x80)
        return 1;
    int n = c >= 0xC2 && c <= 0xDF ? 2 : c >= 0xE0 && c <= 0xEF ? 3 : c >= 0xF0 && c <= 0xF4 ? 4 : 0;
    if (!n)
        return 0;
    unsigned char lo = c == 0xE0 ? 0xA0 : c == 0xF0 ? 0x90 : 0x80, hi = c == 0xED ? 0x9F : c == 0xF4 ? 0x8F : 0xBF;
    if (p[1] < lo || p[1] > hi)
        return 0;
    for (int i = 2; i < n; i++)
        if ((p[i] & 0xC0) != 0x80)
            return 0;
    return n;
}

/* A Kelvin source is UTF-8, valid and without a BOM (#295): a BOM, or a
   byte that is no UTF-8, is an error where it stands */
static void check_utf8(const char *file, const char *src) {
    const unsigned char *p = (const unsigned char *)src;
    if (p[0] == 0xEF && p[1] == 0xBB && p[2] == 0xBF)
        error_at((Pos){file, 1, 1}, "a Kelvin source is UTF-8 without a BOM: remove its first three bytes, EF BB BF "
                                    "(#295)");
    Pos pos = {file, 1, 1};
    while (*p) {
        int n = utf8_length(p);
        if (!n)
            error_at(pos, "a Kelvin source is valid UTF-8, and byte 0x%02X here is not (#295)", *p);
        if (*p == '\n') {
            pos.line++;
            pos.col = 1;
        } else {
            pos.col += n;
        }
        p += n;
    }
}

Token *lex(const char *file, const char *src, int *ntoks) {
    check_utf8(file, src);
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
            if ((*lx.p == '"' || *lx.p == '\'') && (!strcmp(t->text, "L") || !strcmp(t->text, "u") ||
                                                    !strcmp(t->text, "U") || !strcmp(t->text, "u8")))
                error_at(pos, "%s%c...%c is C's prefixed literal: a Kelvin source is UTF-8, and a literal's one "
                              "prefix is $, a String's, $\"...\" (#295)",
                         t->text, *lx.p, *lx.p);
            for (int i = 0; keywords[i]; i++)
                if (!strcmp(t->text, keywords[i]))
                    t->kind = TK_KEYWORD;
            /* the full names of the number types (#151): int64 is i64, uint8 u8,
               float32 f32, each the keyword by another name */
            static const struct { const char *full, *name; } full_names[] = {
                {"int8", "i8"},     {"int16", "i16"},   {"int32", "i32"},   {"int64", "i64"},   {"int128", "i128"},
                {"uint8", "u8"},    {"uint16", "u16"},  {"uint32", "u32"},  {"uint64", "u64"},  {"uint128", "u128"},
                {"float32", "f32"}, {"float64", "f64"}};
            for (size_t i = 0; i < sizeof full_names / sizeof full_names[0]; i++)
                if (!strcmp(t->text, full_names[i].full)) {
                    t->text = xstrdup(full_names[i].name);
                    t->kind = TK_KEYWORD;
                }
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
        if (c == '"' && lx.p[1] == '"' && lx.p[2] == '"') {
            lex_triple(&lx);
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
        if (c == '$' && lx.p[1] == '/') {
            lex_regexp(&lx, pos); /* $/pattern/flags (#157) */
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
