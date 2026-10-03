/* parser.c - recursive descent over C's grammar with Kelvin's changes:

   - declarations put the type after the name: `var x: int`, `fn f() -> int`
   - types are postfix: `int^` is a pointer to int
   - dereference is postfix: `p^`, so `p->m` is written `p^.m`
   - XOR is binary `~` (and `~=`); `^` only means "pointer"

   Operator precedence is otherwise exactly C's. */
#include "kelvin.h"

#include <ctype.h>
#include <stdint.h>
#include <string.h>

static Token *toks;
static int cur;
static bool pragma_statement; /* parsing `_Pragma("...");` as a statement */
/* In a ternary's middle operand and a case label, `: name` is the
   separator, not a type annotation `expr:T` with a typedef name. */
static bool ident_annotation_ok = true;
/* parsing the condition of if or while, which a `{` ends: there `(x) {`
   is a parenthesized condition, not a compound literal (#23) */
static bool brace_ends_condition;

static int skip_nested(int i);
static int binary_prec(Token *t);

static bool brace_is_compound(int i);
static bool stmt_is_body; /* the next statement is the body of if/while/for/do or a label */

/* Names declared so far, innermost scope last. kelvinc tracks them only
   to tell `x = 42` (declare x) from an assignment to an existing x. Names
   from C headers are not known. */
static List scope_names;
static List scope_marks;

/* Method names: the prelude's plus every `type.name(...)` defined at the
   top level, collected before parsing so a call may precede the
   definition. `x.name(...)` with any other name is a field call. */
static List method_names;
/* struct, union and enum declarations so far, to resolve method receivers */
static List records;
/* functions and methods declared so far, for the types of their results */
static List functions;

static bool is_method_name(const char *name) {
    for (int i = 0; i < method_names.len; i++)
        if (!strcmp(method_names.data[i], name))
            return true;
    return false;
}

static List scope_types; /* Type * (or NULL) for each name in scope_names */
/* for each name: 0 for a var, else what kind of let (#27) */
enum { LET_NONE, LET_VALUE, LET_PARAM, LET_RANGE };
static List scope_lets;

static void open_scope(void) { list_push(&scope_marks, (void *)(intptr_t)scope_names.len); }

static void close_scope(void) {
    scope_names.len = scope_types.len = scope_lets.len = (int)(intptr_t)scope_marks.data[--scope_marks.len];
}

static void declare_binding(const char *name, Type *type, int let) {
    list_push(&scope_names, (void *)name);
    list_push(&scope_types, type);
    list_push(&scope_lets, (void *)(intptr_t)let);
}

static void declare_typed(const char *name, Type *type) { declare_binding(name, type, LET_NONE); }

/* What kind of let `name` is here (#27), or LET_NONE */
static int let_kind(const char *name) {
    for (int i = scope_names.len - 1; i >= 0; i--)
        if (!strcmp(scope_names.data[i], name))
            return (int)(intptr_t)scope_lets.data[i];
    return LET_NONE;
}

static void declare_name(const char *name) { declare_typed(name, NULL); }

/* the declared type of a name in scope, or NULL if unknown */
static Type *lookup_type(const char *name) {
    for (int i = scope_names.len - 1; i >= 0; i--)
        if (!strcmp(scope_names.data[i], name))
            return scope_types.data[i];
    return NULL;
}

/* the struct, union or enum tag `name` declared so far, if any: its bare
   name is a type, as in C++ (#29) */
static Decl *record_named(const char *name) {
    for (int i = records.len - 1; i >= 0; i--) {
        Decl *r = records.data[i];
        if (r->name && !strcmp(r->name, name))
            return r;
    }
    return NULL;
}

static char *tag_type_name(Decl *r) {
    return strfmt("%s %s", r->kind == D_STRUCT ? "struct" : r->kind == D_UNION ? "union" : "enum", r->name);
}

/* Is `name` declared here as a variable, a parameter or a function? */
static bool in_scope(const char *name) {
    for (int i = scope_names.len - 1; i >= 0; i--)
        if (!strcmp(scope_names.data[i], name))
            return true;
    return false;
}

static Decl *function_named(const char *name);

/* Is the token a tag's bare name (#29) where an expression could stand
   too, as in sizeof(point) or (point^)p? Only for a tag defined in Kelvin:
   C headers often give a C struct's name to a function or variable too
   (stat, timezone), which kelvinc cannot see, so there the C compiler
   decides. A Kelvin variable of that name wins, and so does a Kelvin
   function, except in sizeof, where a function's size is never meant. */
static bool tag_name_ahead(Token *t, bool in_sizeof) {
    Decl *r = t->kind == TK_IDENT ? record_named(t->text) : NULL;
    if (!r || !r->has_body)
        return false;
    if (!in_scope(t->text))
        return true;
    return in_sizeof && function_named(t->text);
}

/* the function `name` names here, unless a local name hides it */
static Decl *function_named(const char *name) {
    int global_end = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
    for (int i = scope_names.len - 1; i >= 0; i--) {
        if (strcmp(scope_names.data[i], name))
            continue;
        if (i >= global_end)
            return NULL;
        for (int j = 0; j < functions.len; j++) {
            Decl *d = functions.data[j];
            if (!d->recv && !strcmp(d->name, name))
                return d;
        }
        return NULL;
    }
    return NULL;
}

static Token *peek(void) { return &toks[cur]; }
static Token *peek_at(int k) {
    int i = cur;
    while (k-- > 0 && toks[i].kind != TK_EOF)
        i++;
    return &toks[i];
}

static Token *peek2(void) { return peek_at(1); }

static Token *advance(void) {
    Token *t = &toks[cur];
    if (t->kind != TK_EOF)
        cur++;
    return t;
}

static bool is_p(Token *t, const char *s) { return t->kind == TK_PUNCT && !strcmp(t->text, s); }
static bool is_kw(Token *t, const char *s) { return t->kind == TK_KEYWORD && !strcmp(t->text, s); }

static bool accept_p(const char *s) {
    if (!is_p(peek(), s))
        return false;
    cur++;
    return true;
}

static bool accept_kw(const char *s) {
    if (!is_kw(peek(), s))
        return false;
    cur++;
    return true;
}

static const char *desc(Token *t) { return t->kind == TK_EOF ? "end of file" : strfmt("'%s'", t->text); }

static Token *expect_p(const char *s) {
    if (!is_p(peek(), s))
        error_at(peek()->pos, "expected '%s', found %s", s, desc(peek()));
    return advance();
}

static char *expect_ident(const char *what) {
    if (peek()->kind != TK_IDENT)
        error_at(peek()->pos, "expected %s, found %s", what, desc(peek()));
    return advance()->text;
}

/* ---------- types ---------- */

/* Kelvin's numeric types always say their size. C's own names for them
   are rejected with a suggestion. */
static const char *base_words[] = {"i8",  "i16",  "i32", "i64",  "i128",     "u8",   "u16",    "u32",
                                   "u64", "u128", "f32", "f64", "bool", "_Complex", "any", "cstr", NULL};

static const struct { const char *c, *kelvin; } dead_words[] = {
    {"char", "u8 (or i8)"},
    {"short", "i16 or u16"},
    {"int", "i32 or u32"},
    {"long", "i64 or u64 (or i128/u128)"},
    {"signed", "i8, i16, i32, i64 or i128"},
    {"unsigned", "u8, u16, u32, u64 or u128"},
    {"float", "f32"},
    {"double", "f64"},
    {"_Bool", "bool"},
    {"void", "any^ for C's void *; a function without a result omits ': type'"},
};

static bool is_base_word(Token *t) {
    for (int i = 0; base_words[i]; i++)
        if (is_kw(t, base_words[i]))
            return true;
    return false;
}

/* built-in types that can be used as converters: i32(x), f64(n), bool(v) */
static bool is_converter(Token *t) {
    return is_base_word(t) && !is_kw(t, "any") && !is_kw(t, "_Complex") && !is_kw(t, "cstr");
}

/* toString(), fmt() and String wait for a true string type (#22) */
#define SHELVED_HINT "is shelved until Kelvin has a true string type; text is cstr (u8^), as in 'x.cstr'"

static bool starts_type(Token *t);

/* Does `(` begin a parenthesized type, as in sizeof(T) or (T){...}?
   `(i32(x) + 1)` does not: a type name directly followed by `(` is a
   converter call. */
static bool is_qualifier(Token *t);

static bool paren_type_ahead(bool in_sizeof) {
    if (!is_p(peek(), "("))
        return false;
    if (tag_name_ahead(peek2(), in_sizeof)) {
        /* sizeof(point), (point^)p: a tag's bare name, then the type's end */
        Token *n = peek_at(2);
        return is_p(n, ")") || is_p(n, "^") || is_p(n, "[") || is_qualifier(n);
    }
    if (!starts_type(peek2()))
        return false;
    return !(is_converter(peek2()) && is_p(peek_at(2), "("));
}

/* the Kelvin replacement for a C type name, or NULL */
static const char *kelvin_for_c_word(Token *t) {
    if (is_kw(t, "long") && t[0].kind != TK_EOF && is_kw(&t[1], "double"))
        return "f64 (long double has no Kelvin type yet)";
    for (size_t i = 0; i < sizeof dead_words / sizeof dead_words[0]; i++)
        if (is_kw(t, dead_words[i].c))
            return dead_words[i].kelvin;
    return NULL;
}

static void reject_c_int_name(Token *t) {
    const char *k = kelvin_for_c_word(t);
    if (k)
        error_at(t->pos, "'%s' is not a Kelvin type; use %s", t->text, k);
}

static bool is_qualifier(Token *t);
static const char *kelvin_for_c_word(Token *t);

/* can this token start an operand (a value or a prefix operator)? */
static bool starts_operand(Token *n) {
    return n->kind == TK_IDENT || n->kind == TK_NUMBER || n->kind == TK_CHAR || n->kind == TK_STRING ||
           is_p(n, "(") || is_p(n, "-") || is_p(n, "+") || is_p(n, "!") || is_p(n, "~") || is_p(n, "&") ||
           is_p(n, "++") || is_p(n, "--") || is_kw(n, "sizeof") || is_kw(n, "true") || is_kw(n, "false") ||
           is_kw(n, "nullptr") || is_converter(n);
}

/* the index just past the balanced (...) or [...] group starting at i */
static int skip_group(int i) {
    int depth = 0;
    for (; toks[i].kind != TK_EOF; i++) {
        if (is_p(&toks[i], "(") || is_p(&toks[i], "["))
            depth++;
        else if ((is_p(&toks[i], ")") || is_p(&toks[i], "]")) && --depth == 0)
            return i + 1;
    }
    return i;
}

/* the index just past the (...), [...] or {...} group that starts at i */
static int skip_nested(int i) {
    int depth = 0;
    for (; toks[i].kind != TK_EOF; i++) {
        if (is_p(&toks[i], "(") || is_p(&toks[i], "[") || is_p(&toks[i], "{"))
            depth++;
        else if ((is_p(&toks[i], ")") || is_p(&toks[i], "]") || is_p(&toks[i], "}")) && --depth == 0)
            return i + 1;
    }
    return i;
}

/* If the tokens from index i spell a type, such as `size_t[2]`,
   `const div_t^` or `struct pt^`, the index just past it; otherwise -1.
   C's own type words are accepted so they reach the "not a Kelvin type"
   hint. */
static int type_shape_end(int i) {
    while (is_qualifier(&toks[i]))
        i++;
    if (is_kw(&toks[i], "struct") || is_kw(&toks[i], "union") || is_kw(&toks[i], "enum")) {
        if (toks[++i].kind != TK_IDENT)
            return -1;
    } else if (toks[i].kind != TK_IDENT && !is_base_word(&toks[i]) && !kelvin_for_c_word(&toks[i]) &&
               !is_kw(&toks[i], "String")) {
        return -1; /* String is shelved (#22), but read as a type to say so */
    }
    for (i++;;) {
        if (kelvin_for_c_word(&toks[i]) || is_qualifier(&toks[i]) || is_p(&toks[i], "^") ||
            is_kw(&toks[i], "_Complex"))
            i++;
        else if (is_p(&toks[i], "["))
            i = skip_group(i);
        else
            return i;
    }
}

/* Do the tokens between the `(` at index i and its `)` spell a type?
   Used to tell (T){...} from a missing `;` before a block. */
static bool paren_holds_type(int i) {
    int end = type_shape_end(i + 1);
    return end >= 0 && is_p(&toks[end], ")");
}

/* the token after the `)` that matches the `(` at token index i, or NULL */
static Token *after_matching_paren(int i) {
    int depth = 0;
    for (; toks[i].kind != TK_EOF; i++) {
        if (is_p(&toks[i], "("))
            depth++;
        else if (is_p(&toks[i], ")") && --depth == 0)
            return &toks[i + 1];
    }
    return NULL;
}

#define CAST_HINT "C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type"

static bool is_qualifier(Token *t) { return is_kw(t, "const") || is_kw(t, "volatile"); }

static bool starts_type(Token *t) {
    reject_c_int_name(t);
    return is_base_word(t) || is_qualifier(t) || is_kw(t, "struct") || is_kw(t, "union") || is_kw(t, "enum");
}

static void parse_qualifiers(Type *t) {
    for (;;) {
        if (accept_kw("const"))
            t->is_const = true;
        else if (accept_kw("volatile"))
            t->is_volatile = true;
        else
            return;
    }
}

static Expr *parse_assign(void);

/* type := qualifiers base qualifiers { '^' qualifiers | '[' size ']'... }

   Suffixes apply left to right: `i32^[4]` is an array of four pointers to
   i32, and `i32[4]^` is a pointer to an array of four i32. Consecutive
   brackets read in C order, so `i32[2][3]` is C's `int32_t[2][3]`. */
typedef enum {
    TYPE_DECL,   /* after `:` or in sizeof(...) */
    TYPE_AS,     /* after `as`: stop at `*`, which is multiplication */
    TYPE_PAREN,  /* inside `(...)` in an expression: a C cast or compound literal */
} TypeContext;

static Type *parse_type_suffixes(Type *t, TypeContext ctx);

static Type *parse_type_in(TypeContext ctx) {
    Type *base = xcalloc(1, sizeof *base);
    base->kind = T_BASE;
    base->pos = peek()->pos;
    parse_qualifiers(base);
    if (is_kw(peek(), "struct") || is_kw(peek(), "union") || is_kw(peek(), "enum")) {
        char *kw = advance()->text;
        base->name = strfmt("%s %s", kw, expect_ident("a tag name"));
    } else {
        /* one built-in type name, or a C typedef name such as FILE or
           size_t from an imported header; f32 and f64 may be _Complex */
        reject_c_int_name(peek());
        Token *name = peek();
        if (is_kw(name, "String"))
            error_at(name->pos, "String " SHELVED_HINT);
        if (name->kind != TK_IDENT && (!is_base_word(name) || is_kw(name, "_Complex")))
            error_at(name->pos, "expected a type, found %s", desc(name));
        advance();
        if (is_kw(name, "cstr")) {
            /* cstr is u8^ (#22); qualifiers apply to the pointer */
            base->name = "u8";
            Type *p = xcalloc(1, sizeof *p);
            p->kind = T_PTR;
            p->pos = name->pos;
            p->elem = base;
            p->is_const = base->is_const;
            p->is_volatile = base->is_volatile;
            base->is_const = base->is_volatile = false;
            parse_qualifiers(p);
            return parse_type_suffixes(p, ctx);
        }
        base->name = name->text;
        Decl *tag = name->kind == TK_IDENT ? record_named(name->text) : NULL;
        if (tag)
            base->name = tag_type_name(tag); /* point is struct point (#29) */
        parse_qualifiers(base);
        if (is_kw(name, "any") && !is_p(peek(), "^"))
            error_at(name->pos, "'any' exists only as 'any^', C's void *");
        if ((is_kw(name, "f32") || is_kw(name, "f64")) && accept_kw("_Complex"))
            base->name = strfmt("%s _Complex", name->text);
    }
    parse_qualifiers(base);
    return parse_type_suffixes(base, ctx);
}

/* the ^, [n] and qualifiers after a base type */
static Type *parse_type_suffixes(Type *t, TypeContext ctx) {
    for (;;) {
        Token *tok = peek();
        if (accept_p("^")) {
            Type *p = xcalloc(1, sizeof *p);
            p->kind = T_PTR;
            p->pos = tok->pos;
            p->elem = t;
            parse_qualifiers(p);
            t = p;
        } else if (is_p(tok, "*")) {
            if (ctx == TYPE_AS) {
                /* `x as T * y` multiplies; `x as T*` followed by nothing
                   is C's pointer habit */
                if (!starts_operand(&tok[1]))
                    error_at(tok->pos, "pointer types are written with a postfix '^', as in 'i32^'");
                return t;
            }
            if (ctx == TYPE_PAREN)
                error_at(tok->pos, CAST_HINT "; pointer types are written with a postfix '^', as in 'i32^'");
            error_at(tok->pos, "pointer types are written with a postfix '^', as in 'i32^'");
        } else if (is_p(tok, "[")) {
            List sizes = {0};
            List positions = {0};
            while (is_p(peek(), "[")) {
                list_push(&positions, &peek()->pos);
                advance();
                list_push(&sizes, is_p(peek(), "]") ? NULL : parse_assign());
                expect_p("]");
            }
            for (int i = sizes.len - 1; i >= 0; i--) {
                Type *a = xcalloc(1, sizeof *a);
                a->kind = T_ARRAY;
                a->pos = *(Pos *)positions.data[i];
                a->elem = t;
                a->size = sizes.data[i];
                t = a;
            }
        } else {
            return t;
        }
    }
}

static Type *parse_type(void) { return parse_type_in(TYPE_DECL); }

/* ---------- expressions ---------- */

static Expr *parse_expr(void);
static Expr *parse_cast(void);
static Expr *parse_initializer(void);
static Type *base_type(const char *name, Pos pos);
static const char *literal_type(Expr *e);
static Type *target_type(Expr *e);
static Expr *property(Expr *e, Token *name, char *member);
static void require_bool(Expr *e);
_Noreturn static void reject_step(Token *t);
static bool binding_ahead(int i);
static bool seen_bool(Expr *e);
static char expr_class(Expr *e, Decl **record);
static bool record_has_field(Decl *r, const char *name);

/* Is the `{` at token i the initializer of a compound literal `(T){...}`
   rather than a body? Always outside a condition. In a condition, only
   when the expression goes on after its `}`, as in
   `if p.x == (struct point){1, 2}.x {`: in `if n == sizeof(i32) {} {`
   the first `{}` is the body */
static bool brace_is_compound(int i) {
    if (!brace_ends_condition)
        return true;
    Token *n = &toks[skip_nested(i)];
    return is_p(n, ".") || is_p(n, "[") || is_p(n, "^") || is_p(n, "?") || is_kw(n, "as") || binary_prec(n) > 0;
}

static Expr *new_expr(ExprKind kind, Pos pos) {
    Expr *e = xcalloc(1, sizeof *e);
    e->kind = kind;
    e->pos = pos;
    return e;
}

static Expr *parse_postfix_ops(Expr *e) {
    for (;;) {
        Token *t = peek();
        if (accept_p("[")) {
            bool saved = ident_annotation_ok;
            bool saved_brace = brace_ends_condition;
            ident_annotation_ok = true;
            brace_ends_condition = false;
            Expr *x = new_expr(E_INDEX, t->pos);
            x->a = e;
            x->b = parse_expr();
            ident_annotation_ok = saved;
            brace_ends_condition = saved_brace;
            expect_p("]");
            e = x;
        } else if (accept_p("(")) {
            bool saved = ident_annotation_ok;
            bool saved_brace = brace_ends_condition;
            ident_annotation_ok = true;
            brace_ends_condition = false;
            Expr *x = new_expr(E_CALL, t->pos);
            x->a = e;
            while (!is_p(peek(), ")")) {
                list_push(&x->items, parse_assign());
                if (!accept_p(","))
                    break;
            }
            ident_annotation_ok = saved;
            brace_ends_condition = saved_brace;
            expect_p(")");
            e = x;
        } else if (accept_p(".")) {
            Token *name = peek();
            /* cstr is a keyword, but also the .cstr property and possibly
               a field of a C struct */
            char *member = is_kw(name, "cstr") ? advance()->text : expect_ident("a member or method name");
            if (is_p(peek(), "(") && (!strcmp(member, "toString") || !strcmp(member, "fmt")) &&
                !is_method_name(member)) {
                /* a field of that name that kelvinc can see, or one of a
                   struct it cannot see, is called as in C */
                Decl *record;
                char c = expr_class(e, &record);
                if (c != 'c' && c != 'u' && !(c == 's' && record_has_field(record, member)))
                    error_at(name->pos, "%s() " SHELVED_HINT, member);
            }
            if (is_p(peek(), "(") && is_method_name(member)) {
                /* v.method(args) */
                advance();
                bool saved = ident_annotation_ok;
                bool saved_brace = brace_ends_condition;
                ident_annotation_ok = true;
                brace_ends_condition = false;
                Expr *x = new_expr(E_METHOD, name->pos);
                x->a = e;
                x->text = member;
                while (!is_p(peek(), ")")) {
                    list_push(&x->items, parse_assign());
                    if (!accept_p(","))
                        break;
                }
                ident_annotation_ok = saved;
                brace_ends_condition = saved_brace;
                expect_p(")");
                e = x;
                continue;
            }
            if (!is_p(peek(), "(")) {
                Expr *x = property(e, name, member);
                if (x) {
                    e = x;
                    continue;
                }
            }
            if (e->kind == E_LITERAL && !e->paren && isdigit((unsigned char)e->text[0]))
                error_at(e->pos, "'%s.%s': literals have no suffixes in Kelvin, and '%s' is not a method", e->text,
                         member, member);
            Expr *x = new_expr(E_FIELD, t->pos);
            x->a = e;
            x->text = member;
            e = x;
        } else if (accept_p("^")) {
            Expr *x = new_expr(E_DEREF, t->pos);
            x->a = e;
            e = x;
        } else if (is_p(t, "++") || is_p(t, "--")) {
            reject_step(t);
        } else if (is_p(t, "->")) {
            error_at(t->pos, "write 'p^.member' instead of 'p->member'");
        } else {
            return e;
        }
    }
}

static Expr *parse_primary(void) {
    Token *t = peek();
    if (t->kind == TK_IDENT && !strcmp(t->text, "_Pragma") && !pragma_statement)
        error_at(t->pos, "_Pragma(\"...\") is only allowed as a statement of its own");
    if (t->kind == TK_IDENT || t->kind == TK_NUMBER || t->kind == TK_CHAR || is_kw(t, "true") ||
        is_kw(t, "false")) {
        advance();
        Expr *e = new_expr(t->kind == TK_IDENT ? E_IDENT : E_LITERAL, t->pos);
        e->text = t->text;
        return e;
    }
    if (t->kind == TK_STRING) {
        Expr *e = new_expr(E_STRING, t->pos);
        while (peek()->kind == TK_STRING)
            list_push(&e->items, advance()->text);
        return e;
    }
    reject_c_int_name(t);
    if (is_converter(t)) {
        /* T(v): a converter for a built-in type. codegen emits ((T)(v)),
           grouping v even when it is a header macro such as 1.5 + 2.5 */
        if (!is_p(peek2(), "(")) {
            if (cur > 0 && is_kw(&toks[cur - 1], "sizeof")) {
                Buf type = {0};
                buf_puts(&type, t->text);
                for (int i = cur + 1;;) {
                    if (is_qualifier(&toks[i]) || is_kw(&toks[i], "_Complex")) {
                        buf_printf(&type, " %s", toks[i++].text);
                    } else if (is_p(&toks[i], "^")) {
                        buf_puts(&type, toks[i++].text);
                    } else if (is_p(&toks[i], "[")) {
                        for (int end = skip_group(i); i < end; i++)
                            buf_puts(&type, toks[i].text);
                    } else {
                        break;
                    }
                }
                error_at(t->pos, "sizeof a type needs parentheses: sizeof(%s)", type.buf);
            }
            if (is_p(peek2(), "^") || is_p(peek2(), "["))
                error_at(t->pos, "converters are only for built-in types like %s(v); for other types write 'v as T'",
                         t->text);
            error_at(t->pos, "'%s' is a type; convert a value with %s(v) or v as %s", t->text, t->text, t->text);
        }
        advance();
        Expr *e = new_expr(E_CAST, t->pos);
        e->op = "converter";
        e->type = base_type(t->text, t->pos);
        e->paren = true;
        advance();
        e->a = parse_assign();
        if (is_p(peek(), ","))
            error_at(peek()->pos, "a converter takes exactly one value: %s(v)", t->text);
        expect_p(")");
        return e;
    }
    if (accept_kw("nullptr")) {
        /* C's (void *)0, typed any^ */
        Expr *e = new_expr(E_LITERAL, t->pos);
        e->text = "nullptr";
        return e;
    }
    if (is_p(t, "(")) {
        /* `(...)` followed by `{` is a compound literal; its type may be a C
           typedef with suffixes, e.g. (size_t[2]){1, 2}, because an
           expression is never followed by `{` */
        Token *after = after_matching_paren(cur);
        bool compound = after && is_p(after, "{") && paren_holds_type(cur) && brace_is_compound((int)(after - toks));
        Token *inner = peek2();
        bool converter_call = is_converter(inner) && is_p(peek_at(2), "(");
        if (!compound && is_kw(inner, "void") && is_p(peek_at(2), ")"))
            error_at(t->pos, "C casts are not Kelvin: to discard a value, write it as a statement of its own");
        if (kelvin_for_c_word(inner)) {
            if (compound)
                reject_c_int_name(inner);
            error_at(t->pos, CAST_HINT "; '%s' is not a Kelvin type, use %s", inner->text, kelvin_for_c_word(inner));
        }
        if (compound && !converter_call && (starts_type(inner) || inner->kind == TK_IDENT)) {
            advance();
            Type *type = parse_type_in(TYPE_DECL);
            expect_p(")");
            Expr *e = new_expr(E_COMPOUND, t->pos);
            e->type = type;
            e->a = parse_initializer();
            return e;
        }
        {
            /* (T *)p, (FILE **)p, (T const *)p, (T * const)p, (T *){...} */
            int i = 1;
            while (is_qualifier(peek_at(i)))
                i++;
            if (peek_at(i)->kind == TK_IDENT || is_base_word(peek_at(i))) {
                i++;
                while (is_qualifier(peek_at(i)))
                    i++;
                bool star = false;
                while (is_p(peek_at(i), "*") || (star && is_qualifier(peek_at(i)))) {
                    star = true;
                    i++;
                }
                if (star && is_p(peek_at(i), ")")) {
                    if (is_p(peek_at(i + 1), "{"))
                        error_at(t->pos, "pointer types are written with a postfix '^', as in '(i32^){0}'");
                    error_at(t->pos, CAST_HINT "; pointer types are written with a postfix '^', as in 'i32^'");
                }
            }
        }
        if (paren_type_ahead(false)) {
            /* (T)v is C's cast, not Kelvin's */
            advance();
            parse_type_in(TYPE_PAREN);
            error_at(t->pos, CAST_HINT);
        }
    }
    if (accept_p("(")) {
        bool saved = ident_annotation_ok;
        bool saved_brace = brace_ends_condition;
        ident_annotation_ok = true;
        brace_ends_condition = false;
        Expr *e = parse_expr();
        ident_annotation_ok = saved;
        brace_ends_condition = saved_brace;
        expect_p(")");
        e->paren = true;
        /* `(x) y` is never Kelvin; it is a C cast to a typedef, e.g. (size_t)n */
        Token *n = peek();
        if (n->kind == TK_IDENT || n->kind == TK_NUMBER || n->kind == TK_CHAR || n->kind == TK_STRING ||
            is_p(n, "!") || is_kw(n, "sizeof") || is_kw(n, "true") || is_kw(n, "false") || is_kw(n, "nullptr") ||
            is_converter(n) ||
            ((is_p(n, "++") || is_p(n, "--")) &&
             (peek2()->kind == TK_IDENT || peek2()->kind == TK_NUMBER || peek2()->kind == TK_CHAR)))
            error_at(t->pos, CAST_HINT);
        return e;
    }
    if (is_kw(t, "String"))
        error_at(t->pos, "String " SHELVED_HINT);
    if (is_kw(t, "cstr") && is_p(peek2(), "("))
        error_at(t->pos, "cstr is u8^: convert with 'v as cstr'");
    error_at(t->pos, "expected an expression, found %s", desc(t));
}

/* Kelvin has no ++ and -- (#26) */
_Noreturn static void reject_step(Token *t) {
    error_at(t->pos, "Kelvin has no '%s': write 'x %s= 1' as a statement, or 'p := p.%s' for a pointer", t->text,
             t->text[0] == '+' ? "+" : "-", t->text[0] == '+' ? "next" : "prev");
}

static Expr *parse_unary(void) {
    Token *t = peek();
    if (is_p(t, "++") || is_p(t, "--"))
        reject_step(t);
    if (is_p(t, "&") || is_p(t, "-") || is_p(t, "+") || is_p(t, "!") || is_p(t, "~")) {
        advance();
        Expr *e = new_expr(E_PREFIX, t->pos);
        e->op = t->text;
        e->a = parse_unary();
        if (!strcmp(e->op, "!"))
            require_bool(e->a);
        return e;
    }
    if (is_p(t, "*"))
        error_at(t->pos, "dereference is a postfix '^' in Kelvin: write 'p^' instead of '*p'");
    if (accept_kw("sizeof")) {
        if (tag_name_ahead(peek(), true))
            error_at(peek()->pos, "sizeof a type needs parentheses: sizeof(%s)", peek()->text);
        if (paren_type_ahead(true)) {
            Token *open = advance();
            Type *type = parse_type();
            expect_p(")");
            if (is_p(peek(), "{") && brace_is_compound(cur)) {
                /* sizeof (T){...} is the size of a compound literal */
                Expr *c = new_expr(E_COMPOUND, open->pos);
                c->type = type;
                c->a = parse_initializer();
                Expr *e = new_expr(E_SIZEOF_EXPR, t->pos);
                e->a = parse_postfix_ops(c);
                return e;
            }
            Expr *e = new_expr(E_SIZEOF_TYPE, t->pos);
            e->type = type;
            return e;
        }
        Expr *e = new_expr(E_SIZEOF_EXPR, t->pos);
        e->a = parse_unary();
        return e;
    }
    return parse_postfix_ops(parse_primary());
}

/* cast := unary { ('as' | ':') type }

   `as` binds tighter than every binary operator and looser than the
   prefix ones, which is where C's cast sits: `-x as u8` is `(-x) as u8`,
   and `a * b as i64` is `a * (b as i64)`. Any identifier after `as` is a
   type name, so C typedefs work: `n as size_t`, `p as FILE^`. */
/* Is the `:` at the cursor a type annotation, as in `0xdead:u16`? */
static bool annotation_ahead(void) {
    Token *n = peek2();
    if (is_converter(n) && is_p(peek_at(2), "("))
        return false; /* c ? x : u8(y) */
    if (is_base_word(n) || is_qualifier(n) || kelvin_for_c_word(n) || is_kw(n, "struct") || is_kw(n, "union") ||
        is_kw(n, "enum") || is_kw(n, "String"))
        return true;
    return n->kind == TK_IDENT && ident_annotation_ok;
}

static Expr *parse_cast(void) {
    Expr *e = parse_unary();
    while (is_kw(peek(), "as") || (is_p(peek(), ":") && annotation_ahead())) {
        Token *t = advance();
        Expr *c = new_expr(E_CAST, t->pos);
        c->a = e;
        c->type = parse_type_in(TYPE_AS);
        e = c;
    }
    return e;
}

/* C's binary precedence levels; `~` takes XOR's place. */
static int binary_prec(Token *t) {
    if (t->kind != TK_PUNCT)
        return -1;
    static const struct { const char *op; int prec; } table[] = {
        {"||", 1}, {"&&", 2}, {"|", 3}, {"~", 4}, {"&", 5},
        {"==", 6}, {"!=", 6}, {"<", 7}, {">", 7}, {"<=", 7}, {">=", 7},
        {"<<", 8}, {">>", 8}, {"+", 9}, {"-", 9}, {"*", 10}, {"/", 10}, {"%", 10},
    };
    for (size_t i = 0; i < sizeof table / sizeof table[0]; i++)
        if (!strcmp(t->text, table[i].op))
            return table[i].prec;
    return -1;
}

static Expr *parse_binary(int min_prec) {
    Expr *lhs = parse_cast();
    for (;;) {
        Token *t = peek();
        int prec = binary_prec(t);
        if (prec < min_prec)
            return lhs;
        advance();
        Expr *e = new_expr(E_BINARY, t->pos);
        e->op = t->text;
        e->a = lhs;
        e->b = parse_binary(prec + 1);
        if (!strcmp(e->op, "&&") || !strcmp(e->op, "||")) {
            require_bool(e->a);
            require_bool(e->b);
        }
        lhs = e;
    }
}

static Expr *parse_conditional(void) {
    Expr *c = parse_binary(1);
    Token *t = peek();
    if (!accept_p("?"))
        return c;
    Expr *e = new_expr(E_TERNARY, t->pos);
    require_bool(c);
    e->a = c;
    bool saved = ident_annotation_ok;
    ident_annotation_ok = false;
    e->b = parse_expr();
    ident_annotation_ok = saved;
    expect_p(":");
    e->c = parse_conditional();
    e->is_bool = seen_bool(e); /* C would promote two bools to int */
    return e;
}

/* ---------- references (`:=`) and values (`=`) ---------- */

/* A parameter declared as an array is a pointer to its element, as C
   adjusts it, so reassigning it is a reference assignment. */
static Type *param_type(Type *t) {
    if (t->kind != T_ARRAY)
        return t;
    Type *p = xcalloc(1, sizeof *p);
    p->kind = T_PTR;
    p->pos = t->pos;
    p->elem = t->elem;
    return p;
}

/* the Kelvin spelling of a type, for messages */
static char *kelvin_type(Type *t) {
    const char *q = t->is_const && t->is_volatile ? "const volatile" : t->is_const ? "const" : t->is_volatile ? "volatile" : "";
    switch (t->kind) {
    case T_BASE: return strfmt("%s%s%s", q, *q ? " " : "", t->name);
    case T_PTR: return strfmt("%s^%s%s", kelvin_type(t->elem), *q ? " " : "", q);
    case T_ARRAY:
        return strfmt("%s[%s]", kelvin_type(t->elem),
                      !t->size ? "" : t->size->kind == E_LITERAL ? t->size->text : "...");
    }
    return "?";
}

/* 1 for a reference (a pointer), 0 for a value, -1 when kelvinc cannot
   tell (a C typedef name, or an unknown type) */
static int ref_kind(Type *t) {
    if (!t)
        return -1;
    if (t->kind == T_PTR)
        return 1;
    if (t->kind == T_ARRAY)
        return 0;
    const char *n = t->name;
    if (!strncmp(n, "struct ", 7) || !strncmp(n, "union ", 6) || !strncmp(n, "enum ", 5))
        return 0;
    for (int i = 0; base_words[i]; i++)
        if (!strcmp(n, base_words[i]) || (!strncmp(n, base_words[i], strlen(base_words[i])) &&
                                           !strcmp(n + strlen(base_words[i]), " _Complex")))
            return 0;
    return -1;
}

/* The type of names, p^, a[i] and fields of Kelvin structs, as far as
   kelvinc can see it, where `base` gives the type of the operand of ^, []
   and `.`. NULL otherwise. */
static Type *type_through(Expr *e, Type *(*base)(Expr *)) {
    switch (e->kind) {
    case E_IDENT:
        return lookup_type(e->text);
    case E_DEREF: {
        Type *t = base(e->a);
        return t && (t->kind == T_PTR || t->kind == T_ARRAY) ? t->elem : NULL;
    }
    case E_INDEX: {
        Type *t = base(e->a);
        return t && (t->kind == T_PTR || t->kind == T_ARRAY) ? t->elem : NULL;
    }
    case E_FIELD: {
        Type *t = e->a ? base(e->a) : NULL;
        if (!t || t->kind != T_BASE)
            return NULL;
        for (int i = records.len - 1; i >= 0; i--) {
            Decl *r = records.data[i];
            const char *kw = r->kind == D_STRUCT ? "struct" : r->kind == D_UNION ? "union" : "enum";
            if (!r->name || !r->has_body || strcmp(t->name, strfmt("%s %s", kw, r->name)))
                continue; /* `struct T;` declares no fields */
            for (int j = 0; j < r->members.len; j++) {
                Var *m = r->members.data[j];
                if (!strcmp(m->name, e->text))
                    return m->type;
            }
            return NULL;
        }
        return NULL;
    }
    default:
        return NULL;
    }
}

/* The type of an assignment target: names, p^, a[i] and fields, down to
   a name (#19 checks `=` and `:=` only there) */
static Type *target_type(Expr *e) { return type_through(e, target_type); }

/* ---------- properties: .size, .dec, .hex, .oct, .bin (#21) ---------- */

/* What kelvinc can see of an expression's type, for properties:
   'i' integer, 'f' f32/f64, 's' Kelvin struct or union, 'c' C struct or
   union, 'n' something else it knows (pointer, array, bool, complex),
   'u' unknown (a C typedef, a call result, an expression). */
static char type_class(Type *t, Decl **record) {
    *record = NULL;
    if (!t)
        return 'u';
    if (t->kind != T_BASE)
        return 'n';
    const char *n = t->name;
    static const char *ints[] = {"i8", "i16", "i32", "i64", "i128", "u8", "u16", "u32", "u64", "u128", NULL};
    for (int i = 0; ints[i]; i++)
        if (!strcmp(n, ints[i]))
            return 'i';
    if (!strcmp(n, "f32") || !strcmp(n, "f64"))
        return 'f';
    if (!strncmp(n, "enum ", 5))
        return 'i';
    if (!strncmp(n, "struct ", 7) || !strncmp(n, "union ", 6)) {
        for (int i = records.len - 1; i >= 0; i--) {
            Decl *r = records.data[i];
            const char *kw = r->kind == D_STRUCT ? "struct" : "union";
            if (r->kind != D_ENUM && r->name && r->has_body && !strcmp(n, strfmt("%s %s", kw, r->name))) {
                *record = r;
                return 's';
            }
        }
        return 'c';
    }
    if (is_base_word(&(Token){.kind = TK_KEYWORD, .text = (char *)n}) || !strcmp(n, "f32 _Complex") ||
        !strcmp(n, "f64 _Complex"))
        return 'n'; /* bool, complex */
    return 'u';     /* a C typedef name */
}

/* The type of an expression's value, as far as kelvinc can see it: names,
   `v as T`, compound literals and the results of Kelvin functions and
   methods (a method only when every method of that name returns the same
   type), and p^, a[i] and fields of all these. NULL otherwise. */
static Type *value_type(Expr *e) {
    switch (e->kind) {
    case E_CAST:
    case E_COMPOUND:
        return e->type;
    case E_CALL: {
        Decl *f = e->a->kind == E_IDENT ? function_named(e->a->text) : NULL;
        return f ? f->ret : NULL;
    }
    case E_METHOD: {
        Type *ret = NULL;
        for (int i = 0; i < functions.len; i++) {
            Decl *d = functions.data[i];
            if (!d->recv || strcmp(d->name, e->text))
                continue;
            if (!d->ret || (ret && strcmp(kelvin_type(ret), kelvin_type(d->ret))))
                return NULL;
            ret = d->ret;
        }
        return ret;
    }
    case E_PROPERTY: /* p.next and p.prev have p's type */
        return !strcmp(e->text, "next") || !strcmp(e->text, "prev") ? value_type(e->a) : NULL;
    default:
        return type_through(e, value_type);
    }
}

/* ---------- conditions are bool (#23) ---------- */

static bool is_comparison(const char *op) {
    return !strcmp(op, "==") || !strcmp(op, "!=") || !strcmp(op, "<") || !strcmp(op, ">") || !strcmp(op, "<=") ||
           !strcmp(op, ">=");
}

/* Does e have type bool by its shape: a comparison, &&, ||, !, true,
   false, bool(x), x as bool, or ?: between two bools? */
static bool bool_shape(Expr *e) {
    switch (e->kind) {
    case E_BINARY:
        return is_comparison(e->op) || !strcmp(e->op, "&&") || !strcmp(e->op, "||");
    case E_PREFIX:
        return !strcmp(e->op, "!");
    case E_LITERAL:
        return !strcmp(e->text, "true") || !strcmp(e->text, "false");
    case E_CAST:
        return e->type->kind == T_BASE && !strcmp(e->type->name, "bool");
    case E_TERNARY:
        return seen_bool(e->b) && seen_bool(e->c);
    default:
        return false;
    }
}

/* Is e a bool by its shape, or a bool value kelvinc sees (a variable, a
   field, a Kelvin function's result)? */
static bool seen_bool(Expr *e) {
    if (e->is_bool || bool_shape(e))
        return true;
    Type *t = value_type(e);
    return t && t->kind == T_BASE && !strcmp(t->name, "bool");
}

/* A condition, and an operand of &&, || or !, is a bool. Where kelvinc
   sees the type it checks it here; elsewhere (a C function, a macro)
   codegen has the C compiler check it. */
static void require_bool(Expr *e) {
    if (e->is_bool || bool_shape(e)) {
        e->is_bool = true;
        return;
    }
    const char *hint = NULL, *what = NULL;
    if (e->kind == E_LITERAL && !strcmp(e->text, "nullptr")) {
        what = "any^", hint = "p != nullptr";
    } else if (e->kind == E_LITERAL) {
        if (e->text[0] != '\'' && !strcmp(literal_type(e), "i64"))
            error_at(e->pos, "a condition must be a bool, not a number: write 'true' or 'false'");
        what = "a number", hint = e->text[0] == '\'' ? "c != 0" : "x != 0.0";
    } else if (e->kind == E_STRING) {
        what = "a string", hint = "s != nullptr";
    } else if (e->kind == E_PROPERTY) {
        what = !strcmp(e->text, "size") ? "size_t" : "u8^";
        hint = !strcmp(e->text, "size") ? "x.size != 0" : "x != nullptr";
    } else {
        Type *t = value_type(e);
        if (!t)
            return; /* the C compiler checks it */
        what = kelvin_type(t);
        Decl *record;
        char c = type_class(t, &record);
        if (t->kind == T_BASE && !strcmp(t->name, "bool")) {
            e->is_bool = true;
            return;
        }
        if (t->kind == T_PTR || t->kind == T_ARRAY)
            hint = "p != nullptr";
        else if (c == 'i')
            hint = "x != 0";
        else if (c == 'f')
            hint = "x != 0.0";
        else if (c == 'u' || c == 'c')
            return; /* a C typedef or C struct: the C compiler checks it */
    }
    if (hint)
        error_at(e->pos, "a condition must be a bool, not %s: compare it, as in '%s'", what, hint);
    error_at(e->pos, "a condition must be a bool, not %s", what);
}

static char expr_class(Expr *e, Decl **record) {
    *record = NULL;
    switch (e->kind) {
    case E_LITERAL:
        if (!strcmp(e->text, "true") || !strcmp(e->text, "false") || !strcmp(e->text, "nullptr"))
            return 'n';
        if (e->text[0] == '\'')
            return 'i';
        return !strcmp(literal_type(e), "f64") ? 'f' : 'i';
    case E_STRING:
        return 'n';
    case E_PROPERTY:
        return !strcmp(e->text, "size") ? 'i' : 'n';
    default:
        return type_class(value_type(e), record);
    }
}

static bool record_has_field(Decl *r, const char *name) {
    for (int i = 0; r && i < r->members.len; i++)
        if (!strcmp(((Var *)r->members.data[i])->name, name))
            return true;
    return false;
}

/* `x.size` is sizeof(x); `x.cstr` is its text (#22), and `x.dec`, `.hex`,
   `.oct`, `.bin` the text of a number. Returns NULL when `.name` is a
   field access instead: always when a Kelvin struct has that field, and
   for `.size` whenever kelvinc cannot see that the receiver is not a C
   struct (the field wins when unsure). */
static Expr *property(Expr *e, Token *name, char *member) {
    if (!strcmp(member, "next") || !strcmp(member, "prev")) {
        /* p.next is p + 1 and p.prev is p - 1, on a pointer kelvinc can
           see (#26); on anything else `.next` is a field, as in n^.next */
        Type *t = value_type(e);
        if (t && t->kind == T_ARRAY)
            error_at(name->pos, "'.%s' is a property of pointers: for an array, write '&a[%s]'", member,
                     member[0] == 'n' ? "1" : "-1");
        if (!t || t->kind != T_PTR)
            return NULL;
        if (t->elem->kind == T_BASE && !strcmp(t->elem->name, "any"))
            error_at(name->pos, "an any^ has no '.%s': its element has no size", member);
        Expr *x = new_expr(E_PROPERTY, name->pos);
        x->a = e;
        x->text = member;
        return x;
    }
    bool is_size = !strcmp(member, "size");
    bool is_cstr = !strcmp(member, "cstr");
    bool is_text = !strcmp(member, "dec") || !strcmp(member, "hex") || !strcmp(member, "oct") || !strcmp(member, "bin");
    if (!is_size && !is_text && !is_cstr)
        return NULL;
    Decl *record;
    char c = expr_class(e, &record);
    if (c == 's' && record_has_field(record, member))
        return NULL;
    if (c == 'c')
        return NULL;
    if (is_size && c == 'u')
        return NULL;
    if (is_cstr) {
        /* the receiver's type, when kelvinc can see it, sizes the buffer */
        Type *t = value_type(e);
        if (t && t->kind == T_ARRAY)
            error_at(name->pos, "'.cstr' of an array: C arrays are not values; index it, or put it in a struct");
        Expr *x = new_expr(E_PROPERTY, name->pos);
        x->a = e;
        x->text = member;
        x->type = c == 's' ? t : NULL;
        x->op = c == 'u' ? "unknown" : NULL;
        return x;
    }
    if (is_text && (c == 'n' || c == 's'))
        error_at(name->pos, "'.%s' is a property of integers%s", member,
                 !strcmp(member, "dec") || !strcmp(member, "hex") ? " and of f32/f64" : "");
    if (is_text && c == 'f' && (!strcmp(member, "oct") || !strcmp(member, "bin")))
        error_at(name->pos, "'.%s' is a property of integers; f32 and f64 have .dec and .hex", member);
    Expr *x = new_expr(E_PROPERTY, name->pos);
    x->a = e;
    x->text = member;
    return x;
}

/* `=` assigns values and `:=` references (best effort: only where the
   target's type is known) */
static void check_assign_op(const char *op, Type *t, const char *what, Pos pos, Expr *init) {
    int k = ref_kind(t);
    if (!strcmp(op, "=") && k == 1)
        error_at(pos, "%s is a reference (%s): assign it with ':=', not '='", what, kelvin_type(t));
    if (!strcmp(op, ":=") && k == 0) {
        /* `buffer := malloc(n):i64` most likely meant :i64^ */
        if (init && init->kind == E_CAST && !init->op)
            error_at(pos, "%s would be a value (%s): use '=' for a value, or annotate a reference such as '%s^'",
                     what, kelvin_type(t), kelvin_type(t));
        error_at(pos, "%s is a value (%s): assign it with '=', not ':='", what, kelvin_type(t));
    }
}

static const char *assign_ops[] = {"=", ":=", "+=", "-=", "*=", "/=", "%=", "<<=", ">>=", "&=", "~=", "|=", NULL};

/* The let that assigning to e would change (#27): a let name, its fields,
   and the elements of a let array. Assigning through a pointer, p^ or
   p[i], changes what p points to, which a let pointer does not fix. */
static const char *let_target(Expr *e) {
    switch (e->kind) {
    case E_IDENT:
        return let_kind(e->text) ? e->text : NULL;
    case E_FIELD:
        return e->a ? let_target(e->a) : NULL;
    case E_INDEX: {
        Type *t = value_type(e->a);
        return t && t->kind == T_ARRAY ? let_target(e->a) : NULL;
    }
    default:
        return NULL;
    }
}

/* Assignment is a statement (#26): `=`, `:=` and `+=` and friends appear
   only at the top of an expression statement or of a for clause, where a
   comma list such as `i += 1, j -= 1` runs left to right. Anywhere else,
   as in `a = b = c` or `if (x = f()) != nullptr`, it is an error. */
static bool assign_ok;

static Expr *parse_assign(void) {
    bool ok = assign_ok;
    assign_ok = false; /* nothing inside may assign */
    Expr *lhs = parse_conditional();
    Token *t = peek();
    for (int i = 0; assign_ops[i]; i++)
        if (is_p(t, assign_ops[i])) {
            if (!ok)
                error_at(t->pos, "assignment is a statement in Kelvin, not a value: assign on a line of its own");
            advance();
            const char *let = let_target(lhs);
            if (let && let_kind(let) == LET_RANGE)
                error_at(t->pos, "'%s' counts the range and cannot change; copy it under another name, as in "
                                 "'var k:%s = %s;'", let, kelvin_type(lookup_type(let)), let);
            if (let && let_kind(let) == LET_PARAM)
                error_at(t->pos, "'%s' is a let parameter and cannot change; write 'var %s' in the parameter list",
                         let, let);
            if (let)
                error_at(t->pos, "'%s' is a let and cannot change; declare it with var", let);
            if (!strcmp(t->text, "=") || !strcmp(t->text, ":="))
                check_assign_op(t->text, target_type(lhs),
                                lhs->kind == E_IDENT ? strfmt("'%s'", lhs->text) : "this target", t->pos, NULL);
            Expr *e = new_expr(E_BINARY, t->pos);
            e->op = t->text;
            e->a = lhs;
            e->b = parse_assign();
            assign_ok = ok;
            return e;
        }
    assign_ok = ok;
    return lhs;
}

/* an expression statement or a for clause, which may assign */
static Expr *parse_assignments(void) {
    assign_ok = true;
    Expr *e = parse_expr();
    assign_ok = false;
    return e;
}

static Expr *parse_expr(void) {
    Expr *e = parse_assign();
    while (is_p(peek(), ",")) {
        Token *t = advance();
        Expr *c = new_expr(E_BINARY, t->pos);
        c->op = ",";
        c->a = e;
        c->b = parse_assign();
        e = c;
    }
    return e;
}

/* initializer := assign | '{' [designator '='] initializer, ... '}'
   A designator is stored as a member/index chain with a NULL root. */
static Expr *parse_initializer(void) {
    Token *t = peek();
    if (!accept_p("{"))
        return parse_assign();
    Expr *e = new_expr(E_INIT, t->pos);
    while (!is_p(peek(), "}")) {
        Expr *d = NULL;
        while (is_p(peek(), ".") || is_p(peek(), "[")) {
            Token *dt = advance();
            Expr *x = new_expr(is_p(dt, ".") ? E_FIELD : E_INDEX, dt->pos);
            x->a = d;
            if (x->kind == E_FIELD) {
                /* cstr is a keyword, but may be a C struct's field */
                x->text = is_kw(peek(), "cstr") ? advance()->text : expect_ident("a member name");
            } else {
                x->b = parse_conditional();
                expect_p("]");
            }
            d = x;
        }
        if (d)
            expect_p("=");
        list_push(&e->designators, d);
        list_push(&e->items, parse_initializer());
        if (!accept_p(","))
            break;
    }
    expect_p("}");
    return e;
}

/* ---------- declarations shared by statements and top level ---------- */

/* The Kelvin type of a number literal: an integer literal is i64 and a
   floating literal is f64 (optionally negated). NULL otherwise. */
static const char *literal_type(Expr *e) {
    if (e->kind == E_PREFIX && (!strcmp(e->op, "-") || !strcmp(e->op, "+")))
        return literal_type(e->a);
    if (e->kind != E_LITERAL || e->text[0] == '\'' || !strcmp(e->text, "true") || !strcmp(e->text, "false"))
        return NULL;
    const char *t = e->text;
    bool hex = t[0] == '0' && (t[1] == 'x' || t[1] == 'X');
    bool floating = hex ? strpbrk(t, "pP") != NULL : strpbrk(t, ".eE") != NULL;
    return floating ? "f64" : "i64";
}

static Type *base_type(const char *name, Pos pos) {
    Type *t = xcalloc(1, sizeof *t);
    t->kind = T_BASE;
    t->pos = pos;
    t->name = (char *)name;
    return t;
}

/* The type of an initializer when none is written: an integer literal is
   an i64, a floating literal an f64, nullptr is an any^, and `v:T`,
   `v as T` or `T(v)` is a T. A bool is a bool (#24, #25): `true`, a
   comparison, &&, || and !, and any value kelvinc sees is a bool, such as
   a bool variable or a Kelvin function's bool result. NULL otherwise. */
static Type *inferred_type(Expr *e, Pos pos) {
    if (e->kind == E_CAST)
        return e->type;
    if (seen_bool(e))
        return base_type("bool", pos);
    if (e->kind == E_LITERAL && !strcmp(e->text, "nullptr")) {
        Type *t = xcalloc(1, sizeof *t);
        t->kind = T_PTR;
        t->pos = pos;
        t->elem = base_type("any", pos);
        return t;
    }
    const char *lit = literal_type(e);
    return lit ? base_type(lit, pos) : NULL;
}

/* name: type [= init], or (for variables) name = init with the type
   inferred from init */
static Var *parse_var(bool with_init, int let) {
    Var *v = xcalloc(1, sizeof *v);
    v->pos = peek()->pos;
    v->name = expect_ident("a name");
    char *what = strfmt("'%s'", v->name);
    if (with_init && (is_p(peek(), "=") || is_p(peek(), ":="))) {
        Token *op = advance();
        /* in scope from here, as in C, so the initializer sees it, as in
           `let point: i16 = sizeof(point)`; its type is filled in below */
        declare_binding(v->name, NULL, let);
        v->init = parse_initializer();
        v->type = inferred_type(v->init, v->pos);
        scope_types.data[scope_types.len - 1] = v->type;
        if (!v->type)
            error_at(v->pos,
                     "'%s' needs a type: write '%s:T = ...' (or '%s:T := ...' for a reference); only literals, "
                     "bools and values written 'v:T', 'v as T' or 'T(v)' have a type Kelvin can infer",
                     v->name, v->name, v->name);
        check_assign_op(op->text, v->type, what, op->pos, v->init);
        return v;
    }
    expect_p(":");
    v->type = parse_type();
    if (with_init) /* a declaration: in scope before its initializer */
        declare_binding(v->name, v->type, let);
    if (with_init && (is_p(peek(), "=") || is_p(peek(), ":="))) {
        Token *op = advance();
        check_assign_op(op->text, v->type, what, op->pos, NULL);
        v->init = parse_initializer();
    }
    return v;
}

/* let|var name[: type] [= or := init] {, ...} (#27): each name is in
   scope after its declarator. A let is C's const, so it needs a value,
   except in an extern declaration. */
static void parse_var_list(List *out, bool is_let, const char *storage) {
    do {
        Var *v = parse_var(true, is_let ? LET_VALUE : LET_NONE); /* declares it */
        v->is_let = is_let;
        if (is_let && !v->init && !(storage && !strcmp(storage, "extern")))
            error_at(v->pos, "a let needs a value: write 'let %s = ...', or 'var %s' if it changes later", v->name,
                     v->name);
        list_push(out, v);
    } while (accept_p(","));
}

static const char *parse_storage(void) {
    if (accept_kw("static"))
        return "static";
    if (accept_kw("extern"))
        return "extern";
    return NULL;
}

/* ---------- statements ---------- */

static Stmt *parse_stmt(void);

/* Report C-style declarations at the start of a statement or a `for`
   initializer, with their Kelvin spelling:

     i32 * r = &x;    struct pt *p;    size_t n = 0;    const u8 *s;
     size_t a[3];     static size_t m;  size_t f(void);  FILE **pp;

   As Kelvin these would be discarded multiplications or juxtaposed names,
   but C reads the ones that start with a typedef name as declarations.
   `T ~ b = 0` is caught too: Kelvin's `~` prints as `^`, which Apple's
   clang reads as a block-pointer declarator. Only shapes that end the
   statement (`;`, `,` or `=` after the declarator) are reported, so
   `n * f(x) == 4 || g();` is still an expression. */
static void reject_c_declaration(void) {
    int i = cur;
    Pos pos = toks[i].pos;
    const char *storage = NULL;
    if (is_kw(&toks[i], "static") || is_kw(&toks[i], "extern") || is_kw(&toks[i], "register") ||
        is_kw(&toks[i], "auto"))
        storage = toks[i++].text;
    bool base_const = false, base_volatile = false;
    for (; is_qualifier(&toks[i]); i++)
        *(is_kw(&toks[i], "const") ? &base_const : &base_volatile) = true;
    char *type;
    if (is_kw(&toks[i], "struct") || is_kw(&toks[i], "union") || is_kw(&toks[i], "enum")) {
        if (toks[i + 1].kind != TK_IDENT)
            return;
        type = strfmt("%s %s", toks[i].text, toks[i + 1].text);
        i += 2;
    } else if (toks[i].kind == TK_IDENT || (is_base_word(&toks[i]) && !is_kw(&toks[i], "_Complex"))) {
        static const char *statement_words[] = {"__asm__", "__asm", "asm", "__attribute__", "_Pragma", NULL};
        for (int k = 0; statement_words[k]; k++)
            if (!strcmp(toks[i].text, statement_words[k]))
                return;
        if (is_converter(&toks[i]) && is_p(&toks[i + 1], "("))
            return;
        type = toks[i].text;
        i++;
        if (is_kw(&toks[i], "_Complex")) {
            type = strfmt("%s _Complex", type);
            i++;
        }
    } else {
        return;
    }
    for (; is_qualifier(&toks[i]); i++)
        *(is_kw(&toks[i], "const") ? &base_const : &base_volatile) = true;
    Buf suffix = {0};
    buf_puts(&suffix, "");
    bool block = false;
    while (is_p(&toks[i], "*")) {
        buf_puts(&suffix, "^");
        for (i++; is_qualifier(&toks[i]); i++)
            buf_printf(&suffix, " %s", toks[i].text);
    }
    if (!suffix.len && is_p(&toks[i], "~")) {
        block = true;
        i++;
    }
    /* the declarator: a name, possibly parenthesized, then (...), [...]
       or ^ suffixes */
    int name_at = i;
    if (is_p(&toks[i], "(") && (suffix.len || block)) {
        /* `T * (p) = ...`; without a `*`, `name(x)` is a call (or the
           documented typedef ambiguity) and is left alone */
        int end = skip_group(i);
        for (name_at = i; name_at < end && toks[name_at].kind != TK_IDENT; name_at++)
            ;
        if (name_at == end)
            return;
        i = end;
    } else if (toks[i].kind == TK_IDENT) {
        i++;
    } else {
        return;
    }
    bool function = false, function_pointer = false;
    Buf dims = {0};
    buf_puts(&dims, "");
    while (is_p(&toks[i], "(") || is_p(&toks[i], "[") || is_p(&toks[i], "^")) {
        if (is_p(&toks[i], "^"))
            buf_puts(&suffix, "^");
        if (is_p(&toks[i], "(")) {
            function_pointer = function_pointer || is_p(&toks[i - 1], "^");
            function = true;
        }
        int end = is_p(&toks[i], "^") ? i + 1 : skip_group(i);
        if (is_p(&toks[i], "["))
            for (int k = i; k < end; k++)
                buf_puts(&dims, toks[k].text);
        i = end;
    }
    if (!is_p(&toks[i], ";") && !is_p(&toks[i], ",") && !is_p(&toks[i], "="))
        return;
    const char *name = toks[name_at].text;
    if (block)
        error_at(pos, "'%s ~ %s' as a statement would be read by C as a block-pointer declaration; "
                      "declarations are written 'var name:type'", type, name);
    char *quals = strfmt("%s%s", base_const ? "const " : "", base_volatile ? "volatile " : "");
    if (function_pointer)
        error_at(pos, "'%s' looks like a C function-pointer declaration; function pointer types are not "
                      "available in Kelvin yet", name);
    if (function)
        error_at(pos, "functions are declared at the top level as '%s(...):%s%s%s'", name, quals, type, suffix.buf);
    error_at(pos, "declarations are written 'var name:type', as in '%s%svar %s:%s%s%s%s'", storage ? storage : "",
             storage ? " " : "", name, quals, type, suffix.buf, dims.buf);
}

static Stmt *new_stmt(StmtKind kind, Pos pos) {
    Stmt *s = xcalloc(1, sizeof *s);
    s->kind = kind;
    s->pos = pos;
    return s;
}

static Stmt *parse_block(void) {
    Token *t = expect_p("{");
    Stmt *s = new_stmt(S_BLOCK, t->pos);
    open_scope();
    while (!is_p(peek(), "}")) {
        if (peek()->kind == TK_EOF)
            error_at(t->pos, "unterminated block");
        list_push(&s->stmts, parse_stmt());
    }
    close_scope();
    advance();
    return s;
}

/* the body of if/else/while/do/for or a label: a declaration is not
   allowed there, as in C */
static Stmt *parse_body(void) {
    stmt_is_body = true;
    return parse_stmt();
}

/* Does a declaration start at token i: `[static|extern] let` or `var`
   (#27)? */
static bool binding_ahead(int i) {
    if (is_kw(&toks[i], "static") || is_kw(&toks[i], "extern"))
        i++;
    return is_kw(&toks[i], "let") || is_kw(&toks[i], "var");
}

/* C-era Kelvin's `name: i32 = 0;` without let or var (#27): a name, `:`,
   and a type that starts with a type word, such as `i32`, `u8 const^`
   or `struct p`. `again: n = 0;` stays a label before a statement. */
static void reject_bare_declaration(int i) {
    if (is_kw(&toks[i], "static") || is_kw(&toks[i], "extern"))
        i++;
    if (toks[i].kind != TK_IDENT || !is_p(&toks[i + 1], ":"))
        return;
    Token *t = &toks[i + 2];
    if (!is_base_word(t) && !is_qualifier(t) && !is_kw(t, "struct") && !is_kw(t, "union") && !is_kw(t, "enum") &&
        !tag_name_ahead(t, false))
        return;
    int end = type_shape_end(i + 2);
    if (end >= 0 && (is_p(&toks[end], "=") || is_p(&toks[end], ":=") || is_p(&toks[end], ";") ||
                     is_p(&toks[end], ",")))
        error_at(toks[i].pos, "declarations start with let or var: write 'var %s:...', or 'let %s:...' if it "
                              "never changes",
                 toks[i].text, toks[i].text);
}

static Stmt *parse_declaration(void) {
    Stmt *s = new_stmt(S_VAR, peek()->pos);
    s->storage = parse_storage();
    bool is_let = accept_kw("let");
    if (!is_let && !accept_kw("var"))
        error_at(peek()->pos, "expected 'let' or 'var'");
    parse_var_list(&s->vars, is_let, s->storage);
    return s;
}

static Expr *parse_paren_expr(void) {
    expect_p("(");
    Expr *e = parse_expr();
    expect_p(")");
    return e;
}

/* The condition of if, while or do (#23): a bool, with no parentheses
   needed, as in `if n > 0 { ... }` */
static Expr *parse_condition(const char *what) {
    if (is_p(peek(), "(")) {
        /* C's `if (x) y = 1;`: the body must be a block */
        Token *after = after_matching_paren(cur);
        if (after && (after->kind == TK_IDENT || after->kind == TK_NUMBER || after->kind == TK_STRING ||
                      is_kw(after, "return") || is_kw(after, "break") || is_kw(after, "continue") ||
                      is_kw(after, "goto") || is_kw(after, "if") || is_kw(after, "while") || is_kw(after, "for") ||
                      is_kw(after, "do") || is_kw(after, "switch") || (is_p(after, ";") && strcmp(what, "do"))))
            error_at(after->pos, "the body of '%s' is a block: write '%s cond { ... }'", what, what);
    }
    bool saved = brace_ends_condition;
    brace_ends_condition = strcmp(what, "do") != 0;
    Expr *e = parse_expr();
    brace_ends_condition = saved;
    require_bool(e);
    return e;
}

/* the body of if, else, while or do: a block (#23) */
static Stmt *parse_block_body(const char *what) {
    if (!is_p(peek(), "{"))
        error_at(peek()->pos, "expected '{': the body of '%s' is a block, as in '%s cond { ... }'", what,
                 strcmp(what, "do") ? what : "while");
    return parse_block();
}

/* an integer, an enum, or a C typedef name kelvinc cannot see */
static bool is_integer_type(Type *t) {
    Decl *record;
    char c = type_class(t, &record);
    return c == 'i' || c == 'u';
}

/* for i in a..<b { } and for i in a...b { } (#28): i runs from a up to
   b, without b or with it, and is a let in the body. Both bounds are
   evaluated once. A bound is an expression down to the shifts, so
   `0..<n - 1` ends before n - 1. i's type is written (`for i: u8 in`) or
   comes from the bounds: the upper one's type if kelvinc sees it, else the
   lower one's, else i64 for literals. `for _ in 0..<n` names no variable. */
static Stmt *parse_for_in(Pos pos) {
    Stmt *s = new_stmt(S_FOR_IN, pos);
    Token *name = peek();
    s->name = advance()->text;
    Type *written = accept_p(":") ? parse_type() : NULL;
    if (peek()->kind != TK_IDENT || strcmp(peek()->text, "in"))
        error_at(peek()->pos, "expected 'in', as in 'for %s in 0..<n { ... }', or 'for (...)'", s->name);
    advance();
    int prec = binary_prec(&(Token){.kind = TK_PUNCT, .text = "<<"});
    s->expr = parse_binary(prec);
    if (accept_p("..."))
        s->closed = true;
    else if (!accept_p("..<"))
        error_at(peek()->pos, "expected '..<' or '...' in a range, as in '0..<n' or '1...n'");
    bool saved = brace_ends_condition;
    brace_ends_condition = true;
    s->step = parse_binary(prec);
    brace_ends_condition = saved;
    /* both bounds, and a written type, must be integers */
    if (written && !is_integer_type(written))
        error_at(written->pos, "a range is of integers, not %s", kelvin_type(written));
    Type *t = written;
    for (int i = 0; i < 2; i++) {
        Expr *bound = i == 0 ? s->step : s->expr;
        Type *seen = value_type(bound);
        const char *lit = literal_type(bound);
        if (seen && !is_integer_type(seen))
            error_at(bound->pos, "a range is of integers, not %s", kelvin_type(seen));
        if (lit && strcmp(lit, "i64"))
            error_at(bound->pos, "a range is of integers, not %s", lit);
        if (!t && seen)
            t = seen;
    }
    if (!t)
        t = base_type("i64", name->pos);
    /* the counter must change: drop const and volatile from the bound's type */
    Type *plain = xcalloc(1, sizeof *plain);
    *plain = *t;
    plain->is_const = plain->is_volatile = false;
    t = plain;
    s->type = t;
    open_scope();
    if (strcmp(s->name, "_"))
        declare_binding(s->name, t, LET_RANGE);
    if (!is_p(peek(), "{"))
        error_at(peek()->pos, "expected '{': the body of 'for' is a block, as in 'for %s in a..<b { ... }'", s->name);
    s->body = parse_block();
    close_scope();
    return s;
}

static Stmt *parse_stmt(void) {
    Token *t = peek();
    Pos pos = t->pos;
    bool as_body = stmt_is_body;
    stmt_is_body = false;

    if (is_p(t, "{"))
        return parse_block();
    if (accept_p(";"))
        return new_stmt(S_EMPTY, pos);
    if (binding_ahead(cur)) {
        if (as_body)
            error_at(pos, "a declaration cannot be the body of a statement or follow a label; put it in a block, "
                          "or write 'label: ;' before it");
        Stmt *s = parse_declaration();
        expect_p(";");
        return s;
    }
    reject_bare_declaration(cur);
    if (is_kw(t, "static") || is_kw(t, "extern") || is_kw(t, "register") || is_kw(t, "auto"))
        reject_c_declaration();
    if (accept_kw("if")) {
        Stmt *s = new_stmt(S_IF, pos);
        s->expr = parse_condition("if");
        s->body = parse_block_body("if");
        if (accept_kw("else")) {
            if (!is_kw(peek(), "if") && !is_p(peek(), "{"))
                error_at(peek()->pos, "expected '{' or 'if' after 'else': the body of 'else' is a block");
            s->els = is_p(peek(), "{") ? parse_block() : parse_stmt();
        }
        return s;
    }
    if (accept_kw("while")) {
        Stmt *s = new_stmt(S_WHILE, pos);
        s->expr = parse_condition("while");
        s->body = parse_block_body("while");
        return s;
    }
    if (accept_kw("do")) {
        Stmt *s = new_stmt(S_DO, pos);
        s->body = parse_block_body("do");
        if (!accept_kw("while"))
            error_at(peek()->pos, "expected 'while' after the body of 'do'");
        s->expr = parse_condition("do");
        expect_p(";");
        return s;
    }
    if (accept_kw("for")) {
        if (peek()->kind == TK_IDENT)
            return parse_for_in(pos);
        Stmt *s = new_stmt(S_FOR, pos);
        expect_p("(");
        open_scope();
        if (binding_ahead(cur) && !is_kw(peek(), "static") && !is_kw(peek(), "extern")) {
            s->init = parse_declaration();
        } else if (!is_p(peek(), ";")) {
            reject_bare_declaration(cur);
            reject_c_declaration();
            s->init = new_stmt(S_EXPR, peek()->pos);
            s->init->expr = parse_assignments();
        }
        expect_p(";");
        if (!is_p(peek(), ";")) {
            s->expr = parse_expr();
            require_bool(s->expr);
        }
        expect_p(";");
        if (!is_p(peek(), ")"))
            s->step = parse_assignments();
        expect_p(")");
        s->body = parse_body();
        close_scope();
        return s;
    }
    if (accept_kw("switch")) {
        Stmt *s = new_stmt(S_SWITCH, pos);
        s->expr = parse_paren_expr();
        s->body = parse_body();
        return s;
    }
    if (accept_kw("case")) {
        Stmt *s = new_stmt(S_CASE, pos);
        bool saved = ident_annotation_ok;
        ident_annotation_ok = false;
        s->expr = parse_conditional();
        ident_annotation_ok = saved;
        expect_p(":");
        return s;
    }
    if (accept_kw("default")) {
        expect_p(":");
        return new_stmt(S_DEFAULT, pos);
    }
    if (accept_kw("break")) {
        expect_p(";");
        return new_stmt(S_BREAK, pos);
    }
    if (accept_kw("continue")) {
        expect_p(";");
        return new_stmt(S_CONTINUE, pos);
    }
    if (accept_kw("return")) {
        Stmt *s = new_stmt(S_RETURN, pos);
        if (!is_p(peek(), ";"))
            s->expr = parse_expr();
        expect_p(";");
        return s;
    }
    if (accept_kw("goto")) {
        Stmt *s = new_stmt(S_GOTO, pos);
        s->name = expect_ident("a label");
        expect_p(";");
        return s;
    }
    if (t->kind == TK_IDENT && is_p(peek2(), ":")) {
        Stmt *s = new_stmt(S_LABEL, pos);
        s->name = advance()->text;
        advance();
        s->body = parse_body();
        return s;
    }
    if (t->kind == TK_IDENT && !strcmp(t->text, "_Pragma") && is_p(peek2(), "(") &&
        peek_at(2)->kind == TK_STRING && is_p(peek_at(3), ")") && is_p(peek_at(4), ";")) {
        pragma_statement = true;
        Stmt *s = new_stmt(S_EXPR, pos);
        s->expr = parse_assignments();
        pragma_statement = false;
        expect_p(";");
        return s;
    }
    reject_c_declaration();
    bool call_like = is_converter(t) && is_p(peek2(), "(");
    if (!call_like && (starts_type(t) || (tag_name_ahead(t, false) && !is_p(peek2(), "(") && !is_p(peek2(), ".")))) {
        const char *example = "T";
        if ((is_kw(t, "struct") || is_kw(t, "union") || is_kw(t, "enum")) && peek2()->kind == TK_IDENT)
            example = strfmt("%s %s", t->text, peek2()->text);
        else if ((is_base_word(t) && !is_kw(t, "any")) || t->kind == TK_IDENT)
            example = t->text;
        error_at(pos, "declarations are written 'var name:type', as in 'var x:%s'", example);
    }
    Stmt *s = new_stmt(S_EXPR, pos);
    s->expr = parse_assignments();
    expect_p(";");
    return s;
}

/* ---------- top level ---------- */

static Decl *new_decl(DeclKind kind, Pos pos, const char *storage) {
    Decl *d = xcalloc(1, sizeof *d);
    d->kind = kind;
    d->pos = pos;
    d->storage = storage;
    return d;
}

static Decl *parse_fn(Pos pos, const char *storage) {
    Decl *d = new_decl(D_FN, pos, storage);
    Token *name = peek();
    d->name = expect_ident("a function name");
    if (!strcmp(d->name, "print") || !strcmp(d->name, "println"))
        error_at(name->pos, "'%s' is part of the Kelvin prelude and cannot be redefined", d->name);
    declare_name(d->name);
    open_scope();
    expect_p("(");
    while (!is_p(peek(), ")")) {
        if (accept_p("...")) {
            if (d->params.len == 0)
                error_at(pos, "a variadic function needs at least one named parameter");
            d->variadic = true;
            break;
        }
        bool mutable = accept_kw("var"); /* parameters are lets unless var (#27) */
        Var *p = parse_var(false, LET_NONE);
        p->is_let = !mutable;
        declare_binding(p->name, param_type(p->type), p->is_let ? LET_PARAM : LET_NONE);
        list_push(&d->params, p);
        if (!accept_p(","))
            break;
    }
    expect_p(")");
    if (accept_p(":"))
        d->ret = parse_type();
    list_push(&functions, d);
    if (!accept_p(";"))
        d->body = parse_block();
    close_scope();
    return d;
}

/* type.name(params): T { ... }, a method with an implicit `self`. The
   receiver is a struct or union declared earlier, or a built-in type. */
static Decl *parse_method(Pos pos, const char *storage) {
    Token *recv = advance();
    advance(); /* . */
    Token *name = peek();
    Decl *d = new_decl(D_FN, pos, storage);
    d->name = expect_ident("a method name");
    d->recv_name = recv->text;
    if (!strcmp(d->name, "toString") || !strcmp(d->name, "fmt"))
        error_at(name->pos, "%s() " SHELVED_HINT, d->name);
    if (recv->kind == TK_KEYWORD) {
        if (is_kw(recv, "any") || is_kw(recv, "_Complex") || is_kw(recv, "cstr"))
            error_at(recv->pos, "'%s' cannot have methods", recv->text);
        d->recv = base_type(recv->text, recv->pos);
    } else {
        Decl *r = NULL;
        for (int i = records.len - 1; i >= 0 && !r; i--) {
            Decl *c = records.data[i];
            if (c->name && !strcmp(c->name, recv->text))
                r = c;
        }
        if (!r)
            error_at(recv->pos, "'%s' is not a struct or union declared before this method", recv->text);
        if (r->kind == D_ENUM)
            error_at(recv->pos, "enums cannot have methods: C cannot tell an enum from its integer type");
        d->recv = base_type(strfmt("%s %s", r->kind == D_STRUCT ? "struct" : "union", r->name), recv->pos);
    }
    open_scope();
    declare_typed("self", d->recv);
    expect_p("(");
    while (!is_p(peek(), ")")) {
        if (accept_p("...")) {
            d->variadic = true;
            break;
        }
        bool mutable = accept_kw("var"); /* parameters are lets unless var (#27) */
        Var *p = parse_var(false, LET_NONE);
        p->is_let = !mutable;
        declare_binding(p->name, param_type(p->type), p->is_let ? LET_PARAM : LET_NONE);
        list_push(&d->params, p);
        if (!accept_p(","))
            break;
    }
    expect_p(")");
    if (accept_p(":"))
        d->ret = parse_type();
    list_push(&functions, d);
    if (!accept_p(";"))
        d->body = parse_block();
    close_scope();
    return d;
}

static Decl *parse_record(Pos pos, DeclKind kind) {
    Decl *d = new_decl(kind, pos, NULL);
    if (kind == D_ENUM && is_p(peek(), "{"))
        d->name = NULL; /* anonymous enum: a group of int constants */
    else
        d->name = expect_ident("a tag name");
    list_push(&records, d);
    if (accept_p("{")) {
        d->has_body = true;
        while (!is_p(peek(), "}")) {
            if (kind == D_ENUM) {
                Var *v = xcalloc(1, sizeof *v);
                v->pos = peek()->pos;
                v->name = expect_ident("an enumerator");
                declare_name(v->name);
                if (accept_p("="))
                    v->init = parse_conditional();
                list_push(&d->members, v);
                if (!accept_p(","))
                    break;
            } else {
                do
                    list_push(&d->members, parse_var(false, LET_NONE));
                while (accept_p(","));
                expect_p(";");
            }
        }
        expect_p("}");
    }
    expect_p(";");
    return d;
}

Program *parse(Token *tokens, int ntoks) {
    (void)ntoks;
    toks = tokens;
    cur = 0;
    scope_names = (List){0};
    scope_types = (List){0};
    scope_lets = (List){0};
    scope_marks = (List){0};
    records = (List){0};
    functions = (List){0};
    method_names = (List){0};
    for (int i = 0, depth = 0; toks[i].kind != TK_EOF; i++) {
        if (is_p(&toks[i], "{"))
            depth++;
        else if (is_p(&toks[i], "}"))
            depth--;
        else if (depth == 0 && (toks[i].kind == TK_IDENT || is_base_word(&toks[i])) && is_p(&toks[i + 1], ".") &&
                 toks[i + 2].kind == TK_IDENT && is_p(&toks[i + 3], "("))
            list_push(&method_names, toks[i + 2].text);
    }
    Program *prog = xcalloc(1, sizeof *prog);
    while (peek()->kind != TK_EOF) {
        Token *t = peek();
        if (t->kind == TK_IMPORT) {
            Decl *d = new_decl(D_IMPORT, t->pos, NULL);
            d->name = advance()->text;
            list_push(&prog->decls, d);
            continue;
        }
        const char *storage = parse_storage();
        if ((peek()->kind == TK_IDENT || is_base_word(peek())) && is_p(peek2(), ".") &&
            peek_at(2)->kind == TK_IDENT && is_p(peek_at(3), "(")) {
            list_push(&prog->decls, parse_method(t->pos, storage));
        } else if (peek()->kind == TK_IDENT && is_p(peek2(), "(")) {
            list_push(&prog->decls, parse_fn(t->pos, storage));
        } else if (is_kw(peek(), "let") || is_kw(peek(), "var")) {
            Decl *d = new_decl(D_VAR, t->pos, storage);
            bool is_let = is_kw(advance(), "let");
            parse_var_list(&d->members, is_let, storage);
            expect_p(";");
            list_push(&prog->decls, d);
        } else if (peek()->kind == TK_IDENT && (is_p(peek2(), ":") || is_p(peek2(), "=") || is_p(peek2(), ":="))) {
            error_at(peek()->pos, "declarations start with let or var: write 'var %s ...', or 'let %s ...' if it "
                                  "never changes",
                     peek()->text, peek()->text);
        } else if (!storage && accept_kw("struct")) {
            list_push(&prog->decls, parse_record(t->pos, D_STRUCT));
        } else if (!storage && accept_kw("union")) {
            list_push(&prog->decls, parse_record(t->pos, D_UNION));
        } else if (!storage && accept_kw("enum")) {
            list_push(&prog->decls, parse_record(t->pos, D_ENUM));
        } else {
            error_at(peek()->pos, "expected a declaration (name(...):type, let or var name, struct, union, enum), found %s", desc(peek()));
        }
    }
    return prog;
}
