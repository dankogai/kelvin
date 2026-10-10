/* parser.c - recursive descent over C's grammar with Kelvin's changes:

   - declarations put the type after the name: `var x: int`, `fn f() -> int`
   - types are postfix: `int^` is a pointer to int
   - dereference is postfix: `p^`, so `p->m` is written `p^.m`
   - XOR is binary `~` (and `~=`); `^` only means "pointer"

   Operator precedence is otherwise exactly C's. */
#include "kelvin.h"

#include <ctype.h>
#include <stdint.h>
#include <stdlib.h>
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
static bool line_break(Token *a, Token *b);
static bool newline_before(void);
static char *kelvin_type(Type *t);
static char *source_text(int i, int end);
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
enum { LET_NONE, LET_VALUE, LET_PARAM, LET_RANGE, LET_EACH };
static List scope_lets;
static List scope_moved; /* per binding: moved out, so dead until assigned anew (#54) */

static void open_scope(void) { list_push(&scope_marks, (void *)(intptr_t)scope_names.len); }

static void close_scope(void) {
    scope_names.len = scope_types.len = scope_lets.len = scope_moved.len =
        (int)(intptr_t)scope_marks.data[--scope_marks.len];
}

static void declare_binding(const char *name, Type *type, int let) {
    list_push(&scope_names, (void *)name);
    list_push(&scope_types, type);
    list_push(&scope_lets, (void *)(intptr_t)let);
    list_push(&scope_moved, (void *)0);
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

/* where the innermost binding of `name` sits in scope_names, or -1 */
static int binding_index(const char *name) {
    for (int i = scope_names.len - 1; i >= 0; i--)
        if (!strcmp(scope_names.data[i], name))
            return i;
    return -1;
}

/* Is name declared in the innermost scope? */
static bool bound_here(const char *name) {
    return scope_marks.len && binding_index(name) >= (int)(intptr_t)scope_marks.data[scope_marks.len - 1];
}

/* the function or method being parsed, and where its parameters sit in
   scope_names */
static Decl *parsing_fn;
static int params_start, params_end;
/* the first token of that function's body and its closing `}`, where
   one expression is what the body returns (#35) */
static int body_first = -1, body_end = -1;

/* main keeps C's rule that its end returns 0 (#35) */
static bool is_main(Decl *d) { return !d->anon && !d->recv && !strcmp(d->name, "main"); }

/* Is the statement from token first, ending before token end (a `;` or
   what follows it), the one expression that the body being parsed
   returns, as in `{ x * x }` (#35)? */
static bool returned_statement(int first, int end) {
    if (!parsing_fn || !parsing_fn->ret || is_main(parsing_fn) || first != body_first)
        return false;
    return (toks[end].kind == TK_PUNCT && !strcmp(toks[end].text, ";") ? end + 1 : end) == body_end;
}

/* Anonymous functions (#32): those finished, which go before the
   top-level declaration around them; where the innermost one's bindings
   start in scope_names (-1 outside one); how its parameters were given;
   and the token just past a trailing `{ }`, which ends a statement */
static List anon_fns;
/* the structs with no tag (#59), Decl *, one per spelling, in order of first use */
static List anon_records;
static List anon_names;     /* their C names, _kv_main_fn and so on (#38) */
static const char *top_name; /* the top-level declaration being parsed */
static int anon_start = -1;
enum { ANON_BARE, ANON_WRITTEN, ANON_CONTEXT };
static int anon_kind;
static int trailing_end = -1;
/* for $'s hints: the `{` of a body that follows a call in a condition,
   the `{` of a block on the line after a call (#35), how deep in
   initializer lists the parser is, and whether it is reading an
   anonymous function's written parameters */
static int body_after_call = -1;
static int block_after_call = -1;
static int init_depth;
static bool in_signature;
/* for $'s hint in a function whose parameter kelvinc could not see */
static const char *pending_note, *anon_note;
/* the token where a `{` may start an anonymous function, and the type
   it takes there (NULL: none in sight) */
static int fn_at = -1;
static Type *fn_type;

/* the parameter of the function being parsed that `name` names here,
   unless a local name hides it */
static Var *param_named(const char *name) {
    int i = binding_index(name);
    if (!parsing_fn || i < params_start || i >= params_end)
        return NULL;
    for (int k = 0; k < parsing_fn->params.len; k++) {
        Var *p = parsing_fn->params.data[k];
        if (!strcmp(p->name, name))
            return p;
    }
    return NULL;
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

static const char *desc(Token *t) {
    if (t->kind == TK_TPL_HEAD || t->tpl)
        return "a template literal";
    if (t->kind == TK_TPL_MIDDLE || t->kind == TK_TPL_TAIL)
        return "'}', the end of ${...}";
    if (t->kind == TK_FILE_END)
        return strfmt("the end of %s", t->text);
    return t->kind == TK_EOF ? "end of file" : strfmt("'%s'", t->text);
}

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
                                   "u64", "u128", "f32", "f64", "bool", "_Complex", "any", "cstr", "Bytes", "String", "uchr", "Array", "Dictionary", NULL};

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
    return is_base_word(t) && !is_kw(t, "any") && !is_kw(t, "_Complex") && !is_kw(t, "cstr") && !is_kw(t, "Bytes") && !is_kw(t, "String") && !is_kw(t, "Array") && !is_kw(t, "Dictionary");
}

/* toString(), fmt() and String wait for a true string type (#22) */
#define SHELVED_HINT "is not a method: a value's text is 'x.cstr', and String(x.cstr) a String (#22, #55)"

static bool starts_type(Token *t);

/* Does `(` begin a parenthesized type, as in sizeof(T) or (T){...}?
   `(i32(x) + 1)` does not: a type name directly followed by `(` is a
   converter call. */
static bool is_qualifier(Token *t);

static int typeof_at(int i);
static int type_suffix_end(int i);
static bool type_is_field(int i, int dot);

static bool paren_type_ahead(bool in_sizeof) {
    if (!is_p(peek(), "("))
        return false;
    int dot = typeof_at(cur + 1);
    if (dot >= 0) /* sizeof(v.type), unless .type is a field there (#34) */
        return !type_is_field(cur + 1, dot) && is_p(&toks[type_suffix_end(dot + 2)], ")");
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
           n->kind == TK_TPL_HEAD ||
           (n->kind == TK_PUNCT && n->text[0] == '$') ||
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
static char type_class(Type *t, Decl **record);
static bool record_has_field(Decl *r, const char *name);
static Type *param_type(Type *t);

/* If the tokens from i spell a value's type, `v.type` (#34): a name or
   $k, then .member, ^ or [...] steps, then .type, the index of the `.`
   of the last .type; otherwise -1 */
static int typeof_at(int i) {
    bool dollar = toks[i].kind == TK_PUNCT && toks[i].text[0] == '$';
    if (toks[i].kind != TK_IDENT && !dollar)
        return -1;
    int j = i + 1, dot = -1;
    if (dollar && !toks[i].text[1]) { /* $[k] */
        if (!is_p(&toks[j], "["))
            return -1;
        j = skip_group(j);
    }
    for (;;) {
        if (is_p(&toks[j], ".") && toks[j + 1].kind == TK_IDENT) {
            if (!strcmp(toks[j + 1].text, "type"))
                dot = j;
            j += 2;
        } else if (is_p(&toks[j], "^")) {
            j++;
        } else if (is_p(&toks[j], "[")) {
            j = skip_group(j);
        } else {
            return dot;
        }
    }
}

/* the index just past the ^, [...] and qualifiers after a type ending at i */
static int type_suffix_end(int i) {
    for (;;) {
        if (is_p(&toks[i], "^") || is_kw(&toks[i], "const") || is_kw(&toks[i], "volatile"))
            i++;
        else if (is_p(&toks[i], "["))
            i = skip_group(i);
        else
            return i;
    }
}

static Type *fn_type_of(Decl *d);
static Type *base_type(const char *name, Pos pos);
static Type *cstr_type(Pos pos);
static bool is_cstr(Type *t);
static Expr *drop_cstr(Expr *v, Type *target);
static bool is_bytes(Type *t);
static bool is_string(Type *t);
static bool is_uchr(Type *t);
static bool is_array_owner(Type *t);
static Program *program; /* the program being parsed: its Array<T> types (#57) */
static Type *parse_array_elem(void);
static void check_array_elem(Type *elem);
static Expr *array_of_list(Token *t, Type *at);
static Type *array_type(Token *at, Type *elem);
static Type *list_type(Expr *e, Pos pos);
static char *mangled_type(Type *t);
static Expr *utf32_of(Expr *c);
static const char *builtin_owner(Type *t);
static bool is_owner(Type *t);
static bool owner_place(Expr *e);
static bool is_moved(const char *name);
static void set_moved(const char *name, bool moved);
static void reject_owner_copy(Expr *value, Type *target, Pos pos);
static void reject_record_mismatch(Expr *value, Type *target, Pos pos);
static void move_argument(Expr *arg, Type *param, const char *what);
static void check_appended(Expr *given, const char *kind, const char *what);
static const char *array_append_kind(Expr *given, Type *array);
static const char *let_target(Expr *e);
static Type *value_type(Expr *e);

/* Is name a Kelvin enumerator that no local hides? */
static bool enumerator_named(const char *name) {
    int global_end = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
    int i = binding_index(name);
    if (i < 0 || i >= global_end)
        return false;
    for (int k = 0; k < records.len; k++) {
        Decl *r = records.data[k];
        for (int m = 0; r->kind == D_ENUM && m < r->members.len; m++)
            if (!strcmp(((Var *)r->members.data[m])->name, name))
                return true;
    }
    return false;
}

/* the type kelvinc sees for the value that the tokens from i to end
   spell (a name or $k, then .member, ^ and [...] steps), or NULL */
static Type *chain_type(int i, int end) {
    Type *t = NULL;
    int j = i + 1;
    if (toks[i].kind == TK_IDENT) {
        t = lookup_type(toks[i].text);
        if (t && t->kind == T_TYPEOF)
            t = t->elem;
        Decl *f = t ? NULL : function_named(toks[i].text);
        if (f)
            t = fn_type_of(f);
        if (!t && enumerator_named(toks[i].text))
            t = base_type("i32", toks[i].pos); /* C's int */
    } else if (anon_start >= 0 && parsing_fn) { /* $k, $[k] */
        const char *digits = toks[i].text + 1;
        if (!*digits) {
            digits = toks[i + 2].text;
            j = skip_group(i + 1);
        }
        int k = strlen(digits) > 6 ? -1 : atoi(digits);
        if (k >= 0 && k < parsing_fn->params.len)
            t = lookup_type(((Var *)parsing_fn->params.data[k])->name);
        if (t && t->kind == T_TYPEOF)
            t = t->elem;
    }
    while (t && j < end) {
        if (is_p(&toks[j], ".")) {
            const char *m = toks[j + 1].text;
            Decl *r = NULL;
            Type *f = NULL;
            if (t->kind == T_BASE && type_class(t, &r) == 's') {
                for (int k = 0; k < r->members.len; k++)
                    if (!strcmp(((Var *)r->members.data[k])->name, m))
                        f = ((Var *)r->members.data[k])->type;
            } else if (t->kind == T_PTR && (!strcmp(m, "next") || !strcmp(m, "prev"))) {
                f = t;
            }
            t = f && f->kind == T_TYPEOF ? f->elem : f;
            j += 2;
        } else if (is_p(&toks[j], "^") || is_p(&toks[j], "[")) {
            t = t->kind == T_PTR || t->kind == T_ARRAY ? t->elem : NULL;
            j = is_p(&toks[j], "^") ? j + 1 : skip_group(j);
        } else {
            break;
        }
    }
    return t;
}

/* Where a value could stand too, as in `sizeof(ev.type)` or `(ev.type)`,
   is the `.type` at dot a field, as it is for a struct with such a field,
   a C struct, and a value kelvinc cannot see? (#34) */
static bool type_is_field(int i, int dot) {
    Type *t = chain_type(i, dot);
    Decl *r;
    char c = type_class(t, &r);
    return !t || c == 'c' || c == 'u' || (c == 's' && record_has_field(r, "type"));
}

static int type_shape_end(int i) {
    int start = i;
    while (is_qualifier(&toks[i]))
        i++;
    if (is_p(&toks[i], "$") && is_p(&toks[i + 1], "[")) /* $[T], an Array<T> (#64) */
        return type_suffix_end(skip_group(i + 1));
    if (is_kw(&toks[i], "Dictionary") && is_p(&toks[i + 1], "<")) { /* Dictionary<K, V> (#65) */
        int e = type_shape_end(i + 2);
        if (e < 0 || !is_p(&toks[e], ","))
            return -1;
        e = type_shape_end(e + 1);
        if (e < 0 || (!is_p(&toks[e], ">") && !is_p(&toks[e], ">>")))
            return -1;
        return type_suffix_end(is_p(&toks[e], ">>") ? e : e + 1);
    }
    if (is_kw(&toks[i], "Array") && is_p(&toks[i + 1], "<")) { /* Array<T> (#57) */
        int e = type_shape_end(i + 2);
        if (e < 0 || (!is_p(&toks[e], ">") && !is_p(&toks[e], ">>")))
            return -1;
        return type_suffix_end(is_p(&toks[e], ">>") ? e : e + 1); /* >> closes two */
    }
    if (is_p(&toks[i], "{")) /* {x:f64, y:f64}, a struct with no tag (#59) */
        return type_suffix_end(skip_nested(i));
    if (is_p(&toks[i], "[")) { /* [T] or [T](N), an array (#49) */
        int e = type_shape_end(i + 1);
        if (e < 0 || !is_p(&toks[e], "]"))
            return -1;
        i = e + 1;
        if (is_p(&toks[i], "(") && !line_break(&toks[i - 1], &toks[i]))
            i = skip_group(i);
        return type_suffix_end(i);
    }
    int dot = typeof_at(i);
    if (dot >= 0) /* after a qualifier, only a type can follow */
        return i == start && type_is_field(i, dot) ? -1 : type_suffix_end(dot + 2);
    if (is_kw(&toks[i], "struct") || is_kw(&toks[i], "union") || is_kw(&toks[i], "enum")) {
        if (is_p(&toks[i + 1], "{")) /* union{i:i32, f:f32}, enum{...}: no tag (#60, #61) */
            return type_suffix_end(skip_nested(i + 1));
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
    return is_base_word(t) || is_qualifier(t) || is_kw(t, "struct") || is_kw(t, "union") || is_kw(t, "enum") ||
           is_p(t, "["); /* [T], an array (#49) */
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
static Type *parse_type_in(TypeContext ctx);
static Type *parse_anon_record(DeclKind kind, bool tagged);
static Type *parse_dollar_array(Token *at);
static Type *dict_type(Token *at, Type *key, Type *val);
static bool is_dict_owner(Type *t);
static Type *parse_dict_types(Token *kw);
static Expr *dict_of_list(Token *t, Type *dt, Token *open, Expr *first);
static Expr *dict_key(Expr *k, Type *dt);
static Type *inferred_type(Expr *e, Pos pos);
static Expr *property(Expr *e, Token *name, char *member);
static bool is_text_expr(Expr *e);
static Type *array_type(Token *at, Type *elem);
static Decl *anon_record_of(Type *t);
static void reject_kv_name(Token *t);
static void parse_cases(Decl *d);
static bool brace_has_colon(int i);
static Var *case_named(Decl *r, const char *name, int *index);
static Expr *case_value(Type *t);
static Decl *tagged_record(Type *t);
static char *case_list(Decl *r);
static char *record_spelling(Decl *r);
static Type *unqualified(Type *t);
static Expr *parse_case_initializer(Type *t, Decl *r);
static void move_argument(Expr *arg, Type *param, const char *what);
/* the enum with values a switch is on, while its body is parsed (#61) */
static Decl *switch_record;
/* the depth of blocks being parsed, and the depth at which the cases of
   the switch being parsed are written: at the top of its block (#63) */
static int block_depth, case_depth = -1;
static void parse_case_label(Stmt *s);
static void check_switch(Stmt *s);
static Type *parse_type(void);
static Type *parse_typeof(int dot);

/* Does e name a local or a parameter, which means something else, or
   nothing, in another scope? (#32) */
static bool type_names_local(Type *t);

static bool names_local(Expr *e) {
    if (!e)
        return false;
    if (e->kind == E_IDENT) {
        int locals = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
        return binding_index(e->text) >= locals;
    }
    /* call and method arguments, initializer items, and types written in
       sizeof, conversions and compound literals */
    bool items = e->kind == E_CALL || e->kind == E_METHOD || e->kind == E_INIT || e->kind == E_TEMPLATE;
    for (int i = 0; items && i < e->items.len; i++)
        if (names_local(e->items.data[i]))
            return true;
    for (int i = 0; e->kind == E_INIT && i < e->designators.len; i++)
        if (names_local(e->designators.data[i]))
            return true;
    if ((e->kind == E_SIZEOF_TYPE || e->kind == E_CAST || e->kind == E_COMPOUND) && type_names_local(e->type))
        return true;
    return names_local(e->a) || names_local(e->b) || names_local(e->c);
}

/* Does t have an array length that names a local or a parameter? */
static bool type_names_local(Type *t) {
    if (!t)
        return false;
    switch (t->kind) {
    case T_ARRAY:
        return t->size_local || names_local(t->size) || type_names_local(t->elem);
    case T_PTR:
        return type_names_local(t->elem);
    case T_TYPEOF:
        return names_local(t->of);
    case T_FUNC:
        for (int i = 0; i < t->params.len; i++)
            if (type_names_local(t->params.data[i]))
                return true;
        return type_names_local(t->elem);
    default:
        return false;
    }
}

/* Does t have an array length that names a local or a parameter? */
static bool has_local_size(Type *t) {
    if (!t)
        return false;
    switch (t->kind) {
    case T_ARRAY:
        return t->size_local || has_local_size(t->elem);
    case T_PTR:
        return has_local_size(t->elem);
    case T_TYPEOF:
        return t->size_local;
    case T_FUNC:
        /* a parameter's outer array is printed as a pointer, without its
           length */
        for (int i = 0; i < t->params.len; i++) {
            Type *p = t->params.data[i];
            if (has_local_size(p->kind == T_ARRAY ? p->elem : p))
                return true;
        }
        return has_local_size(t->elem);
    default:
        return false;
    }
}

/* (T, U):R, a function type (#31): C's pointer to a function, as
   `bool (*)(int64_t, int64_t)` for (i64, i64):bool. (T) has no result, as
   a function without `:R` has none. The result takes every suffix after
   it: (i64):i64^ returns a pointer. */
static Type *parse_fn_type(TypeContext ctx) {
    Token *open = expect_p("(");
    Type *t = xcalloc(1, sizeof *t);
    t->kind = T_FUNC;
    t->pos = open->pos;
    while (!is_p(peek(), ")")) {
        if (accept_p("...")) {
            if (!t->params.len)
                error_at(open->pos, "a variadic function type needs a parameter before '...', as in '(i32, ...)'");
            t->variadic = true;
            break;
        }
        if (peek()->kind == TK_IDENT && is_p(peek2(), ":"))
            error_at(peek()->pos, "a function type lists its parameters' types without names, as in "
                                  "'(i64, i64):bool'");
        list_push(&t->params, parse_type());
        if (!accept_p(","))
            break;
    }
    expect_p(")");
    /* in `c ? f as (i64) : g` or `: nullptr`, the `:` is the ?:'s: there a
       result must start with a type word, as an annotation must */
    Token *n = peek2();
    bool result = is_p(peek(), ":") &&
                  (ident_annotation_ok || ((is_base_word(n) && !(is_converter(n) && is_p(peek_at(2), "("))) ||
                                           is_qualifier(n) || is_kw(n, "struct") || is_kw(n, "union") ||
                                           is_kw(n, "enum")));
    if (result) {
        advance();
        t->elem = parse_type_in(ctx);
    } else if (is_p(peek(), "^") || is_p(peek(), "[")) {
        error_at(peek()->pos, "a pointer to a function type, or an array of functions, has no spelling yet (#31): "
                              "a function type is already a pointer, and several can go in a struct");
    }
    return t;
}

/* the first token of the type being parsed, for the hint that rewrites
   C-order T[N] as [T](N) (#49) */
static int type_start;

static Type *parse_type_in(TypeContext ctx) {
    type_start = cur;
    if (is_p(peek(), "("))
        return parse_fn_type(ctx);
    Type *base = xcalloc(1, sizeof *base);
    base->kind = T_BASE;
    base->pos = peek()->pos;
    parse_qualifiers(base);
    if (is_kw(peek(), "Dictionary")) { /* Dictionary<K, V> (#65) */
        Token *kw = advance();
        if (base->is_const || base->is_volatile)
            error_at(base->pos, "a qualifier of a Dictionary is the variable's: a let does not change");
        Type *t = parse_dict_types(kw);
        type_start = cur;
        return parse_type_suffixes(t, ctx);
    }
    if (is_kw(peek(), "Array")) {
        Token *kw = advance();
        if (base->is_const || base->is_volatile)
            error_at(base->pos, "a qualifier of an Array is the variable's: a let does not change");
        Type *t = array_type(kw, parse_array_elem());
        type_start = cur;
        return parse_type_suffixes(t, ctx);
    }
    if (is_p(peek(), "$")) { /* $[T] is Array<T>, and $[[T]] Array<Array<T>> (#64) */
        Token *d = advance();
        if (!is_p(peek(), "["))
            error_at(d->pos, "'$' before a type: $[T] is Array<T>, as $[a, b] is Array([a, b]); a String is written String");
        if (base->is_const || base->is_volatile)
            error_at(base->pos, "a qualifier of an Array is the variable's: a let does not change");
        Type *t = parse_dollar_array(d);
        type_start = cur;
        return parse_type_suffixes(t, ctx);
    }
    if (is_p(peek(), "[")) {
        /* [T] is an array of T, [T](N) one of N elements (#49); a
           qualifier is the elements', inside the brackets */
        if (base->is_const || base->is_volatile)
            error_at(base->pos, "a qualifier of an array is its elements': write it inside the brackets, as in "
                                "'[const u8]'");
        Token *open = advance();
        Type *elem = parse_type_in(TYPE_DECL);
        expect_p("]");
        Type *a = xcalloc(1, sizeof *a);
        a->kind = T_ARRAY;
        a->pos = open->pos;
        a->elem = elem;
        /* a `(` on the next line starts a statement (#35) */
        if (is_p(peek(), "(") && !newline_before()) {
            advance();
            a->size = parse_assign();
            a->size_local = names_local(a->size);
            expect_p(")");
        }
        type_start = cur;
        return parse_type_suffixes(a, ctx);
    }
    if (is_p(peek(), "{") || ((is_kw(peek(), "struct") || is_kw(peek(), "union") || is_kw(peek(), "enum")) &&
                              is_p(peek2(), "{"))) {
        /* {x:f64, y:f64}, a struct with no tag (#59); union{i:i32, f:f32} (#60);
           enum{i:i32, f:f32}, an enum with values, a tagged union (#61) */
        Token *kw = is_p(peek(), "{") ? NULL : advance();
        Type *t = parse_anon_record(kw && is_kw(kw, "union") ? D_UNION : D_STRUCT, kw && is_kw(kw, "enum"));
        t->is_const = base->is_const;
        t->is_volatile = base->is_volatile;
        parse_qualifiers(t);
        type_start = cur;
        return parse_type_suffixes(t, ctx);
    }
    int dot = typeof_at(cur);
    if (dot >= 0) { /* v.type (#34) */
        Type *t = parse_typeof(dot);
        Type q = {0};
        q.is_const = base->is_const;
        q.is_volatile = base->is_volatile;
        parse_qualifiers(&q);
        if (q.is_const || q.is_volatile) {
            /* as C has it, a qualifier on an array is on its elements */
            Type *at = t;
            while (at->kind == T_ARRAY) {
                Type *e = xcalloc(1, sizeof *e);
                *e = *at->elem; /* the elements are shared with v's type */
                at->elem = e;
                at = e;
            }
            at->is_const |= q.is_const;
            at->is_volatile |= q.is_volatile;
        }
        if (t->kind == T_FUNC && (is_p(peek(), "^") || is_p(peek(), "[")))
            error_at(peek()->pos, "a pointer to a function type, or an array of functions, has no spelling yet "
                                  "(#31): a function type is already a pointer, and several can go in a struct");
        return parse_type_suffixes(t, ctx);
    }
    if (is_base_word(peek()) && is_p(peek2(), ".") && peek_at(2)->kind == TK_IDENT &&
        !strcmp(peek_at(2)->text, "type"))
        error_at(peek()->pos, "'%s' is a type already: write '%s', not '%s.type'", peek()->text, peek()->text,
                 peek()->text);
    if (is_kw(peek(), "struct") || is_kw(peek(), "union") || is_kw(peek(), "enum")) {
        char *kw = advance()->text;
        base->name = strfmt("%s %s", kw, expect_ident("a tag name"));
    } else {
        /* one built-in type name, or a C typedef name such as FILE or
           size_t from an imported header; f32 and f64 may be _Complex */
        reject_c_int_name(peek());
        Token *name = peek();
        if (name->kind != TK_IDENT && (!is_base_word(name) || is_kw(name, "_Complex")))
            error_at(name->pos, "expected a type, found %s", desc(name));
        reject_kv_name(name); /* _kv_anonN is kelvinc's (#59) */
        advance();
        if (is_kw(name, "cstr")) {
            /* cstr is immutable text (#52): a pointer to const u8;
               qualifiers apply to the pointer */
            Type *p = cstr_type(name->pos);
            p->is_const = base->is_const;
            p->is_volatile = base->is_volatile;
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
            /* C's T[N] after a type, read as it was (P2) for the hint that
               spells it as [T](N) (#49) */
            int from = type_start;
            char *spelled = source_text(from, cur); /* the type before the brackets */
            List dims = {0};                        /* each count as written */
            while (is_p(peek(), "[")) {
                advance();
                int at = cur;
                if (!is_p(peek(), "]"))
                    parse_assign();
                list_push(&dims, source_text(at, cur));
                expect_p("]");
            }
            for (int i = dims.len - 1; i >= 0; i--)
                spelled = strfmt("[%s]%s%s%s", spelled, *(char *)dims.data[i] ? "(" : "", (char *)dims.data[i],
                                 *(char *)dims.data[i] ? ")" : "");
            int rest = cur;
            while (is_p(peek(), "^") || is_qualifier(peek())) /* T[N]^, a pointer to the array */
                advance();
            error_at(toks[from].pos, "an array type is written '[T]', or '[T](N)' with its count (#49): write '%s%s' for '%s'",
                     spelled, cur > rest ? source_text(rest, cur) : "", source_text(from, cur));
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
static Expr *convert(Token *t, const char *name, Expr *v, Expr *base);
static bool converter_is_field(Expr *v, const char *member);
static void require_bool(Expr *e);
_Noreturn static void reject_step(Token *t);
static bool binding_ahead(int i);
static bool seen_bool(Expr *e);
static char expr_class(Expr *e, Decl **record);
static bool record_has_field(Decl *r, const char *name);
static Expr *parse_anon_fn(Type *ctx);
static Expr *anon_arg(Type *param, int arity, int k, Expr *call, bool trailing);
static bool signature_ahead(int i);
static Type *call_param_type(Expr *callee, int k);
static int call_arity(Expr *callee);
static Decl *method_named(Expr *recv, const char *name);
static Expr *parse_dollar(void);
static bool overloadable_op(Token *t);
static int function_shape(int i);
static bool params_ahead(int i);
static void resolve_call(Expr *call);
static void pick_overload(Expr *v, Type *want);
static Expr *resolve_operator(Expr *e, const char *op, Expr *a, Expr *b);
static bool repeatable(Expr *e);
static bool reaches_c(List *cands, Expr *call, int k);
static void drop_cstr_args(Expr *call, Decl *d);
static void move_args(Expr *call, Decl *d);
static void reject_owners_to_c(Expr *call);
static List overloads_of(const char *name, const char *op);
static Expr *parse_initializer_for(Type *t);
static void count_items(Type *t, Expr *init);
static void check_print_args(Expr *call);
static bool is_function_designator(Expr *e);

/* set while parsing the head of `for x in ...`, where a `{` ends it too */
static bool brace_in_for;

/* the first token of the statement being parsed, for trailing `{ }` */
static int stmt_start;

/* Is the next token on a new line? */
/* Does token b start on a later line than token a ends? Where an
   imported file begins or ends (#40), it does, whatever the lines' numbers. */
static bool line_break(Token *a, Token *b) {
    return a->kind == TK_IMPORT_K || a->kind == TK_FILE_END || b->kind == TK_FILE_END || a->pos.file != b->pos.file ||
           b->pos.line > a->end_line;
}

static bool newline_before(void) { return cur > 0 && line_break(&toks[cur - 1], peek()); }

/* the tokens from i to the one before end, as written: a space where the
   source has one between two tokens */
static char *source_text(int i, int end) {
    Buf b = {0};
    buf_puts(&b, "");
    for (int k = i; k < end; k++) {
        if (k > i && (toks[k].pos.line != toks[k - 1].pos.line ||
                      toks[k].pos.col > toks[k - 1].pos.col + (int)strlen(toks[k - 1].text)))
            buf_puts(&b, " ");
        buf_puts(&b, toks[k].text);
    }
    return b.buf;
}


static bool at_statement_level(void);

/* At the top level of a statement, a `(` on a new line starts the next
   statement, as in Swift, rather than calling what went before (#35);
   an operator, `.member` or `[` there goes on with the expression */
static bool line_ends_expression(void) { return is_p(peek(), "(") && newline_before() && at_statement_level(); }

/* Does the token at the cursor start the next statement, being on a new
   line at the top level of a statement (#35)? There a `{` starts a block,
   and `(x)` before it is no cast or compound literal */
static bool line_starts_statement(void) { return newline_before() && at_statement_level(); }

/* Is the `{ }` that just ended at token cur at the top level of its
   statement, not inside parentheses, brackets or an initializer list? */
static bool at_statement_level(void) {
    int depth = 0;
    for (int i = stmt_start; i < cur; i++) {
        if (is_p(&toks[i], "(") || is_p(&toks[i], "[") || is_p(&toks[i], "{") || toks[i].kind == TK_TPL_HEAD)
            depth++;
        else if (toks[i].kind == TK_TPL_TAIL)
            depth--;
        else if (is_p(&toks[i], ")") || is_p(&toks[i], "]") || is_p(&toks[i], "}"))
            depth--;
    }
    return depth == 0;
}

static int binary_prec(Token *t);

/* Can token t go on with an expression before it, as an operator, a
   postfix or a separator does? */
static bool continues_expression(Token *t) {
    static const char *ops[] = {"(", "[", ".", "^", "?", ":", ",", ")", "]", "..<", "...", "=", ":=", "+=", "-=",
                                "*=", "/=", "%=", "<<=", ">>=", "&=", "~=", "|=", NULL};
    for (int i = 0; ops[i]; i++)
        if (is_p(t, ops[i]))
            return true;
    return binary_prec(t) > 0 || is_kw(t, "as");
}

/* Is the `{` at token i the initializer of a compound literal `(T){...}`
   rather than a body? Always outside a condition. In a condition, only
   when the expression goes on after its `}`, as in
   `if p.x == (struct point){1, 2}.x {`: in `if n == sizeof(i32) {} {`
   the first `{}` is the body */
static bool brace_is_compound(int i) {
    if (!brace_ends_condition)
        return true;
    Token *n = &toks[skip_nested(i)];
    if (brace_in_for && (is_p(n, "..<") || is_p(n, "...")))
        return true; /* for i in (i64){1}..<3 { */
    return is_p(n, ".") || is_p(n, "[") || is_p(n, "^") || is_p(n, "?") || is_kw(n, "as") || binary_prec(n) > 0;
}

static Expr *new_expr(ExprKind kind, Pos pos) {
    Expr *e = xcalloc(1, sizeof *e);
    e->kind = kind;
    e->pos = pos;
    return e;
}

/* the token where parse_postfix_ops stops, as before the .type of v.type */
static int postfix_stop = -1;

/* At the top level of a statement, a `{` on the line after a call's `)`
   starts a block (#35); one that writes an anonymous function's
   parameters, or one after a call that lacks a function argument, was
   meant as a trailing function */
static void reject_trailing_on_next_line(Type *missing) {
    if (signature_ahead(cur) || (missing && missing->kind == T_FUNC))
        error_at(peek()->pos, "a trailing function starts on the line of the call's ')': on the next line, '{' "
                              "starts a block");
}

static Expr *parse_postfix_ops(Expr *e) {
    for (;;) {
        if (line_ends_expression() || cur == postfix_stop)
            return e;
        Token *t = peek();
        if (is_p(peek(), "[") && is_string(value_type(e)))
            error_at(peek()->pos, "a String is not indexed by codepoint, which would walk it: walk it with 'for c in "
                                  "s', or index its bytes, 's.bytes^[i]'");
        if (is_p(peek(), "[") && is_bytes(value_type(e)) && !owner_place(e))
            error_at(peek()->pos, "indexing a Bytes that an expression gives: bind it to a variable first");
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
            if ((is_bytes(value_type(e)) || is_array_owner(value_type(e)) || is_dict_owner(value_type(e))) &&
                !owner_place(e))
                error_at(t->pos, "'[]' of %s that an expression gives, which nothing would free: bind it to a "
                                 "variable first",
                         is_bytes(value_type(e)) ? "a Bytes" : is_dict_owner(value_type(e)) ? "a Dictionary" : "an Array");
            if (is_dict_owner(value_type(e))) { /* d[k] of a Dictionary, checked (#65) */
                x->op = "dict";
                x->type = value_type(e);
                x->b = dict_key(x->b, x->type);
            }
            if (is_bytes(value_type(e)))
                x->op = "bytes"; /* b[i] of a Bytes is checked (#54) */
            if (is_array_owner(value_type(e))) { /* xs[i] of an Array too (#57) */
                x->op = "array";
                x->type = value_type(e);
            }
            e = x;
        } else if (accept_p("(")) {
            bool saved = ident_annotation_ok;
            bool saved_brace = brace_ends_condition;
            ident_annotation_ok = true;
            brace_ends_condition = false;
            Expr *x = new_expr(E_CALL, t->pos);
            x->a = e;
            while (!is_p(peek(), ")")) {
                list_push(&x->items, is_p(peek(), "{") ? anon_arg(call_param_type(e, x->items.len), call_arity(e),
                                                                  x->items.len, e, false)
                                                       : parse_assign());
                if (!accept_p(","))
                    break;
            }
            ident_annotation_ok = saved;
            brace_ends_condition = saved_brace;
            expect_p(")");
            /* f(x) { ... }: a trailing anonymous function is the last
               argument (#32), except where `{` starts a body, as it does
               on the next line at the top level of a statement (#35) */
            if (is_p(peek(), "{") && !brace_ends_condition && !line_starts_statement()) {
                list_push(&x->items,
                          anon_arg(call_param_type(e, x->items.len), call_arity(e), x->items.len, e, true));
                if (at_statement_level())
                    trailing_end = cur;
            } else if (is_p(peek(), "{") && brace_ends_condition) {
                body_after_call = cur;
            } else if (is_p(peek(), "{")) {
                reject_trailing_on_next_line(call_param_type(e, x->items.len));
                block_after_call = cur;
            }
            check_print_args(x);
            resolve_call(x);
            for (int k = 0; k < x->items.len; k++) /* an overloaded function passed by name (#41) */
                pick_overload(x->items.data[k], x->target && k < x->target->params.len
                                                    ? ((Var *)x->target->params.data[k])->type
                                                    : call_param_type(e, k));
            e = x;
        } else if (accept_p(".")) {
            Token *name = peek();
            /* cstr is a keyword, but also the .cstr property and possibly
               a field of a C struct */
            char *member = is_kw(name, "cstr") || is_converter(name) || is_kw(name, "case")
                               ? advance()->text
                               : expect_ident("a member or method name");
            /* a `(` on the next line starts the next statement (#35) */
            bool call = is_p(peek(), "(") && !line_ends_expression();
            if (call && is_converter(name) && !converter_is_field(e, member))
                error_at(name->pos, "'.%s' takes no arguments: read text in a base with %s(text, base)", member,
                         member);
            if (call && (!strcmp(member, "toString") || !strcmp(member, "fmt")) && !is_method_name(member)) {
                /* a field of that name that kelvinc can see, or one of a
                   struct it cannot see, is called as in C */
                Decl *record;
                char c = expr_class(e, &record);
                if (c != 'c' && c != 'u' && !(c == 's' && record_has_field(record, member)))
                    error_at(name->pos, "%s() " SHELVED_HINT, member);
            }
            Decl *tr = tagged_record(value_type(e)); /* an enum with values (#61) */
            if (tr && call && !strcmp(member, "is")) {
                /* v.is(name): is that the current case? */
                advance();
                Token *cn = peek();
                char *cname = expect_ident("a case name");
                if (!case_named(tr, cname, NULL))
                    error_at(cn->pos, "%s has no case '%s': the cases are %s", record_spelling(tr), cname, case_list(tr));
                expect_p(")");
                Expr *x = new_expr(E_METHOD, t->pos);
                x->a = e;
                x->text = cname;
                x->op = "case_is";
                x->target = tr;
                x->is_bool = true;
                e = x;
                continue;
            }
            {
                /* s.copy() of a struct, or an enum with values, that owns (#61) */
                Type *vt = value_type(e);
                Decl *cr;
                if (call && !strcmp(member, "copy") && vt && type_class(vt, &cr) == 's' && cr && is_owner(vt) &&
                    !method_named(e, member)) {
                    advance();
                    expect_p(")");
                    Expr *x = new_expr(E_METHOD, t->pos);
                    x->a = e;
                    x->text = "copy";
                    x->op = "record_copy";
                    x->type = unqualified(vt);
                    e = x;
                    continue;
                }
            }
            const char *okind = call ? builtin_owner(value_type(e)) : NULL;
            if (okind) {
                /* a Bytes method (#54): append, insert, remove, clear,
                   reserve, compact, copy, string; a String's (#55): append,
                   clear, reserve, compact, copy; on a place; those that
                   change it, not on a let or through a read-only borrow */
                static const struct { const char *name; int arity; bool changes; const char *of; } methods[] = {
                    {"append", 1, true, "bsa"}, {"insert", 2, true, "ba"}, {"remove", 2, true, "ba"},
                    {"clear", 0, true, "bsa"}, {"reserve", 1, true, "bsa"}, {"compact", 0, true, "bsa"},
                    {"copy", 0, false, "bsad"}, {"string", 0, false, "b"}, {"pop", 0, true, "a"},
                    {"has", 1, false, "d"}, {"find", 1, false, "d"}, {"get", 2, false, "d"},
                    {"remove", 1, true, "d"}, {"clear", 0, true, "d"}, {"reserve", 1, true, "d"}};
                int which = -1;
                for (size_t k = 0; k < sizeof methods / sizeof methods[0]; k++)
                    if (!strcmp(member, methods[k].name) && strchr(methods[k].of, okind[0]))
                        which = (int)k;
                if (which < 0)
                    error_at(name->pos, okind[0] == 'b'
                                            ? "a Bytes has no method '%s': append, insert, remove, clear, reserve, "
                                              "compact, copy and string, and the properties count, capacity, at, cstr "
                                              "and isUTF8"
                                        : okind[0] == 's'
                                            ? "a String has no method '%s': append, clear, reserve, compact and copy, "
                                              "and the properties count, bytes and cstr"
                                        : okind[0] == 'd'
                                            ? "a Dictionary has no method '%s': has, find, get, remove, clear, reserve "
                                              "and copy, and the property count"
                                            : "an Array has no method '%s': append, insert, remove, pop, clear, "
                                              "reserve, compact and copy, and the properties count, capacity and at",
                             member);
                if (!owner_place(e))
                    error_at(name->pos, "'.%s' of a %s that an expression gives: bind it to a variable first", member,
                             okind[0] == 'b' ? "Bytes" : okind[0] == 's' ? "String" : okind[0] == 'd' ? "Dictionary" : "Array");
                if (methods[which].changes && let_target(e))
                    error_at(name->pos, "'%s' is a let and cannot change; declare it with var", let_target(e));
                Type *through = e->kind == E_DEREF ? value_type(e->a) : NULL;
                if (methods[which].changes && through && through->kind == T_PTR && through->elem->is_const)
                    error_at(name->pos, "'.%s' through a read-only borrow: a String's bytes change only as a String",
                             member);
                advance();
                Expr *x = new_expr(E_METHOD, name->pos);
                x->a = e;
                x->text = member;
                x->op = (char *)okind;
                x->type = value_type(e); /* an Array's own type names its C functions (#57) */
                bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
                brace_ends_condition = brace_in_for = false;
                while (!is_p(peek(), ")")) {
                    list_push(&x->items, parse_assign());
                    if (!accept_p(","))
                        break;
                }
                brace_ends_condition = saved_brace;
                brace_in_for = saved_for;
                expect_p(")");
                if (x->items.len != methods[which].arity)
                    error_at(name->pos, "'.%s' takes %d argument%s", member, methods[which].arity,
                             methods[which].arity == 1 ? "" : "s");
                Expr *given = which == 0 ? x->items.data[0] : which == 1 ? x->items.data[1] : NULL;
                if (given)
                    check_appended(given, okind, member);
                if (given && which == 0 && okind[0] == 'a')
                    x->text = (char *)array_append_kind(given, x->type);
                if (okind[0] == 'd' && (!strcmp(member, "has") || !strcmp(member, "find") || !strcmp(member, "get") ||
                                        !strcmp(member, "remove"))) {
                    x->items.data[0] = dict_key(x->items.data[0], x->type); /* the key, by its kind (#65) */
                    x->is_bool = !strcmp(member, "has") || !strcmp(member, "remove");
                    if (!strcmp(member, "get") && is_owner(x->type->elem))
                        error_at(name->pos, "'.get' copies the value, and %s owns: borrow it with '.find(k)', a %s^ "
                                            "or nullptr",
                                 kelvin_type(x->type->elem), kelvin_type(x->type->elem));
                    if (!strcmp(member, "get")) {
                        Expr *dv = x->items.data[1];
                        reject_record_mismatch(dv, x->type->elem, dv->pos);
                    }
                }
                e = x;
                continue;
            }
            if (call && is_method_name(member)) {
                /* v.method(args) */
                advance();
                bool saved = ident_annotation_ok;
                bool saved_brace = brace_ends_condition;
                ident_annotation_ok = true;
                brace_ends_condition = false;
                Expr *x = new_expr(E_METHOD, name->pos);
                x->a = e;
                x->text = member;
                Decl *m = method_named(e, member);
                int arity = m && !m->variadic ? m->params.len : -1;
                while (!is_p(peek(), ")")) {
                    int k = x->items.len;
                    list_push(&x->items,
                              is_p(peek(), "{")
                                  ? anon_arg(m && k < m->params.len ? ((Var *)m->params.data[k])->type : NULL, arity, k, x,
                                             false)
                                  : parse_assign());
                    if (!accept_p(","))
                        break;
                }
                ident_annotation_ok = saved;
                brace_ends_condition = saved_brace;
                expect_p(")");
                if (is_p(peek(), "{") && !brace_ends_condition && !line_starts_statement()) {
                    int k = x->items.len;
                    list_push(&x->items,
                              anon_arg(m && k < m->params.len ? ((Var *)m->params.data[k])->type : NULL, arity, k, x,
                                       true));
                    if (at_statement_level())
                        trailing_end = cur;
                } else if (is_p(peek(), "{") && brace_ends_condition) {
                    body_after_call = cur;
                } else if (is_p(peek(), "{")) {
                    int k = x->items.len;
                    reject_trailing_on_next_line(m && k < m->params.len ? ((Var *)m->params.data[k])->type : NULL);
                    block_after_call = cur;
                }
                e = x;
                continue;
            }
            if (tr && !call && !strcmp(member, "case")) { /* v.case: the tag, a u8 (#61) */
                Expr *x = new_expr(E_PROPERTY, t->pos);
                x->a = e;
                x->text = "case";
                x->op = "tagged";
                e = x;
                continue;
            }
            if (!call) {
                Expr *x = property(e, name, member);
                if (x) {
                    e = x;
                    continue;
                }
            }
            if (tr && !call) {
                /* v.n: the value of case n, checked at run time (#61) */
                Var *c = case_named(tr, member, NULL);
                if (!c)
                    error_at(name->pos, "%s has no case '%s': the cases are %s", record_spelling(tr), member, case_list(tr));
                if (!c->type)
                    error_at(name->pos, "case '%s' of %s carries no value: test it with '.is(%s)', or set it with {.%s}",
                             member, record_spelling(tr), member, member);
                Expr *x = new_expr(E_FIELD, t->pos);
                x->a = e;
                x->text = member;
                x->op = "case";
                x->type = c->type;
                x->target = tr;
                e = x;
                continue;
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
            return e; /* p++ is a statement (#51): parse_assign takes it */
        } else if (is_p(t, "->")) {
            error_at(t->pos, "write 'p^.member' instead of 'p->member'");
        } else {
            return e;
        }
    }
}

static Type *value_type(Expr *e);

static bool is_comparison(const char *op);

/* the kind of number of type t, as C's arithmetic makes it: "i64" (any
   integer up to 64 bits, a bool), "i128" (also an enum, which gcc may
   make one) or "f64" (f32 or f64); NULL for anything else */
static const char *number_kind(Type *t) {
    if (!t || t->kind != T_BASE)
        return NULL;
    static const char *ints[] = {"i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", "bool", NULL};
    for (int i = 0; ints[i]; i++)
        if (!strcmp(t->name, ints[i]))
            return "i64";
    if (!strncmp(t->name, "enum ", 5))
        return "i128";
    if (!strcmp(t->name, "i128") || !strcmp(t->name, "u128"))
        return "i128";
    if (!strcmp(t->name, "f32") || !strcmp(t->name, "f64"))
        return "f64";
    return NULL;
}

/* A type of the same longest text as a template's value (#39): the type
   kelvinc sees, or for arithmetic on numbers whose kinds it sees, i64
   (any integer up to 64 bits), i128 or f64 (f32 and f64); bool for
   comparisons, ! and the logic operators. NULL otherwise: C's own
   functions, macros and typedefs, pointer arithmetic */
static Type *shown_type(Expr *e) {
    Type *t = e->kind == E_TERNARY ? NULL : value_type(e); /* C promotes the arms of ?: */
    if (t)
        return t->kind == T_TYPEOF ? NULL : t;
    const char *kind = NULL;
    switch (e->kind) {
    case E_LITERAL: {
        const char *s = e->text;
        if (!strcmp(s, "true") || !strcmp(s, "false"))
            kind = "bool";
        else if (s[0] == '\'')
            kind = "i64";
        else if ((s[0] >= '0' && s[0] <= '9') || s[0] == '.') {
            bool hex = s[0] == '0' && (s[1] == 'x' || s[1] == 'X');
            bool flt = strchr(s, '.') || (!hex && strpbrk(s, "eE")) || (hex && strpbrk(s, "pP"));
            kind = flt ? "f64" : "i64";
        }
        break;
    }
    case E_TERNARY:   /* C converts both arms of c ? a : b, as it does a + b */
    case E_BINARY: {
        if (e->kind == E_BINARY && (is_comparison(e->op) || !strcmp(e->op, "&&") || !strcmp(e->op, "||"))) {
            kind = "bool";
            break;
        }
        if (e->kind == E_BINARY && !strcmp(e->op, ","))
            return shown_type(e->b);
        Type *a = shown_type(e->kind == E_TERNARY ? e->b : e->a), *b = shown_type(e->kind == E_TERNARY ? e->c : e->b);
        kind = "i64";
        for (int i = 0; i < 2 && kind; i++) {
            const char *k = number_kind(i ? b : a);
            if (!k)
                return NULL;
            if (!strcmp(k, "f64") || (!strcmp(k, "i128") && strcmp(kind, "f64")))
                kind = k;
        }
        break;
    }
    case E_PREFIX:
        if (!strcmp(e->op, "!"))
            kind = "bool";
        else if (!strcmp(e->op, "-") || !strcmp(e->op, "+") || !strcmp(e->op, "~")) {
            /* -x of a u8 is C's int, and may be -255 */
            Type *a = shown_type(e->a);
            kind = number_kind(a);
            if (kind && !strcmp(kind, "f64"))
                return a;
        }
        break;
    case E_SIZEOF_TYPE:
    case E_SIZEOF_EXPR:
        kind = "u64";
        break;
    default:
        break;
    }
    return kind ? base_type(kind, e->pos) : NULL;
}

/* set while parsing a static local's initializer, which C needs constant */
static bool static_init;

/* `a${x}b` (#39): the template's literal parts and its values in turn.
   A value is any expression, shown as print shows it; a struct kelvinc
   sees shows its .cstr text. The text is made at run time, in storage of
   the enclosing block, so a global cannot be initialized with one. */
static Expr *parse_template(void) {
    Token *head = advance();
    if (!parsing_fn || static_init)
        error_at(head->pos, "a template literal with ${...} is made at run time, and a %s initializer must be "
                            "constant: make it in a function",
                 parsing_fn ? "static's" : "global's");
    Expr *e = new_expr(E_TEMPLATE, head->pos);
    Token *part = head;
    for (;;) {
        Expr *lit = new_expr(E_STRING, part->pos);
        list_push(&lit->items, part->text);
        list_push(&e->items, lit);
        if (part->kind == TK_TPL_TAIL)
            return e;
        bool saved_brace = brace_ends_condition, saved_for = brace_in_for, saved_annotation = ident_annotation_ok;
        brace_ends_condition = brace_in_for = false;
        ident_annotation_ok = true;
        if (peek()->kind == TK_TPL_MIDDLE || peek()->kind == TK_TPL_TAIL)
            error_at(peek()->pos, "${} is empty: write an expression in it, as in ${x}");
        Expr *v = parse_expr();
        brace_ends_condition = saved_brace;
        brace_in_for = saved_for;
        ident_annotation_ok = saved_annotation;
        Type *vt = value_type(v);
        if ((vt && vt->kind == T_FUNC) || is_function_designator(v))
            error_at(v->pos, "a template cannot show a function: a function has no text");
        Decl *record;
        if (expr_class(v, &record) == 's')
            v = property(v, &(Token){.kind = TK_IDENT, .pos = v->pos, .text = "cstr"}, "cstr");
        v->shown = shown_type(v);
        if (is_array_owner(value_type(v)) || is_dict_owner(value_type(v)))
            error_at(v->pos, "%s has no text yet: show its %s", is_dict_owner(value_type(v)) ? "a Dictionary" : "an Array",
                     is_dict_owner(value_type(v)) ? "entries" : "elements");
        list_push(&e->items, v);
        part = peek();
        if (part->kind != TK_TPL_MIDDLE && part->kind != TK_TPL_TAIL)
            error_at(part->pos, "expected '}' to end ${...} in the template literal, found %s", desc(part));
        advance();
    }
}

/* Does [T](n), an array of n zero-filled elements (#49), start at i? */
static bool zero_array_ahead(int i) {
    if (!is_p(&toks[i], "["))
        return false;
    int e = type_shape_end(i + 1);
    return e >= 0 && is_p(&toks[e], "]") && is_p(&toks[e + 1], "(");
}

static Expr *parse_primary(void) {
    Token *t = peek();
    if (zero_array_ahead(cur)) {
        Expr *e = new_expr(E_COMPOUND, t->pos);
        e->type = parse_type_in(TYPE_DECL);
        if (!e->type->size)
            error_at(t->pos, "'[T](n)' makes an array of n zero-filled elements: write the count");
        return e; /* a NULL initializer: zero-filled */
    }
    if (t->kind == TK_IDENT && !strcmp(t->text, "_Pragma") && !pragma_statement)
        error_at(t->pos, "_Pragma(\"...\") is only allowed as a statement of its own");
    if (t->kind == TK_PUNCT && !strcmp(t->text, "$") && peek2()->kind == TK_TPL_HEAD) {
        /* $`a${x}b` (#67): a String built on the heap from the parts and the
           values' text, with no bound; each value is appended as text, a
           String's by reference, a uchr as its codepoint */
        advance();
        Expr *e = parse_template();
        e->op = "string";
        for (int i = 1; i < e->items.len; i += 2) {
            Expr *v = e->items.data[i];
            Type *vt = value_type(v);
            Expr *w = new_expr(E_CAST, v->pos);
            w->a = v;
            if (is_string(vt) || is_bytes(vt)) {
                if (!owner_place(v))
                    error_at(v->pos, "a %s that an expression gives in a template, which nothing would free: bind it "
                                     "to a variable first",
                             is_string(vt) ? "String" : "Bytes");
                if (is_bytes(vt))
                    w->a = property(v, &(Token){.kind = TK_IDENT, .pos = v->pos, .text = "cstr"}, "cstr");
                w->op = is_string(vt) ? "tplstr_ref" : "tplstr_text";
            } else if (is_uchr(vt)) {
                w->op = "tplstr_uchr";
            } else if (v->kind == E_STRING || v->kind == E_TEMPLATE || is_text_expr(v)) {
                w->op = "tplstr_text";
            } else {
                w->a = property(v, &(Token){.kind = TK_IDENT, .pos = v->pos, .text = "cstr"}, "cstr");
                w->op = "tplstr_text";
            }
            e->items.data[i] = w;
        }
        return e;
    }
    if (t->kind == TK_PUNCT && !strcmp(t->text, "$") && peek2()->kind == TK_STRING) {
        /* $"text" is String("text") (#62) */
        advance();
        Expr *e = new_expr(E_CALL, t->pos);
        e->a = new_expr(E_IDENT, t->pos);
        e->a->text = "String";
        e->op = "string";
        list_push(&e->items, parse_primary());
        return e;
    }
    if (t->kind == TK_PUNCT && !strcmp(t->text, "$") && is_p(peek2(), "[") &&
        !(anon_start >= 0 && !is_p(peek_at(2), "]") && is_p(peek_at(3), "]"))) {
        /* $[a, b, c] is Array([a, b, c]) (#62); in an anonymous function,
           $[k] of one token is still its parameter k */
        advance();
        return array_of_list(t, NULL);
    }
    if (t->kind == TK_PUNCT && t->text[0] == '$')
        return parse_dollar();
    if (t->kind == TK_IDENT && anon_start >= 0) {
        /* a local of the function around an anonymous function (#32) */
        int i = binding_index(t->text);
        int locals = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
        if (i >= locals && i < anon_start)
            error_at(t->pos, "an anonymous function cannot use '%s' of the function around it: C has no "
                             "closures, so pass it as an argument, or make it a global",
                     t->text);
    }
    if (t->kind == TK_IDENT && is_p(peek2(), ".") && peek_at(2)->kind == TK_IDENT && binding_index(t->text) < 0) {
        /* T.n(x) and T.none make a value of an enum with values (#61) */
        Decl *r = record_named(t->text);
        int k;
        Var *c = r && r->tagged ? case_named(r, peek_at(2)->text, &k) : NULL;
        if (c) {
            advance();
            advance();
            Token *cn = advance();
            Expr *e = new_expr(E_CALL, t->pos);
            e->a = new_expr(E_IDENT, t->pos);
            e->a->text = t->text;
            e->op = "case_make";
            e->text = c->name;
            e->target = r;
            e->type = base_type(tag_type_name(r), t->pos);
            if (c->type) {
                if (!is_p(peek(), "("))
                    error_at(cn->pos, "case '%s' of %s carries a value: write %s.%s(value)", c->name, r->name, r->name, c->name);
                advance();
                bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
                brace_ends_condition = brace_in_for = false;
                Expr *v = case_value(c->type);
                brace_ends_condition = saved_brace;
                brace_in_for = saved_for;
                expect_p(")");
                reject_record_mismatch(v, c->type, v->pos);
                move_argument(v, c->type, strfmt("case '%s'", c->name)); /* given by value, an owner moves (O5) */
                list_push(&e->items, v);
            } else if (is_p(peek(), "(")) {
                error_at(peek()->pos, "case '%s' of %s carries no value: write %s.%s", c->name, r->name, r->name, c->name);
            }
            return e;
        }
    }
    if (t->kind == TK_IDENT || t->kind == TK_NUMBER || t->kind == TK_CHAR || is_kw(t, "true") ||
        is_kw(t, "false")) {
        advance();
        Expr *e = new_expr(t->kind == TK_IDENT ? E_IDENT : E_LITERAL, t->pos);
        e->text = t->text;
        /* an owner moved out is dead until assigned anew (#54) */
        if (t->kind == TK_IDENT && is_moved(t->text) && !is_p(peek(), "="))
            error_at(t->pos, "'%s' was moved out and holds nothing now: assign it anew before using it", t->text);
        /* a Kelvin function's name, which overloads may share (#41) */
        if (t->kind == TK_IDENT && !lookup_type(t->text) && function_named(t->text)) {
            List cands = overloads_of(t->text, NULL);
            if (cands.len == 1)
                e->target = cands.data[0];
            else
                e->cands = cands;
        }
        return e;
    }
    if (t->kind == TK_TPL_HEAD)
        return parse_template();
    if (t->kind == TK_STRING) {
        Expr *e = new_expr(E_STRING, t->pos);
        while (peek()->kind == TK_STRING)
            list_push(&e->items, advance()->text);
        return e;
    }
    reject_c_int_name(t);
    if (is_kw(t, "Dictionary") && is_p(peek2(), "<")) {
        /* Dictionary<K, V>(), Dictionary<K, V>([k: v, ...]), Dictionary<K, V>(&other) (#65) */
        advance();
        Type *dt = parse_dict_types(t);
        if (!is_p(peek(), "("))
            error_at(peek()->pos, "%s is a type: make one with %s(), or write it after ':'", kelvin_type(dt),
                     kelvin_type(dt));
        advance();
        bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
        brace_ends_condition = brace_in_for = false;
        Expr *e;
        if (is_p(peek(), "[")) {
            e = dict_of_list(t, dt, NULL, NULL);
        } else {
            e = new_expr(E_CALL, t->pos);
            e->a = new_expr(E_IDENT, t->pos);
            e->a->text = "Dictionary";
            e->op = "dict";
            e->text = "";
            e->type = dt;
            if (!is_p(peek(), ")")) {
                Expr *x = parse_assign();
                Type *xt = value_type(x);
                if (!(xt && xt->kind == T_PTR && is_dict_owner(xt->elem) && !strcmp(xt->elem->name, dt->name)))
                    error_at(x->pos, "%s takes nothing, the entries in [k: v, ...], or a borrow of another, '&d'",
                             kelvin_type(dt));
                e->text = "copy";
                list_push(&e->items, x);
            }
        }
        brace_ends_condition = saved_brace;
        brace_in_for = saved_for;
        expect_p(")");
        return e;
    }
    if (is_kw(t, "Array") && (is_p(peek2(), "<") || is_p(peek2(), "("))) {
        /* Array<T>(), Array<T>(n) of n zero elements, Array<T>(a) of a
           fixed array of T, Array<T>(&other) a copy (#57); Array<T>([...])
           of the elements written, and Array([...]), Array(a) and
           Array(&other), with T inferred from the argument (#58) */
        advance();
        Type *at = is_p(peek(), "<") ? array_type(t, parse_array_elem()) : NULL;
        if (!is_p(peek(), "("))
            error_at(peek()->pos, "Array<%s> is a type: make one with Array<%s>(), or write it after ':'",
                     kelvin_type(at->elem), kelvin_type(at->elem));
        advance();
        Expr *e = new_expr(E_CALL, t->pos);
        e->a = new_expr(E_IDENT, t->pos);
        e->a->text = "Array";
        e->op = "array";
        e->type = at;
        bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
        brace_ends_condition = brace_in_for = false;
        if (is_p(peek(), "[")) { /* the elements (#58) */
            e = array_of_list(t, at);
            brace_ends_condition = saved_brace;
            brace_in_for = saved_for;
            if (!is_p(peek(), ")"))
                error_at(peek()->pos, "Array([...]) takes the elements alone: expected ')'");
            advance();
            return e;
        }
        while (!is_p(peek(), ")")) {
            list_push(&e->items, parse_assign());
            if (!accept_p(","))
                break;
        }
        brace_ends_condition = saved_brace;
        brace_in_for = saved_for;
        expect_p(")");
        if (e->items.len > 1)
            error_at(t->pos, "Array%s takes nothing, a count, the elements in [...], a fixed array, or a borrow of "
                             "an Array",
                     at ? "<T>" : "");
        Expr *x = e->items.len ? e->items.data[0] : NULL;
        if (!at) {
            Type *xt = x ? value_type(x) : NULL;
            if (xt && xt->kind == T_ARRAY && xt->elem) {
                check_array_elem(xt->elem);
                at = e->type = array_type(t, xt->elem);
            } else if (xt && xt->kind == T_PTR && is_array_owner(xt->elem)) {
                at = e->type = xt->elem;
            } else {
                error_at(t->pos, "Array(%s) has no element type: write Array<T>(%s), or the elements, Array([...])",
                         x ? "x" : "", x ? "x" : "");
            }
        }
        if (x) {
            Type *xt = value_type(x);
            if (owner_place(x))
                error_at(x->pos, "Array<T>(a) would copy an owner: write a.copy(), or Array<T>(&a)");
            e->text = xt && xt->kind == T_ARRAY ? "fixed" : xt && xt->kind == T_PTR ? "copy" : "zeros";
            if (xt && xt->kind == T_ARRAY && !xt->size)
                error_at(x->pos, "the fixed array's count is not known here");
        }
        return e;
    }
    if ((is_kw(t, "Bytes") || is_kw(t, "String")) && is_p(peek2(), "(")) {
        /* Bytes(), Bytes(n), Bytes(text), Bytes(&b), Bytes(p, n) (#54);
           String(), String(text), String(&b) of a Bytes, validated (#55) */
        bool string = is_kw(t, "String");
        advance();
        advance();
        Expr *e = new_expr(E_CALL, t->pos);
        e->a = new_expr(E_IDENT, t->pos);
        e->a->text = t->text;
        e->op = string ? "string" : "bytes";
        bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
        brace_ends_condition = brace_in_for = false;
        while (!is_p(peek(), ")")) {
            list_push(&e->items, parse_assign());
            if (!accept_p(","))
                break;
        }
        brace_ends_condition = saved_brace;
        brace_in_for = saved_for;
        expect_p(")");
        if (e->items.len > (string ? 1 : 2))
            error_at(t->pos, string ? "String takes nothing, text, or a borrow of a Bytes, '&b'"
                                    : "Bytes takes nothing, a count, text, a borrow of a Bytes, or bytes and their count");
        if (e->items.len == 1 && owner_place(e->items.data[0]))
            error_at(t->pos, "%s(x) would copy an owner: write x.copy(), %s", t->text,
                     string ? "b.string() of a Bytes, or String(&b)" : "or Bytes(&b)");
        return e;
    }
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
        advance();
        bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
        brace_ends_condition = brace_in_for = false;
        Expr *v = parse_assign(), *base = NULL;
        if (accept_p(","))
            base = parse_assign(); /* i32("755", 8) (#36) */
        brace_ends_condition = saved_brace;
        brace_in_for = saved_for;
        if (is_p(peek(), ","))
            error_at(peek()->pos, "a converter takes one value, and an integer type a base for text after it: "
                                  "%s(v) or %s(text, base)",
                     t->text, t->text);
        expect_p(")");
        return convert(t, t->text, v, base);
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
        /* in `for x in (i32[3]){1, 2, 3} {`, an array's or a pointer's
           type cannot be a parenthesized name, as in `for c in (s) {` */
        /* (v.type){...} is a compound literal also where .type could be a
           field, since a field is never followed by `{` (#34); in a for
           head, it must be an array's or a pointer's type */
        int dot = typeof_at(cur + 1);
        bool typeof_paren = dot >= 0 && is_p(&toks[type_suffix_end(dot + 2)], ")");
        Type *chain = typeof_paren ? chain_type(cur + 1, dot) : NULL;
        /* on the next line at the top level of a statement, `{` starts a
           block (#35) */
        bool next_line = after && line_break(after - 1, after) && at_statement_level();
        bool compound = after && is_p(after, "{") && !next_line && (paren_holds_type(cur) || typeof_paren) &&
                        (brace_is_compound((int)(after - toks)) ||
                         (brace_in_for && (is_p(after - 2, "]") || is_p(after - 2, "^"))) ||
                         (brace_in_for && chain && (chain->kind == T_ARRAY || chain->kind == T_PTR)) ||
                         (typeof_paren && !brace_ends_condition));
        /* ([i32])[1, 2, 3], an array's compound literal (#48, #49): the type
           starts with `[`, or is a v.type kelvinc sees as an array, or is
           C-order (i32[3]) for the hint; (p)[0] and (m[1])[0] index */
        compound = compound || (after && is_p(after, "[") &&
                                ((paren_holds_type(cur) &&
                                  (is_p(peek2(), "[") || (is_p(after - 2, "]") && peek2()->kind != TK_IDENT))) ||
                                 (typeof_paren && chain && chain->kind == T_ARRAY)));
        Token *inner = peek2();
        bool converter_call = is_converter(inner) && is_p(peek_at(2), "(");
        if (!compound && is_kw(inner, "void") && is_p(peek_at(2), ")"))
            error_at(t->pos, "C casts are not Kelvin: to discard a value, write it as a statement of its own");
        if (kelvin_for_c_word(inner)) {
            if (compound)
                reject_c_int_name(inner);
            error_at(t->pos, CAST_HINT "; '%s' is not a Kelvin type, use %s", inner->text, kelvin_for_c_word(inner));
        }
        if (compound && !converter_call &&
            (starts_type(inner) || inner->kind == TK_IDENT || typeof_paren || is_p(inner, "{") ||
             is_p(inner, "$"))) { /* ({x:f64}){...} (#59), ($[i64]){...} (#64) */
            advance();
            Type *type = parse_type_in(TYPE_DECL);
            expect_p(")");
            Expr *e = new_expr(E_COMPOUND, t->pos);
            e->type = type;
            e->a = parse_initializer_for(type);
            count_items(type, e->a);
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
        int tdot = typeof_at(cur + 1);
        if (tdot >= 0 && is_p(&toks[type_suffix_end(tdot + 2)], ")") && !starts_operand(&toks[type_suffix_end(tdot + 2) + 1]) &&
            paren_type_ahead(false))
            error_at(t->pos, "'.type' is a type, not a value: use it where a type goes, as in 'var w:v.type' or "
                             "'x as v.type'");
        if (paren_type_ahead(false)) {
            /* (T)v is C's cast, not Kelvin's; (T) before a `{` on the next
               line was a compound literal before #35 */
            if (next_line && is_p(after, "{"))
                error_at(after->pos, "a compound literal's '{' starts on the line of its '(type)': on the next line, "
                                     "'{' starts a block");
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
        /* `(x) y` is never Kelvin; it is a C cast to a typedef, e.g.
           (size_t)n, unless y starts the next statement on a new line (#35) */
        Token *n = peek();
        if (!line_starts_statement() && (n->kind == TK_IDENT || n->kind == TK_NUMBER || n->kind == TK_CHAR || n->kind == TK_STRING ||
            n->kind == TK_TPL_HEAD ||
            (n->kind == TK_PUNCT && n->text[0] == '$') || is_p(n, "!") || is_kw(n, "sizeof") || is_kw(n, "true") || is_kw(n, "false") || is_kw(n, "nullptr") ||
            is_converter(n) ||
            ((is_p(n, "++") || is_p(n, "--")) &&
             (peek2()->kind == TK_IDENT || peek2()->kind == TK_NUMBER || peek2()->kind == TK_CHAR))))
            error_at(t->pos, CAST_HINT);
        return e;
    }
    if (is_kw(t, "cstr") && is_p(peek2(), "("))
        error_at(t->pos, "cstr is u8^: convert with 'v as cstr'");
    if (is_p(t, "{")) {
        if (cur == fn_at) { /* an argument, an initializer, a value assigned or returned (#32) */
            fn_at = -1;
            return parse_anon_fn(fn_type);
        }
        if (signature_ahead(cur))
            return parse_anon_fn(NULL); /* c ? { (a:i64) in ... } : ... (#32) */
        error_at(t->pos, "a list is not a value here: write a compound literal, as in '(point){1, 2}' or "
                         "'([i32])[1, 2, 3]'; an anonymous function here writes its parameters, as in "
                         "'{ (a:i64):i64 in a + 1 }'");
    }
    if (is_p(t, "["))
        error_at(t->pos, "an array is not a value here: write a compound literal, as in '([i32])[1, 2, 3]' (#48)");
    error_at(t->pos, "expected an expression, found %s", desc(t));
}

/* Kelvin has no ++ and -- (#26) */
_Noreturn static void reject_step(Token *t) {
    error_at(t->pos, "Kelvin has no prefix '%s': a pointer steps with 'p%s' as a statement (#51), and a number with "
                     "'x %s= 1'",
             t->text, t->text, t->text[0] == '+' ? "+" : "-");
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
        return !strcmp(e->op, "-") ? resolve_operator(e, "-", e->a, NULL) : e; /* -z (#42) */
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
            if ((is_p(peek(), "{") && brace_is_compound(cur) && !line_starts_statement()) ||
                (is_p(peek(), "[") && type->kind == T_ARRAY)) {
                /* sizeof (T){...} or (T[])[...] is the size of a compound literal */
                Expr *c = new_expr(E_COMPOUND, open->pos);
                c->type = type;
                c->a = parse_initializer_for(type);
                count_items(type, c->a);
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
        if (is_function_designator(e->a)) {
            /* a function's name is a function value (#31): its size is a
               pointer's, not C's sizeof of a function */
            Expr *a = new_expr(E_PREFIX, e->a->pos);
            a->op = "&";
            a->a = e->a;
            e->a = a;
        }
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
    if (is_converter(n) && is_p(peek_at(2), "(") && !(line_break(n, peek_at(2)) && at_statement_level()))
        return false; /* c ? x : u8(y), but not 7:i64 before a `(` line (#35) */
    if (is_base_word(n) || is_qualifier(n) || kelvin_for_c_word(n) || is_kw(n, "struct") || is_kw(n, "union") ||
        is_kw(n, "enum") || is_kw(n, "String"))
        return true;
    if (n->kind == TK_PUNCT && n->text[0] == '$' && typeof_at(cur + 1) >= 0)
        return ident_annotation_ok; /* 5:$0.type (#34) */
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

static bool assigned_after(int j);

static Expr *parse_binary(int min_prec) {
    Expr *lhs = parse_cast();
    for (;;) {
        Token *t = peek();
        int prec = binary_prec(t);
        if (prec < min_prec)
            return lhs;
        /* `*p = 1` on a line of its own is C's dereference, not a product
           going on from the line above, which could not be assigned (#35) */
        if (is_p(t, "*") && newline_before() && at_statement_level() && !line_break(t, &toks[cur + 1]) &&
            toks[cur + 1].pos.col == t->pos.col + 1 && (toks[cur + 1].kind == TK_IDENT || is_p(&toks[cur + 1], "(")) &&
            assigned_after(cur + 1))
            error_at(t->pos, "dereference is a postfix '^' in Kelvin: write 'p^' instead of '*p'");
        advance();
        Expr *e = new_expr(E_BINARY, t->pos);
        e->op = t->text;
        e->a = lhs;
        e->b = parse_binary(prec + 1);
        if (!strcmp(e->op, "&&") || !strcmp(e->op, "||")) {
            require_bool(e->a);
            require_bool(e->b);
        }
        if ((!strcmp(e->op, "+") || !strcmp(e->op, "-")) &&
            ((is_cstr(value_type(e->a)) && !is_cstr(value_type(e->b))) ||
             (!strcmp(e->op, "+") && is_cstr(value_type(e->b)))))
            error_at(t->pos, "a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a "
                             "'var p:u8^ := s'");
        if (is_uchr(value_type(e->a)) || is_uchr(value_type(e->b))) {
            /* a uchr compares by its codepoint, with a uchr or a number
               (#56); it has no arithmetic */
            if (!is_comparison(e->op))
                error_at(t->pos, "a uchr has no operator '%s': its codepoint is 'c.utf32', a u32", e->op);
            if (is_uchr(value_type(e->a)))
                e->a = utf32_of(e->a);
            if (is_uchr(value_type(e->b)))
                e->b = utf32_of(e->b);
            e->is_bool = true;
            lhs = e;
            continue;
        }
        const char *ka = builtin_owner(value_type(e->a)), *kb = builtin_owner(value_type(e->b));
        if (ka || kb) {
            /* a Bytes or a String compares with == and != by its bytes
               (#54, #55), with another of its type, both places */
            const char *tn = (ka ? ka : kb)[0] == 'b'   ? "Bytes"
                             : (ka ? ka : kb)[0] == 's' ? "String"
                             : (ka ? ka : kb)[0] == 'd' ? "Dictionary"
                                                        : "Array";
            if (tn[0] == 'A' || tn[0] == 'D')
                error_at(t->pos, "%s has no operator '%s': compare its %s", tn[0] == 'A' ? "an Array" : "a Dictionary",
                         e->op, tn[0] == 'A' ? "elements" : "entries");
            if (strcmp(e->op, "==") && strcmp(e->op, "!="))
                error_at(t->pos, "a %s has no operator '%s': compare with == and !=, append with .append or +=", tn,
                         e->op);
            if (!ka || !kb || strcmp(ka, kb) || !owner_place(e->a) || !owner_place(e->b))
                error_at(t->pos, "a %s compares with another %s, both in variables", tn, tn);
            Expr *eq = new_expr(E_CALL, t->pos);
            eq->a = new_expr(E_IDENT, t->pos);
            eq->a->text = ka[0] == 'b' ? "kv_bytes_eq" : "kv_string_eq";
            eq->op = "c";
            Expr *pa = new_expr(E_PREFIX, t->pos), *pb = new_expr(E_PREFIX, t->pos);
            pa->op = pb->op = "&";
            pa->a = e->a;
            pb->a = e->b;
            list_push(&eq->items, pa);
            list_push(&eq->items, pb);
            eq->is_bool = true;
            if (!strcmp(e->op, "!=")) {
                Expr *not = new_expr(E_PREFIX, t->pos);
                not->op = "!";
                not->a = eq;
                not->is_bool = true;
                eq = not;
            }
            lhs = eq;
            continue;
        }
        lhs = overloadable_op(t) ? resolve_operator(e, e->op, e->a, e->b) : e; /* (#42) */
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
    /* c ? 'A' : ch, a uchr beside an integer: the integer becomes a uchr (#56) */
    Decl *r;
    if (is_uchr(value_type(e->b)) != is_uchr(value_type(e->c))) {
        Expr **other = is_uchr(value_type(e->b)) ? &e->c : &e->b;
        char cls = expr_class(*other, &r);
        if (cls == 'i' || ((*other)->kind == E_LITERAL && (*other)->text[0] == '\'')) {
            Expr *x = new_expr(E_PROPERTY, (*other)->pos);
            x->a = *other;
            x->text = "uchr";
            x->op = "to";
            *other = x;
        }
    }
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

/* while set, kelvin_type writes Kelvin tags by their bare names */
static bool bare_tags;

/* the Kelvin spelling of a type, for messages */
static char *kelvin_type(Type *t) {
    const char *q = t->is_const && t->is_volatile ? "const volatile" : t->is_const ? "const" : t->is_volatile ? "volatile" : "";
    switch (t->kind) {
    case T_BASE: {
        Decl *ar = anon_record_of(t); /* a struct with no tag, by its members (#59) */
        if (ar)
            return strfmt("%s%s%s", q, *q ? " " : "", ar->spelling);
        /* .typename (#34) spells a Kelvin tag by its bare name (#29) */
        const char *n = t->name;
        for (int k = 0; bare_tags && k < 3; k++) {
            const char *kw = k == 0 ? "struct " : k == 1 ? "union " : "enum ";
            if (!strncmp(n, kw, strlen(kw)) && record_named(n + strlen(kw)))
                n += strlen(kw);
        }
        return strfmt("%s%s%s", q, *q ? " " : "", n);
    }
    case T_TYPEOF:
        return strfmt("%s%s%s.type", q, *q ? " " : "", t->name);
    case T_PTR: /* a function type under ^ in parentheses, as its result takes the ^ */
        if (t->cstr) /* immutable text (#52) */
            return strfmt("cstr%s%s", *q ? " " : "", q);
        return strfmt(t->elem->kind == T_FUNC ? "(%s)^%s%s" : "%s^%s%s", kelvin_type(t->elem), *q ? " " : "", q);
    case T_ARRAY: /* [T], or [T](N) with its count (#49) */
        return strfmt("[%s]%s%s%s", kelvin_type(t->elem),
                      !t->size ? "" : strfmt("(%s)", t->size->kind == E_LITERAL || t->size->kind == E_IDENT ? t->size->text : "..."),
                      *q ? " " : "", q);
    case T_FUNC: {
        Buf b = {0};
        buf_puts(&b, "(");
        for (int i = 0; i < t->params.len; i++)
            buf_printf(&b, "%s%s", i ? ", " : "", kelvin_type(t->params.data[i]));
        if (t->variadic)
            buf_puts(&b, ", ...");
        buf_puts(&b, ")");
        if (t->elem)
            buf_printf(&b, ":%s", kelvin_type(t->elem));
        return b.buf;
    }
    }
    return "?";
}

/* 1 for a reference (a pointer), 0 for a value, -1 when kelvinc cannot
   tell (a C typedef name, or an unknown type) */
static int ref_kind(Type *t) {
    if (!t)
        return -1;
    if (t->kind == T_PTR || t->kind == T_FUNC)
        return 1; /* a function is C's pointer to one (#31) */
    if (t->kind == T_ARRAY)
        return 0;
    if (t->kind == T_TYPEOF)
        return ref_kind(t->elem);
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
        if (is_bytes(t)) { /* b[i] (#54): a u8, const for a let */
            Type *u = base_type("u8", e->pos);
            u->is_const = let_target(e->a) != NULL;
            return u;
        }
        if (is_array_owner(t) || is_dict_owner(t)) { /* xs[i] (#57), d[k] (#65): a T, const for a let */
            Type *u = xcalloc(1, sizeof *u);
            *u = *t->elem;
            u->is_const = u->is_const || let_target(e->a) != NULL;
            return u;
        }
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
    if (t && t->kind == T_TYPEOF)
        return type_class(t->elem, record);
    if (!t)
        return 'u';
    if (t->kind != T_BASE || t->cname) /* an Array<T> is known (#57) */
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
   methods (the method of the receiver's type where kelvinc sees it,
   otherwise when every method of that name returns the same type), and
   p^, a[i] and fields of all these. NULL otherwise. */
/* Does e designate a function itself, a Kelvin function's name or an
   anonymous function, rather than a value of a function type? (#31) */
static bool is_function_designator(Expr *e) {
    return e->kind == E_FUNC || (e->kind == E_IDENT && !lookup_type(e->text) && function_named(e->text));
}

static Type *value_type(Expr *e);

/* v.type (#34), with the `.` of its .type at token dot: the type that
   kelvinc sees v has (a let's own const is not part of it), or else C's
   __typeof__(v) */
/* Does t have a .type that kelvinc cannot see and that names a local or
   a parameter? */
static bool typeof_names_local(Type *t) {
    if (!t)
        return false;
    switch (t->kind) {
    case T_TYPEOF:
        return t->size_local;
    case T_ARRAY:
    case T_PTR:
        return typeof_names_local(t->elem);
    case T_FUNC:
        for (int i = 0; i < t->params.len; i++)
            if (typeof_names_local(t->params.data[i]))
                return true;
        return typeof_names_local(t->elem);
    default:
        return false;
    }
}

/* Does t hold an expression that C would evaluate again where the type
   is written: a length that is not a number, or a .type kelvinc could
   not see? */
static bool type_has_expr(Type *t) {
    if (!t)
        return false;
    switch (t->kind) {
    case T_TYPEOF:
        return true;
    case T_ARRAY:
        return (t->size && t->size->kind != E_LITERAL) || type_has_expr(t->elem);
    case T_PTR:
        return type_has_expr(t->elem);
    case T_FUNC:
        for (int i = 0; i < t->params.len; i++)
            if (type_has_expr(t->params.data[i]))
                return true;
        return type_has_expr(t->elem);
    default:
        return false;
    }
}

static Type *parse_typeof(int dot) {
    Token *head = peek();
    Decl *tag = head->kind == TK_IDENT ? record_named(head->text) : NULL;
    if (tag && tag->has_body && !in_scope(head->text) && dot == cur + 1)
        error_at(head->pos, "'%s' is a type already: write '%s', not '%s.type'", head->text, head->text,
                 head->text);
    Buf text = {0};
    for (int i = cur; i < dot; i++)
        buf_puts(&text, toks[i].text);
    int saved_stop = postfix_stop;
    postfix_stop = dot;
    Expr *v = parse_postfix_ops(parse_primary());
    postfix_stop = saved_stop;
    if (cur != dot)
        error_at(peek()->pos, "expected '.type', as in 'var w:v.type'");
    advance();
    advance();
    Type *seen = value_type(v);
    /* A parameter whose declared type kelvinc cannot see may be an array,
       which C makes a pointer: C knows its type (jmp_buf) */
    Var *param = v->kind == E_IDENT ? param_named(v->text) : NULL;
    Decl *r;
    bool unseen_param = param && (param->type->kind == T_TYPEOF ||
                                  (param->type->kind == T_BASE && type_class(param->type, &r) == 'u'));
    Type *t = xcalloc(1, sizeof *t);
    if (seen && !type_has_expr(seen) && !unseen_param) {
        *t = *seen; /* a copy, which qualifiers and suffixes may change */
        t->pos = head->pos;
        if (t->kind == T_BASE && !strcmp(t->name, "any") && !is_p(peek(), "^"))
            error_at(head->pos, "'%s.type' is any, which exists only as 'any^', C's void *", text.buf);
        return t;
    }
    /* C's own __typeof__, which keeps what it saw: a variable length, the
       value a .type had, and a let's const. A function is a value. */
    if (is_function_designator(v)) {
        Expr *a = new_expr(E_PREFIX, v->pos);
        a->op = "&";
        a->a = v;
        v = a;
    }
    t->kind = T_TYPEOF;
    t->pos = head->pos;
    t->name = text.buf;
    t->of = v;
    t->elem = seen; /* for kelvinc's own checks */
    t->size_local = names_local(v);
    return t;
}

/* the function type of a function or an anonymous function (#31) */
static Type *fn_type_of(Decl *d) {
    Type *t = xcalloc(1, sizeof *t);
    t->kind = T_FUNC;
    t->pos = d->pos;
    for (int k = 0; k < d->params.len; k++) {
        /* a length that names a parameter is lost with the names: the
           array is the pointer C makes of it */
        Type *pt = ((Var *)d->params.data[k])->type;
        list_push(&t->params, pt->kind == T_ARRAY && pt->size_local ? param_type(pt) : pt);
    }
    t->elem = d->ret;
    t->variadic = d->variadic;
    return t;
}

static Type *value_type_of(Expr *e);

/* The type of e as far as kelvinc can see it, or NULL. A v.type that
   C writes as __typeof__(v) is the type kelvinc saw for v (#34). */
static Type *value_type(Expr *e) {
    Type *t = value_type_of(e);
    return t && t->kind == T_TYPEOF && t->elem ? t->elem : t;
}

static Type *value_type_of(Expr *e) {
    switch (e->kind) {
    case E_IDENT: { /* a Kelvin function's name is a function value (#31) */
        if (e->op && !strcmp(e->op, "c")) /* C's own function of the name (#41) */
            return NULL;
        Decl *f = lookup_type(e->text) ? NULL : function_named(e->text);
        if (f && (e->target || e->cands.len)) /* one overload, or several (#41) */
            return e->target ? fn_type_of(e->target) : NULL;
        return f ? fn_type_of(f) : type_through(e, value_type);
    }
    case E_CAST:
    case E_COMPOUND:
        return e->type;
    case E_CALL: {
        if (e->op && !strcmp(e->op, "bytes")) /* Bytes(...) (#54) */
            return base_type("Bytes", e->pos);
        if (e->op && !strcmp(e->op, "string")) /* String(...) (#55) */
            return base_type("String", e->pos);
        if (e->op && !strcmp(e->op, "case_make")) /* T.n(x) (#61) */
            return e->type;
        if (e->op && !strcmp(e->op, "dict")) /* Dictionary<K, V>(...) (#65) */
            return e->type;
        if (e->op && !strcmp(e->op, "array")) /* Array<T>(...) (#57) */
            return e->type;
        /* the overload chosen, or the result all that C may choose have,
           or C's own function's (unseen) (#41, #42) */
        if (e->target)
            return e->target->ret;
        if (e->op && !strcmp(e->op, "c"))
            return NULL;
        if (e->cands.len) {
            if (!((Decl *)e->cands.data[0])->op && reaches_c(&e->cands, e, 0))
                return NULL;
            Type *ret = ((Decl *)e->cands.data[0])->ret;
            for (int i = 1; i < e->cands.len && ret; i++) {
                Type *r = ((Decl *)e->cands.data[i])->ret;
                ret = r && !strcmp(kelvin_type(r), kelvin_type(ret)) ? ret : NULL;
            }
            return ret;
        }
        Decl *f = e->a->kind == E_IDENT ? function_named(e->a->text) : NULL;
        if (f)
            return f->ret;
        Type *t = value_type(e->a); /* a function value (#31) */
        return t && t->kind == T_FUNC ? t->elem : NULL;
    }
    case E_FUNC:
        return e->type;
    case E_TERNARY: { /* a choice between functions is a function (#31) */
        Type *b = value_type(e->b), *c = value_type(e->c);
        if (b && b->kind == T_FUNC)
            return b;
        if (c && c->kind == T_FUNC)
            return c;
        /* a choice between two values of one type kelvinc sees (#34) */
        return b && c && b->kind == T_BASE && c->kind == T_BASE && !strcmp(kelvin_type(b), kelvin_type(c)) ? b : NULL;
    }
    case E_METHOD: {
        if (e->op && !strcmp(e->op, "bytes")) /* a Bytes method (#54): copy gives a Bytes, string a String */
            return !strcmp(e->text, "copy") ? base_type("Bytes", e->pos)
                   : !strcmp(e->text, "string") ? base_type("String", e->pos) : NULL;
        if (e->op && !strcmp(e->op, "string")) /* a String method (#55): copy gives a String */
            return !strcmp(e->text, "copy") ? base_type("String", e->pos) : NULL;
        if (e->op && !strcmp(e->op, "case_is")) /* v.is(n) (#61) */
            return base_type("bool", e->pos);
        if (e->op && !strcmp(e->op, "case_set"))
            return NULL;
        if (e->op && !strcmp(e->op, "record_copy")) /* s.copy() of a struct that owns (#61) */
            return e->type;
        if (e->op && !strcmp(e->op, "dict")) { /* a Dictionary method (#65) */
            Type *dt = value_type(e->a);
            if (!strcmp(e->text, "has") || !strcmp(e->text, "remove"))
                return base_type("bool", e->pos);
            if (!strcmp(e->text, "copy"))
                return dt;
            if (!strcmp(e->text, "get"))
                return dt->elem;
            if (!strcmp(e->text, "find")) { /* V^, const for a let */
                Type *p = xcalloc(1, sizeof *p);
                p->kind = T_PTR;
                p->pos = e->pos;
                p->elem = xcalloc(1, sizeof *p->elem);
                *p->elem = *dt->elem;
                p->elem->is_const = p->elem->is_const || let_target(e->a) != NULL;
                return p;
            }
            return NULL;
        }
        if (e->op && !strcmp(e->op, "array")) { /* an Array method (#57): copy gives one, pop an element */
            Type *at = value_type(e->a);
            return !strcmp(e->text, "copy") ? at : !strcmp(e->text, "pop") ? at->elem : NULL;
        }
        Type *rt = value_type(e->a);
        Decl *m = rt && rt->kind == T_BASE ? method_named(e->a, e->text) : NULL;
        if (m) /* the method of the receiver's type */
            return m->ret;
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
    case E_TEMPLATE: /* its text is a cstr (#39, #52); $`...` a String (#67) */
        return e->op && !strcmp(e->op, "string") ? base_type("String", e->pos) : cstr_type(e->pos);
    case E_PROPERTY: { /* p.next and p.prev have p's type; a text is a cstr */
        if (e->op && !strcmp(e->op, "bytes") && !strcmp(e->text, "at")) { /* b.at (#54) */
            Type *p = xcalloc(1, sizeof *p);
            p->kind = T_PTR;
            p->pos = e->pos;
            p->elem = base_type("u8", e->pos);
            p->elem->is_const = let_target(e->a) != NULL;
            return p;
        }
        if (e->op && !strcmp(e->op, "uchr")) /* c.utf32 (#56) */
            return base_type("u32", e->pos);
        if (e->op && !strcmp(e->op, "tagged")) /* v.case, the tag (#61) */
            return base_type("u8", e->pos);
        if (e->op && !strcmp(e->op, "dict") && e->type) /* d.keys, d.values: Arrays (#66) */
            return e->type;
        if (e->op && !strcmp(e->op, "array") && !strcmp(e->text, "at")) { /* xs.at, a T^ (#57) */
            Type *p = xcalloc(1, sizeof *p);
            p->kind = T_PTR;
            p->pos = e->pos;
            p->elem = xcalloc(1, sizeof *p->elem);
            *p->elem = *value_type(e->a)->elem;
            p->elem->is_const = let_target(e->a) != NULL;
            return p;
        }
        if (e->op && !strcmp(e->op, "to")) /* n.uchr (#56) */
            return base_type("uchr", e->pos);
        if (e->op && !strcmp(e->op, "string") && !strcmp(e->text, "bytes")) { /* s.bytes, a read-only borrow (#55) */
            Type *p = xcalloc(1, sizeof *p);
            p->kind = T_PTR;
            p->pos = e->pos;
            p->elem = base_type("Bytes", e->pos);
            p->elem->is_const = true;
            return p;
        }
        if (!strcmp(e->text, "next") || !strcmp(e->text, "prev"))
            return value_type(e->a);
        if (strcmp(e->text, "cstr") && strcmp(e->text, "dec") && strcmp(e->text, "hex") && strcmp(e->text, "oct") &&
            strcmp(e->text, "bin") && strcmp(e->text, "typename"))
            return NULL; /* .size, .count and .addr are C's size_t and uintptr_t */
        return cstr_type(e->pos);
    }
    case E_PREFIX: { /* &x is a pointer to x's type */
        Type *t = !strcmp(e->op, "&") ? value_type(e->a) : NULL;
        if (!t)
            return NULL;
        if (e->a->kind == E_INDEX && is_cstr(value_type(e->a->a)))
            return cstr_type(e->pos); /* &s[i] is the rest of the text (#52) */
        if (t->kind == T_FUNC && is_function_designator(e->a))
            return t; /* &f is the function f, as in C */
        Type *p = xcalloc(1, sizeof *p);
        p->kind = T_PTR;
        p->pos = e->pos;
        p->elem = t;
        return p;
    }
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
        bool number = !strcmp(e->text, "size") || !strcmp(e->text, "addr");
        what = !strcmp(e->text, "size") ? "size_t" : number ? "uintptr_t" : "u8^";
        hint = number ? strfmt("x.%s != 0", e->text) : "x != nullptr";
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
        else if (t->kind == T_FUNC)
            hint = "f != nullptr";
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
    case E_PROPERTY: /* .size, .addr, .count, .capacity, .utf32, .codepoint and .case are integers */
        return (e->op && !strcmp(e->op, "tagged")) || !strcmp(e->text, "size") || !strcmp(e->text, "addr") || !strcmp(e->text, "count") ||
                       !strcmp(e->text, "capacity") || !strcmp(e->text, "utf32") || !strcmp(e->text, "codepoint")
                   ? 'i'
                   : 'n';
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

/* Is t text: u8^ or i8^ (cstr), or an array of u8 or i8? A volatile
   one is not: it converts as before, as C's volatile char * does */
static bool is_text_type(Type *t) {
    return t && (t->kind == T_PTR || t->kind == T_ARRAY) && t->elem && t->elem->kind == T_BASE &&
           !t->elem->is_volatile && (!strcmp(t->elem->name, "u8") || !strcmp(t->elem->name, "i8"));
}

/* Is e text kelvinc can see: a string, a text type, a text property
   (i64(n.hex, 16)), or a ?: of those (c ? argv[1] : "8")? */
static bool is_text_expr(Expr *e) {
    static const char *texts[] = {"dec", "hex", "oct", "bin", "cstr", "typename", NULL};
    if (e->kind == E_STRING || is_text_type(value_type(e)))
        return true;
    for (int i = 0; e->kind == E_PROPERTY && texts[i]; i++)
        if (!strcmp(e->text, texts[i]))
            return true;
    if (e->kind == E_TERNARY)
        return (is_text_expr(e->b) || (e->b->kind == E_LITERAL && !strcmp(e->b->text, "nullptr"))) &&
               (is_text_expr(e->c) || (e->c->kind == E_LITERAL && !strcmp(e->c->text, "nullptr")));
    return false;
}

/* Does kelvinc see that e is a number, or a bool: a literal, sizeof,
   arithmetic (+ and - only of numbers, as a pointer steps with them),
   a prefix operator, a comparison, or a ?: of numbers? */
static bool number_expr(Expr *e) {
    Decl *record;
    char c = expr_class(e, &record);
    if (c == 'i' || c == 'f' || seen_bool(e))
        return true;
    switch (e->kind) {
    case E_SIZEOF_TYPE:
    case E_SIZEOF_EXPR:
        return true;
    case E_PREFIX:
        return strcmp(e->op, "&") != 0;
    case E_BINARY:
        if (!strcmp(e->op, "+") || !strcmp(e->op, "-"))
            return number_expr(e->a) && number_expr(e->b);
        return strcmp(e->op, ",") ? binary_prec(&(Token){.kind = TK_PUNCT, .text = (char *)e->op}) > 0 : number_expr(e->b);
    case E_TERNARY:
        return number_expr(e->b) && number_expr(e->c);
    default:
        return false;
    }
}

/* Is e, a written base, outside 2 to 36: a literal of any radix, a
   negated one, or a float? */
static void check_base(Expr *base) {
    Expr *lit = base->kind == E_PREFIX && !strcmp(base->op, "-") ? base->a : base;
    Decl *record;
    if (expr_class(base, &record) == 'f')
        error_at(base->pos, "a base is an integer from 2 to 36");
    if (lit->kind != E_LITERAL || !isdigit((unsigned char)lit->text[0]))
        return;
    const char *t = lit->text;
    bool binary = t[0] == '0' && (t[1] == 'b' || t[1] == 'B');
    unsigned long long v = strtoull(binary ? t + 2 : t, NULL, binary ? 2 : 0);
    if (lit != base || v < 2 || v > 36)
        error_at(base->pos, "a base is 2 to 36, not %s%s", lit != base ? "-" : "", t);
}

/* T(v), T(text, base) and v.T (#36): v converted as C's cast converts
   it, or where v is text, the number read from it as C's strtol and
   strtod read it (op "text"); where kelvinc cannot see whether v is text,
   C's _Generic chooses (op "text?"). bool reads no text. */
static Expr *convert(Token *t, const char *name, Expr *v, Expr *base) {
    Expr *e = new_expr(E_CAST, t->pos);
    e->type = base_type(name, t->pos);
    e->paren = true;
    e->a = v;
    e->b = base;
    if (!strcmp(name, "uchr")) { /* uchr(n) of a number, uchr(text) its first codepoint (#56) */
        if (base)
            error_at(base->pos, "uchr(x) takes one value: a number, or text");
        if (is_uchr(value_type(v)))
            return v;
        e->op = "uchr";
        return e;
    }
    if (is_uchr(value_type(v))) /* i64(c) is i64(c.utf32) */
        e->a = v = utf32_of(v);
    bool text = is_text_expr(v);
    bool is_bool = !strcmp(name, "bool");
    bool floating = !strcmp(name, "f32") || !strcmp(name, "f64");
    if (is_bool && text && !is_text_type(value_type(v)))
        error_at(t->pos, "bool(...) reads no text, and this text is never nullptr, so it would always be true");
    if (base && (floating || is_bool))
        error_at(base->pos, "a base is for reading an integer from text; %s",
                 floating ? strfmt("%s(text) reads decimal, or C's hex floats as in \"0x1.8p1\"", name)
                          : "bool(...) takes one value");
    /* a pointer whose element kelvinc cannot see may be C's char text,
       as xmlChar^ and gchar^ are */
    Type *vt = value_type(v);
    Decl *record;
    bool unseen_elem = vt && (vt->kind == T_PTR || vt->kind == T_ARRAY) && vt->elem &&
                       type_class(vt->elem, &record) == 'u' && !vt->elem->is_volatile;
    char c = expr_class(v, &record);
    e->op = is_bool ? "converter"
            : text  ? "text"
            : (c == 'u' && !number_expr(v)) || unseen_elem ? "text?"
                                                           : "converter";
    if (base && !strcmp(e->op, "converter"))
        error_at(base->pos, "a base is for reading text, as in %s(\"755\", 8); %s converts a number", name, name);
    if (base)
        check_base(base);
    return e;
}

/* Does kelvinc see that e is a pointer or a function (#37): one of
   their types, a function's name, a string, nullptr, &x, a text property
   (u8^), a pointer stepped with + or -, or a ?: or comma of pointers? */
static bool pointer_expr(Expr *e) {
    static const char *texts[] = {"dec", "hex", "oct", "bin", "cstr", "typename", NULL};
    Type *t = value_type(e);
    if ((t && (t->kind == T_PTR || t->kind == T_FUNC)) || e->kind == E_STRING || e->kind == E_FUNC ||
        is_function_designator(e) || (e->kind == E_LITERAL && !strcmp(e->text, "nullptr")))
        return true;
    for (int i = 0; e->kind == E_PROPERTY && texts[i]; i++)
        if (!strcmp(e->text, texts[i]))
            return true;
    switch (e->kind) {
    case E_PREFIX:
        return !strcmp(e->op, "&");
    case E_BINARY:
        if (!strcmp(e->op, ","))
            return pointer_expr(e->b);
        return (!strcmp(e->op, "+") && ((pointer_expr(e->a) && number_expr(e->b)) || (number_expr(e->a) && pointer_expr(e->b)))) ||
               (!strcmp(e->op, "-") && pointer_expr(e->a) && number_expr(e->b));
    case E_TERNARY:
        return pointer_expr(e->b) && pointer_expr(e->c);
    default:
        return false;
    }
}

/* ---------- overloading (#41) and operators (#42) ---------- */

/* the names called as C's own functions, which a Kelvin function of the
   same name then overloads */
static List c_called;

/* the calls whose overload C's _Generic chooses (#41) */
static List dispatched;

static bool called_as_c(const char *name) {
    for (int i = 0; i < c_called.len; i++)
        if (!strcmp(c_called.data[i], name))
            return true;
    return false;
}

/* A type without its own qualifiers, as an argument's value has it */
static Type *unqualified(Type *t) {
    t = param_type(t);
    if (!t->is_const && !t->is_volatile)
        return t;
    Type *u = xcalloc(1, sizeof *u);
    *u = *t;
    u->is_const = u->is_volatile = false;
    return u;
}

/* t without its own qualifiers, an array staying an array */
static Type *own_unqualified(Type *t) {
    if (!t->is_const && !t->is_volatile)
        return t;
    Type *u = xcalloc(1, sizeof *u);
    *u = *t;
    u->is_const = u->is_volatile = false;
    return u;
}

/* A type as C compares it in a function type: a function type's array
   parameters are pointers, without their own qualifiers */
static char *fn_key(Type *t) {
    if (t->kind != T_FUNC)
        return kelvin_type(t);
    Type *u = xcalloc(1, sizeof *u);
    *u = *t;
    u->params = (List){0};
    for (int i = 0; i < t->params.len; i++)
        list_push(&u->params, unqualified(t->params.data[i]));
    return kelvin_type(u);
}

/* A function's parameter types as Kelvin writes them, without a
   parameter's own qualifiers: "complex64,f64" */
static char *signature(Decl *d) {
    Buf b = {0};
    buf_puts(&b, "");
    bare_tags = true;
    for (int i = 0; i < d->params.len; i++)
        buf_printf(&b, "%s%s", i ? "," : "", kelvin_type(unqualified(((Var *)d->params.data[i])->type)));
    bare_tags = false;
    if (d->variadic)
        buf_puts(&b, ",...");
    return b.buf;
}

/* The Kelvin functions (not methods) named so, or the operators so
   written, one per signature, in the order declared */
static List overloads_of(const char *name, const char *op) {
    List out = {0};
    for (int i = 0; i < functions.len; i++) {
        Decl *d = functions.data[i];
        if (d->recv || (op ? !d->op || strcmp(d->op, op) : d->op || strcmp(d->name, name)))
            continue;
        bool same = false;
        for (int j = 0; j < out.len && !same; j++)
            same = !strcmp(signature(out.data[j]), signature(d));
        if (!same)
            list_push(&out, d);
    }
    return out;
}

/* The same pointer types but for qualifiers that the target of a gains
   in b, as C converts a pointer implicitly; below that, the same types */
static bool gains_qualifiers(Type *a, Type *b) {
    if (a->kind != T_PTR || b->kind != T_PTR || (a->elem->is_const && !b->elem->is_const) ||
        (a->elem->is_volatile && !b->elem->is_volatile))
        return false;
    bare_tags = true;
    bool same = !strcmp(fn_key(own_unqualified(a->elem)), fn_key(own_unqualified(b->elem)));
    bare_tags = false;
    return same;
}

static bool numeric_type(Type *t) {
    Decl *r;
    char c = type_class(t, &r);
    return c == 'i' || c == 'f' || (t->kind == T_BASE && !strcmp(t->name, "bool"));
}

/* Is t a Kelvin struct or union, also one declared without its body yet */
static bool kelvin_record(Type *t) {
    t = unqualified(t);
    if (t->kind != T_BASE)
        return false;
    for (int i = 0; i < records.len; i++) {
        Decl *r = records.data[i];
        if (r->kind != D_ENUM && r->name &&
            !strcmp(t->name, strfmt("%s %s", r->kind == D_STRUCT ? "struct" : "union", r->name)))
            return true;
    }
    return false;
}

/* The Kelvin enum that declares the enumerator name, or NULL */
static Decl *enum_of(const char *name) {
    if (!enumerator_named(name))
        return NULL;
    for (int k = 0; k < records.len; k++) {
        Decl *r = records.data[k];
        for (int m = 0; r->kind == D_ENUM && m < r->members.len; m++)
            if (!strcmp(((Var *)r->members.data[m])->name, name))
                return r;
    }
    return NULL;
}

/* C's integer promotion and usual arithmetic conversions, for Kelvin's
   number types (and bool): the type of a op b, or of op a with b NULL */
static const char *arith_result(const char *a, const char *b) {
    static const char *names[] = {"bool", "i8", "u8", "i16", "u16", "i32", "u32", "i64", "u64", "i128", "u128",
                                  "f32", "f64", NULL};
    static const int ranks[] = {1, 8, 8, 16, 16, 32, 32, 64, 64, 128, 128, 1000, 2000};
    const char *ts[2] = {a, b ? b : a};
    int rank[2];
    for (int i = 0; i < 2; i++) {
        rank[i] = -1;
        for (int k = 0; names[k]; k++)
            if (!strcmp(ts[i], names[k]))
                rank[i] = ranks[k];
        if (rank[i] < 0)
            return NULL;
        if (rank[i] < 32) /* promoted to int */
            ts[i] = "i32", rank[i] = 32;
    }
    if (rank[0] >= 1000 || rank[1] >= 1000)
        return rank[0] > rank[1] ? ts[0] : ts[1];
    bool u0 = ts[0][0] == 'u', u1 = ts[1][0] == 'u';
    if (u0 == u1)
        return rank[0] >= rank[1] ? ts[0] : ts[1];
    const char *un = u0 ? ts[0] : ts[1], *sg = u0 ? ts[1] : ts[0];
    int ru = u0 ? rank[0] : rank[1], rs = u0 ? rank[1] : rank[0];
    return ru >= rs ? un : sg;
}

/* Is e a let's array, which decays to a pointer to its const elements, or
   &x of a let or of a field or element of one, a pointer to const? */
static bool const_target(Expr *e) {
    Expr *x = e;
    bool addr = e->kind == E_PREFIX && !strcmp(e->op, "&");
    if (addr)
        x = e->a;
    while (x->kind == E_FIELD || x->kind == E_INDEX) {
        Type *t = x->a ? value_type(x->a) : NULL;
        if (!x->a || !t || (x->kind == E_INDEX ? t->kind != T_ARRAY : t->kind == T_PTR))
            return false;
        x = x->a;
    }
    if (x->kind != E_IDENT)
        return false;
    int let = let_kind(x->text);
    Type *t = value_type(x);
    if (!t || !(let == LET_VALUE || (let == LET_PARAM && t->kind != T_ARRAY && t->kind != T_PTR)))
        return false;
    return addr || (e == x && t->kind == T_ARRAY);
}

/* An operand's type in C's arithmetic: a literal has C's type there, an
   int where it fits, as `small * 4` is an i32; otherwise as arg_type */
static Type *arg_type(Expr *e);
static Type *operand_type(Expr *e) {
    Expr *lit = e->kind == E_PREFIX && (!strcmp(e->op, "-") || !strcmp(e->op, "+")) ? e->a : e;
    if (lit->kind == E_LITERAL && lit->text[0] == '\'')
        return base_type("i32", e->pos);
    const char *t = literal_type(e);
    if (!t)
        return arg_type(e);
    if (!strcmp(t, "f64"))
        return base_type("f64", e->pos);
    bool hex = lit->text[0] == '0' && lit->text[1] && strchr("xXoObB01234567", lit->text[1]);
    unsigned long long v = strtoull(lit->text, NULL, 0);
    const char *c = v <= 2147483647ULL ? "i32" : hex && v <= 4294967295ULL ? "u32" : v <= 9223372036854775807ULL ? "i64" : "u64";
    return base_type(c, e->pos);
}

/* The type of an argument as far as overloading sees it (#41): the type
   of its value, a literal's own, also negated (#24), bool by its shape, an
   enumerator's enum, size_t for sizeof, and the type C's arithmetic gives
   numbers kelvinc sees; NULL otherwise */
static Type *arg_type(Expr *e) {
    Type *t = value_type(e);
    if (t && const_target(e)) {
        /* a let is const in C (#27): its array's elements, and what &x of
           it (or of its field) points to */
        Type *p = xcalloc(1, sizeof *p);
        p->kind = T_PTR;
        p->pos = e->pos;
        p->elem = xcalloc(1, sizeof *p->elem);
        *p->elem = *t->elem;
        p->elem->is_const = true;
        return p;
    }
    if (t || (e->kind == E_LITERAL && !strcmp(e->text, "nullptr")))
        return t;
    if (seen_bool(e))
        return base_type("bool", e->pos);
    const char *lit = literal_type(e);
    if (lit)
        return base_type(lit, e->pos);
    if (e->kind == E_LITERAL && e->text[0] == '\'') /* a character is a u8 (P13) */
        return base_type("u8", e->pos);
    Decl *en = e->kind == E_IDENT ? enum_of(e->text) : NULL;
    if (en && en->name)
        return base_type(strfmt("enum %s", en->name), e->pos);
    const char *r = NULL;
    switch (e->kind) {
    case E_SIZEOF_TYPE:
    case E_SIZEOF_EXPR:
        return base_type("size_t", e->pos);
    case E_PROPERTY: /* .size and .count are C's size_t */
        if (!strcmp(e->text, "size") || !strcmp(e->text, "count"))
            return base_type("size_t", e->pos);
        break;
    case E_BINARY: {
        if (!strcmp(e->op, ","))
            return arg_type(e->b);
        static const char *ariths[] = {"+", "-", "*", "/", "%", "&", "|", "~", "<<", ">>", NULL};
        bool arith = false;
        for (int i = 0; ariths[i]; i++)
            arith = arith || !strcmp(e->op, ariths[i]);
        Type *a = arith ? operand_type(e->a) : NULL, *b = arith ? operand_type(e->b) : NULL;
        if (a && b && a->kind == T_BASE && b->kind == T_BASE)
            r = !strcmp(e->op, "<<") || !strcmp(e->op, ">>") ? arith_result(a->name, NULL)
                                                               : arith_result(a->name, b->name);
        break;
    }
    case E_PREFIX: {
        Type *a = !strcmp(e->op, "-") || !strcmp(e->op, "+") || !strcmp(e->op, "~") ? operand_type(e->a) : NULL;
        if (a && a->kind == T_BASE)
            r = arith_result(a->name, NULL);
        break;
    }
    case E_TERNARY: {
        Type *b = operand_type(e->b), *c = operand_type(e->c);
        if (b && c && b->kind == T_BASE && c->kind == T_BASE)
            r = arith_result(b->name, c->name);
        break;
    }
    default:
        break;
    }
    return r ? base_type(r, e->pos) : NULL;
}

/* How an argument meets a parameter: 2 exactly, 1 by C's conversions (a
   number to a number, a pointer to one whose target gains qualifiers, or
   to or from any^, nullptr to a pointer), 0 not at all, -1 only C can
   tell, as kelvinc cannot see the argument's type or the parameter's (a C
   typedef) */
static int fit(Expr *arg, Type *param) {
    Type *p = unqualified(param);
    Decl *r;
    char pc = type_class(p, &r);
    if (arg->kind == E_LITERAL && !strcmp(arg->text, "nullptr"))
        return p->kind == T_PTR || p->kind == T_FUNC ? 1 : pc == 'u' ? -1 : 0;
    if (arg->kind == E_IDENT && arg->cands.len) { /* an overloaded function: the one of that type */
        if (p->kind != T_FUNC)
            return pc == 'u' ? -1 : 0;
        for (int i = 0; i < arg->cands.len; i++)
            if (!strcmp(fn_key(fn_type_of(arg->cands.data[i])), fn_key(p)))
                return 2;
        return 0;
    }
    Type *a = arg_type(arg);
    if (a) {
        a = unqualified(a);
        bare_tags = true;
        bool same = !strcmp(fn_key(a), fn_key(p));
        bare_tags = false;
        if (same)
            return 2;
        if (numeric_type(a) && (numeric_type(p) || (pc == 'u' && p->kind == T_BASE)))
            return 1; /* also to a C typedef, which kelvinc cannot tell from a number */
        if (gains_qualifiers(a, p))
            return 1; /* u8^ to const u8^ */
        if (a->kind == T_PTR && p->kind == T_PTR && !(a->elem->is_const && !p->elem->is_const) &&
            ((p->elem->kind == T_BASE && !strcmp(p->elem->name, "any")) ||
             (a->elem->kind == T_BASE && !strcmp(a->elem->name, "any"))))
            return 1;
        Decl *ar;
        return type_class(a, &ar) == 'u' || pc == 'u' ? -1 : 0;
    }
    if (number_expr(arg))
        return numeric_type(p) || pc == 'u' ? -1 : 0;
    if (arg->kind == E_STRING || is_text_expr(arg))
        return p->kind == T_PTR && p->elem->kind == T_BASE &&
                       (!strcmp(p->elem->name, "u8") || !strcmp(p->elem->name, "i8") || !strcmp(p->elem->name, "any"))
                   ? 1
               : pc == 'u' ? -1
                           : 0;
    return -1;
}

/* Does arg, which is no struct where param is one, show that C's own
   function of the name is meant, as sin(z.real) is in sin(z:complex64)?
   A struct passed where no struct is taken is a mistake C reports. */
static bool record_mismatch(Expr *arg, Type *param) {
    Type *a = arg_type(arg);
    Decl *ra, *rp;
    char pc = type_class(unqualified(param), &rp);
    char ac = a ? type_class(unqualified(a), &ra) : number_expr(arg) ? 'i' : 'u';
    return pc == 's' && ac != 's' && ac != 'u';
}

/* Is e a value of some Kelvin struct, which kelvinc cannot tell: a call
   that C's _Generic chooses among overloads that all give one? */
static bool may_be_record(Expr *e) {
    if (e->kind != E_CALL || !e->cands.len ||
        (!((Decl *)e->cands.data[0])->op && reaches_c(&e->cands, e, 0)))
        return false;
    for (int i = 0; i < e->cands.len; i++) {
        Decl *d = e->cands.data[i];
        if (!d->ret || !kelvin_record(d->ret))
            return false;
    }
    return true;
}

/* Does overload da, with fit vector a, beat db: as good on every argument
   kelvinc sees for both, better on one, and the same parameter type where
   only C can tell? */
static char *param_key(Decl *d, int k);
static bool dominates(Decl *da, int *a, Decl *db, int *b, int n) {
    bool better = false;
    for (int k = 0; k < n; k++) {
        if (a[k] < 0 || b[k] < 0) { /* where only C can tell, b may fit where a does not */
            if (strcmp(param_key(da, k), param_key(db, k)))
                return false;
            continue;
        }
        if (a[k] < b[k])
            return false;
        better = better || a[k] > b[k];
    }
    return better;
}

/* The overload, among cands, that args call: the one that all of them fit
   exactly, or the one that fits best, as good as every other on each
   argument kelvinc sees and better on one. *maybe lists the overloads
   left where only C's _Generic can tell, as an argument's type is unseen;
   with neither, C's own function of the name is called (NULL, empty). A
   tie is an error at pos. */
static Decl *choose(List *cands, Expr **args, int nargs, List *maybe, Pos pos, const char *what) {
    *maybe = (List){0};
    List fitting = {0}, fits = {0}, exacts = {0};
    for (int i = 0; i < cands->len; i++) {
        Decl *d = cands->data[i];
        if (nargs < d->params.len || (nargs > d->params.len && !d->variadic))
            continue;
        int *f = xcalloc((size_t)d->params.len + 1, sizeof *f);
        bool ok = true, exact = d->params.len == nargs;
        for (int k = 0; k < d->params.len && ok; k++) {
            f[k] = fit(args[k], ((Var *)d->params.data[k])->type);
            ok = f[k] != 0;
            exact = exact && f[k] == 2;
        }
        if (!ok)
            continue;
        if (exact) {
            list_push(&exacts, d); /* an exact fit is the one, whatever C could tell */
            continue;
        }
        list_push(&fitting, d);
        list_push(&fits, f);
    }
    if (exacts.len > 1)
        error_at(pos, "%s fits more than one of its overloads equally: convert an argument, as in 'x as f64'", what);
    if (exacts.len)
        return exacts.data[0];
    List best = {0};
    bool unknown = false;
    for (int i = 0; i < fitting.len; i++) {
        Decl *d = fitting.data[i];
        bool beaten = false;
        for (int j = 0; j < fitting.len && !beaten; j++) {
            Decl *e = fitting.data[j];
            int n = d->params.len < e->params.len ? d->params.len : e->params.len;
            beaten = j != i && dominates(e, fits.data[j], d, fits.data[i], n);
        }
        if (beaten)
            continue;
        list_push(&best, d);
        for (int k = 0; k < d->params.len; k++)
            unknown = unknown || ((int *)fits.data[i])[k] < 0;
    }
    if (unknown) {
        *maybe = best;
        return NULL;
    }
    if (best.len > 1)
        error_at(pos, "%s fits more than one of its overloads equally: convert an argument, as in 'x as f64'", what);
    return best.len ? best.data[0] : NULL;
}

/* A dispatched call's literal arguments, cast to their Kelvin types, so
   that C's choice sees 4 as an i64, as kelvinc does, not as an int */
static void typed_literals(Expr *call) {
    for (int k = 0; k < call->items.len; k++) {
        Expr *x = call->items.data[k];
        const char *t = literal_type(x);
        if (!t && x->kind == E_LITERAL)
            t = x->text[0] == '\'' ? "u8" : !strcmp(x->text, "true") || !strcmp(x->text, "false") ? "bool" : NULL;
        if (!t)
            continue;
        Expr *c = new_expr(E_CAST, x->pos);
        c->op = "converter";
        c->type = base_type(t, x->pos);
        c->a = x;
        call->items.data[k] = c;
    }
}

/* Per argument, whether only C can tell which of cands it fits */
static bool *unseen_args(List *cands, Expr **args, int nargs) {
    bool *unseen = xcalloc((size_t)nargs + 1, sizeof *unseen);
    for (int i = 0; i < cands->len; i++) {
        Decl *d = cands->data[i];
        for (int k = 0; k < nargs && k < d->params.len; k++)
            unseen[k] = unseen[k] || fit(args[k], ((Var *)d->params.data[k])->type) < 0;
    }
    return unseen;
}

/* Parameter k of d as _Generic tells it from another overload's */
static char *param_key(Decl *d, int k) {
    bare_tags = true;
    char *key = kelvin_type(unqualified(((Var *)d->params.data[k])->type));
    bare_tags = false;
    return key;
}

/* Can the choice of call's overload among cands, from argument k on, give
   a number to C's own function of the name? It may where no overload left
   takes a number there. This follows generic_tree in codegen.c, which
   writes the choice, as if the program called C's function (c_too). */
static bool reaches_c(List *cands, Expr *call, int k) {
    int n = call->items.len;
    while (k < n && call->unseen && !call->unseen[k])
        k++;
    if (k >= n)
        return false;
    int numbers = 0;
    for (int i = 0; i < cands->len; i++) {
        Decl *d = cands->data[i];
        numbers += k < d->params.len && ((Var *)d->params.data[k])->number;
    }
    if (!numbers)
        return true;
    for (int i = 0; i < cands->len; i++) {
        Decl *d = cands->data[i];
        if (k >= d->params.len)
            continue;
        List same = {0};
        for (int j = 0; j < cands->len; j++) {
            Decl *e = cands->data[j];
            if (k < e->params.len && !strcmp(param_key(e, k), param_key(d, k)))
                list_push(&same, e);
        }
        if (reaches_c(&same, call, k + 1))
            return true;
    }
    return false;
}

/* A function's name used as a value (#41): the overload of the function
   type that want is; with none of that type, C's own function of the
   name, as sqrt is beside sqrt(v:vec) */
static void pick_overload(Expr *v, Type *want) {
    if (!v || v->kind != E_IDENT || (!v->cands.len && !v->target) || !want || want->kind != T_FUNC)
        return;
    if (v->target && !strcmp(fn_key(fn_type_of(v->target)), fn_key(want)))
        return;
    for (int i = 0; i < v->cands.len; i++) {
        Decl *d = v->cands.data[i];
        if (!strcmp(fn_key(fn_type_of(d)), fn_key(want))) {
            v->target = d;
            v->cands.len = 0;
            return;
        }
    }
    v->target = NULL;
    v->cands.len = 0;
    v->op = "c";
    list_push(&c_called, v->text);
}

/* f(args) where f names Kelvin functions (#41): the overload chosen, or
   C's _Generic among those that may fit, or C's own function of the
   name for other arguments. A single function of the program's own keeps
   its C name and is called as C calls it, unless what is passed where it
   takes a struct is a number or a value only C sees, which is for C's
   function of the name. */
static void resolve_call(Expr *call) {
    Expr *callee = call->a;
    if (callee->kind != E_IDENT || lookup_type(callee->text))
        return;
    if (!function_named(callee->text)) { /* C's function, which a Kelvin one may overload later */
        list_push(&c_called, callee->text);
        reject_owners_to_c(call);
        return;
    }
    List cands = overloads_of(callee->text, NULL);
    Decl *only = cands.len == 1 ? cands.data[0] : NULL;
    if (only) {
        bool other = false, unseen = false;
        for (int k = 0; k < call->items.len && k < only->params.len; k++) {
            Expr *x = call->items.data[k];
            Type *t = ((Var *)only->params.data[k])->type;
            Decl *r;
            other = other || record_mismatch(x, t);
            unseen = unseen || (type_class(unqualified(t), &r) == 's' && fit(x, t) < 0 && !may_be_record(x));
        }
        if (!other && unseen) { /* _Generic chooses between it and C's function, where C has one */
            list_push(&call->cands, only);
            call->unseen = unseen_args(&call->cands, (Expr **)call->items.data, call->items.len);
            typed_literals(call);
            list_push(&dispatched, call);
            return;
        }
        if (!other) {
            call->target = only;
            drop_cstr_args(call, only);
            move_args(call, only);
            return;
        }
    } else {
        call->target = choose(&cands, (Expr **)call->items.data, call->items.len, &call->cands, call->pos,
                              strfmt("%s(...)", callee->text));
        if (call->cands.len) {
            call->unseen = unseen_args(&call->cands, (Expr **)call->items.data, call->items.len);
            typed_literals(call);
            list_push(&dispatched, call);
        }
        if (call->target) {
            drop_cstr_args(call, call->target);
            move_args(call, call->target);
        }
        if (call->target || call->cands.len)
            return;
    }
    /* with no Kelvin overload to call, C's own function is; the Kelvin
       ones then overload it, and are named by their types in C */
    call->op = "c";
    list_push(&c_called, callee->text);
    reject_owners_to_c(call);
}

/* an owner given by value to a Kelvin function moves into it (O5) */
static void move_args(Expr *call, Decl *d) {
    for (int k = 0; k < call->items.len && k < d->params.len; k++)
        move_argument(call->items.data[k], param_type(((Var *)d->params.data[k])->type), strfmt("'%s'", d->name));
}

/* C sees pointers, not owners (O8); print and println show one in a
   place, since one an expression gives would never be freed */
static void reject_owners_to_c(Expr *call) {
    if (call->a->kind == E_IDENT && (!strcmp(call->a->text, "print") || !strcmp(call->a->text, "println"))) {
        for (int k = 0; k < call->items.len; k++) {
            Expr *x = call->items.data[k];
            if (is_array_owner(value_type(x)) || is_dict_owner(value_type(x)))
                error_at(x->pos, "%s has no text yet: %s its %s, as in '%s'",
                         is_dict_owner(value_type(x)) ? "a Dictionary" : "an Array", call->a->text,
                         is_dict_owner(value_type(x)) ? "entries" : "elements",
                         is_dict_owner(value_type(x)) ? "for k, v in d" : "for x in xs");
            if (is_owner(value_type(x)) && !owner_place(x))
                error_at(x->pos, "%s of an owner that an expression gives, which nothing would free: bind it to a "
                                 "variable first",
                         call->a->text);
        }
        return;
    }
    for (int k = 0; k < call->items.len; k++) {
        Expr *x = call->items.data[k];
        if (is_owner(value_type(x)))
            error_at(x->pos, "an owner cannot be given to a C function, which could not free it: pass '%s.at' and "
                             "'%s.count', or '%s.cstr'",
                     x->kind == E_IDENT ? x->text : "b", x->kind == E_IDENT ? x->text : "b",
                     x->kind == E_IDENT ? x->text : "b");
    }
}

/* a cstr given to a u8^ parameter of the Kelvin function called (#52) */
static void drop_cstr_args(Expr *call, Decl *d) {
    for (int k = 0; k < call->items.len && k < d->params.len; k++)
        call->items.data[k] = drop_cstr(call->items.data[k], param_type(((Var *)d->params.data[k])->type));
}

/* How an operand shows in a message about operators */
static char *operand_text(Expr *x, Type *t) {
    if (x->kind == E_LITERAL && !strcmp(x->text, "nullptr"))
        return "nullptr";
    if (x->kind == E_STRING || is_text_expr(x))
        return "text";
    if (!t)
        return NULL;
    bare_tags = true;
    char *s = kelvin_type(t);
    bare_tags = false;
    return s;
}

/* a op b and op a, with an operator a Kelvin struct defines (#42): a call
   of the operator chosen, or e as C's own operator */
static Expr *resolve_operator(Expr *e, const char *op, Expr *a, Expr *b) {
    Decl *r;
    Type *ta = arg_type(a), *tb = b ? arg_type(b) : NULL;
    bool record = (ta && type_class(ta, &r) == 's') || (tb && type_class(tb, &r) == 's') || may_be_record(a) ||
                  (b && may_be_record(b));
    List cands = overloads_of(NULL, op);
    if (!cands.len && !record)
        return e;
    Expr *args[2] = {a, b};
    List maybe = {0};
    Decl *d = cands.len ? choose(&cands, args, b ? 2 : 1, &maybe, e->pos, strfmt("'%s'", op)) : NULL;
    if (!d && (!record || !maybe.len)) {
        if (record) {
            char *sa = operand_text(a, ta), *sb = b ? operand_text(b, tb) : NULL;
            char *pa = sa && strcmp(sa, "text") && strcmp(sa, "nullptr") ? sa : sa ? "u8^" : "T";
            char *pb = sb && strcmp(sb, "text") && strcmp(sb, "nullptr") ? sb : sb ? "u8^" : "T";
            sa = sa ? sa : "a value kelvinc cannot see";
            sb = b && !sb ? "a value kelvinc cannot see" : sb;
            if (b)
                error_at(e->pos, "no operator %s takes %s and %s: define one, as in 'let %s(a:%s, b:%s):... { ... }'", op,
                         sa, sb, op, pa, pb);
            error_at(e->pos, "no operator %s takes %s: define one, as in 'let %s(a:%s):... { ... }'", op, sa, op, pa);
        }
        return e; /* C's own operator */
    }
    Expr *call = new_expr(E_CALL, e->pos);
    call->a = new_expr(E_IDENT, e->pos);
    call->a->text = (char *)op;
    call->target = d;
    call->paren = e->paren;
    list_push(&call->items, a);
    if (b)
        list_push(&call->items, b);
    if (!d) { /* a struct and a value only C sees: C's _Generic chooses */
        call->cands = maybe;
        call->unseen = unseen_args(&maybe, args, b ? 2 : 1);
        typed_literals(call);
    }
    return call;
}

/* A C name made from a type, as complex64, u8p for u8^, a3 for [3], and
   F...E around a function type's parameters, its result after the E */
static char *mangled_type(Type *t) {
    if (is_dict_owner(t)) /* Dictionary<K, V> is Dictionary_<K>_<V> (#65) */
        return strfmt("Dictionary_%s_%s", mangled_type(t->key), mangled_type(t->elem));
    if (is_array_owner(t)) /* Array<T> is Array_<T> (#57) */
        return strfmt("Array_%s", mangled_type(t->elem));
    if (anon_record_of(t)) /* a struct with no tag is anonN (#59) */
        return anon_record_of(t)->name + 4;
    bare_tags = true;
    char *k = kelvin_type(unqualified(t));
    bare_tags = false;
    Buf b = {0};
    buf_puts(&b, "");
    for (const char *c = k; *c; c++) {
        if (isalnum((unsigned char)*c) || *c == '_')
            buf_putn(&b, c, 1);
        else if (*c == '^')
            buf_puts(&b, "p");
        else if (*c == '[')
            buf_puts(&b, "a");
        else if (*c == '(')
            buf_puts(&b, "F");
        else if (*c == ')')
            buf_puts(&b, "E");
        else if (*c == ',' || (*c == ' ' && c[-1] != ','))
            buf_puts(&b, "_");
    }
    return b.buf;
}

/* The C names of functions and operators (#41, #42): an overloaded
   function, one an imported Kelvin file defines, and one that shares its
   name with a C function the program calls, is named by its parameter
   types, as sin__complex64 (f__void with none); a function the program
   declares but never defines is C's, and keeps its name; an operator is
   _kv_add_op__... Two that would get the same C name are an error. */
static void name_functions(void) {
    for (int i = 0; i < dispatched.len; i++) {
        Expr *call = dispatched.data[i];
        call->c_too = called_as_c(call->a->text);
    }
    static const struct { const char *op, *word; } words[] = {
        {"+", "add"}, {"-", "sub"}, {"*", "mul"}, {"/", "div"}, {"%", "mod"}, {"==", "eq"}, {"!=", "ne"},
        {"<", "lt"}, {"<=", "le"}, {">", "gt"}, {">=", "ge"}};
    for (int i = 0; i < functions.len; i++) {
        Decl *d = functions.data[i];
        if (d->recv)
            continue;
        Buf types = {0};
        buf_puts(&types, "");
        for (int k = 0; k < d->params.len; k++)
            buf_printf(&types, "__%s", mangled_type(((Var *)d->params.data[k])->type));
        if (d->variadic)
            buf_puts(&types, "__va");
        if (!types.len)
            buf_puts(&types, "__void");
        if (d->op) {
            const char *w = d->params.len == 1 && !strcmp(d->op, "-") ? "neg" : "op";
            for (size_t k = 0; k < sizeof words / sizeof words[0]; k++)
                if (!strcmp(words[k].op, d->op) && strcmp(w, "neg"))
                    w = words[k].word;
            d->cname = strfmt("_kv_%s_op%s", w, types.buf);
            continue;
        }
        bool defined = false, imported = false;
        for (int k = 0; k < functions.len; k++) {
            Decl *e = functions.data[k];
            if (e->recv || e->op || strcmp(e->name, d->name))
                continue;
            imported = imported || e->imported;
            defined = defined || (e->body && !strcmp(signature(e), signature(d)));
        }
        bool by_types = overloads_of(d->name, NULL).len > 1 || imported || called_as_c(d->name);
        if (!defined || !strcmp(d->name, "main"))
            by_types = false;
        d->cname = by_types ? strfmt("%s%s", d->name, types.buf) : d->name;
    }
    for (int i = 0; i < functions.len; i++) {
        Decl *d = functions.data[i];
        char *name = d->recv ? strfmt("%s__%s", d->recv_name, d->name) : d->cname;
        for (int j = 0; j < i; j++) {
            Decl *e = functions.data[j];
            char *other = e->recv ? strfmt("%s__%s", e->recv_name, e->name) : e->cname;
            bool same_fn = !d->recv == !e->recv && (d->recv ? !strcmp(d->recv_name, e->recv_name) : 1) &&
                           !strcmp(d->name, e->name) && !strcmp(signature(d), signature(e));
            if (!same_fn && !(d->recv && e->recv) && !strcmp(name, other)) /* methods are checked as declared (P26) */
                error_at(d->pos, "this function and the one at %s%sline %d would both be named %s in C: rename one",
                         strcmp(e->pos.file, d->pos.file) ? e->pos.file : "",
                         strcmp(e->pos.file, d->pos.file) ? ", " : "", e->pos.line, name);
        }
    }
}

/* Is v.i64 (any converter name) a field of v: one of a Kelvin struct
   that has it, of a C struct, or of what kelvinc cannot see is no struct?
   (#36) */
static bool converter_is_field(Expr *v, const char *member) {
    Decl *record;
    char c = expr_class(v, &record);
    return c == 'c' || (c == 's' && record_has_field(record, member)) || (c == 'u' && !number_expr(v) && !is_text_expr(v));
}

/* `x.size` is sizeof(x); `x.cstr` is its text (#22), and `x.dec`, `.hex`,
   `.oct`, `.bin` the text of a number. Returns NULL when `.name` is a
   field access instead: always when a Kelvin struct has that field, and
   for `.size` whenever kelvinc cannot see that the receiver is not a C
   struct (the field wins when unsure). */
static Expr *property(Expr *e, Token *name, char *member) {
    if (is_uchr(value_type(e)) && (!strcmp(member, "utf32") || !strcmp(member, "codepoint"))) {
        /* a uchr's codepoint as a u32 (#56) */
        Expr *x = utf32_of(e);
        x->pos = name->pos;
        return x;
    }
    if (!strcmp(member, "uchr")) {
        /* n.uchr is uchr(n) (#56): of an integer, or a character; a field
           wins where kelvinc is unsure */
        Decl *record;
        char c = expr_class(e, &record);
        if ((c == 's' && record_has_field(record, member)) || c == 'c' || c == 'u')
            return NULL;
        if (c != 'i' && !(e->kind == E_LITERAL && e->text[0] == '\''))
            error_at(name->pos, "'.uchr' converts an integer to a codepoint, and this is %s",
                     arg_type(e) ? kelvin_type(arg_type(e)) : "no integer");
        Expr *x = new_expr(E_PROPERTY, name->pos);
        x->a = e;
        x->text = member;
        x->op = "to";
        return x;
    }
    const char *kind = builtin_owner(value_type(e));
    if (kind && ((!strcmp(kind, "bytes") && (!strcmp(member, "count") || !strcmp(member, "capacity") ||
                                             !strcmp(member, "at") || !strcmp(member, "cstr") ||
                                             !strcmp(member, "isUTF8"))) ||
                 (!strcmp(kind, "string") && (!strcmp(member, "count") || !strcmp(member, "bytes") ||
                                              !strcmp(member, "cstr"))) ||
                 (!strcmp(kind, "array") && (!strcmp(member, "count") || !strcmp(member, "capacity") ||
                                             !strcmp(member, "at"))) ||
                 (!strcmp(kind, "dict") && (!strcmp(member, "count") || !strcmp(member, "keys") ||
                                            !strcmp(member, "values"))))) {
        /* a Bytes (#54): its count and capacity, its bytes, its text as a
           cstr, a borrow, and whether it is UTF-8; a String (#55): its
           codepoints, its bytes, a read-only borrow, and its text; of a
           place, since a value an expression gives would be lost */
        if (!owner_place(e))
            error_at(name->pos, "'.%s' of a %s that an expression gives: bind it to a variable first, which frees "
                                "it when its block ends",
                     member, kind[0] == 'b' ? "Bytes" : kind[0] == 's' ? "String" : kind[0] == 'd' ? "Dictionary" : "Array");
        Expr *x = new_expr(E_PROPERTY, name->pos);
        x->a = e;
        x->text = member;
        x->op = (char *)kind;
        x->is_bool = !strcmp(member, "isUTF8");
        if (kind[0] == 'd' && (!strcmp(member, "keys") || !strcmp(member, "values"))) {
            /* d.keys and d.values (#66): Arrays of copies, made by a function
               the codegen writes after the Dictionary's and the Array's C */
            Type *dt = value_type(e);
            bool keys = !strcmp(member, "keys");
            x->recv_type = dt;
            x->type = array_type(name, keys ? dt->key : dt->elem);
            bool seen = false;
            for (int i = 0; !seen && i < program->views.len; i++) {
                DictView *v = program->views.data[i];
                seen = v->keys == keys && !strcmp(v->dict->name, dt->name);
            }
            if (!seen) {
                DictView *v = xcalloc(1, sizeof *v);
                v->dict = dt;
                v->arr = x->type;
                v->keys = keys;
                v->decl = program->decls.len;
                list_push(&program->views, v);
            }
        }
        return x;
    }
    if (is_converter(&(Token){.kind = TK_KEYWORD, .text = member})) {
        /* v.i64 is i64(v), so "42".i64 reads text (#36). A field of that
           name wins: a Kelvin struct's, a C struct's, and, as for .size,
           whenever kelvinc cannot see that v is no struct (o.via.i64) */
        if (converter_is_field(e, member))
            return NULL;
        Decl *record;
        if (expr_class(e, &record) == 's') {
            bare_tags = true;
            char *type = kelvin_type(value_type(e));
            bare_tags = false;
            error_at(name->pos, "'.%s' converts a number or reads text, and %s is a %s with no field '%s'", member,
                     type, record->kind == D_UNION ? "union" : "struct", member);
        }
        return convert(name, member, e, NULL);
    }
    if (!strcmp(member, "next") || !strcmp(member, "prev")) {
        /* p.next is p + 1 and p.prev is p - 1, on a pointer kelvinc can
           see (#26); on anything else `.next` is a field, as in n^.next */
        Type *t = value_type(e);
        if (is_cstr(t))
            error_at(name->pos, "a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a "
                                "'var p:u8^ := s'");
        if (t && t->kind == T_ARRAY)
            error_at(name->pos, "'.%s' is a property of pointers: for an array, write '&a[%s]'", member,
                     member[0] == 'n' ? "1" : "-1");
        if (t && t->kind == T_FUNC)
            error_at(name->pos, "'.%s' is a property of pointers to data, and %s is a function", member,
                     kelvin_type(t));
        if (!t || t->kind != T_PTR)
            return NULL;
        if (t->elem->kind == T_BASE && !strcmp(t->elem->name, "any"))
            error_at(name->pos, "an any^ has no '.%s': its element has no size", member);
        Expr *x = new_expr(E_PROPERTY, name->pos);
        x->a = e;
        x->text = member;
        return x;
    }
    if (!strcmp(member, "count")) {
        /* a.count is an array's number of elements (#49), sizeof(a) /
           sizeof a[0], also of a VLA; a field wins where kelvinc is unsure */
        Decl *record;
        char c = expr_class(e, &record);
        if ((c == 's' && record_has_field(record, member)) || c == 'c' || c == 'u')
            return NULL;
        Type *t = value_type(e);
        if (is_cstr(t)) { /* strlen, kept once measured (#52) */
            Expr *x = new_expr(E_PROPERTY, name->pos);
            x->a = e;
            x->text = member;
            x->op = "cstr";
            return x;
        }
        if (!t || t->kind != T_ARRAY) {
            if (t && t->kind == T_PTR)
                error_at(name->pos, "'.count' is a property of arrays, and this is %s, a pointer: an array passed to "
                                    "a function is one, so its count is passed beside it",
                         kelvin_type(t));
            error_at(name->pos, "'.count' is a property of arrays%s%s", t ? ", and this is " : "", t ? kelvin_type(t) : "");
        }
        Expr *x = new_expr(E_PROPERTY, name->pos);
        x->a = e;
        x->text = member;
        return x;
    }
    if (!strcmp(member, "type") || !strcmp(member, "typename")) {
        /* v.type is a type (#34), which an expression cannot hold: there
           .type is a field, if any; v.typename is the type's Kelvin text */
        Decl *record;
        char c = expr_class(e, &record);
        if (c == 's' && record_has_field(record, member))
            return NULL;
        if (!member[4]) {
            if (c == 'c' || c == 'u')
                return NULL;
            error_at(name->pos, "'.type' is a type, not a value: use it where a type goes, as in 'var w:v.type' or "
                                "'x as v.type'");
        }
        /* .typename is a property also of a C struct, or of what kelvinc
           cannot see: C++ reserves the word, so C headers rarely name a
           field so. A literal is C's: 42 is an int, as 42.size says. */
        Type *t = value_type(e);
        if (!t && seen_bool(e))
            t = base_type("bool", e->pos);
        Expr *x;
        if (t && !type_has_expr(t)) {
            bare_tags = true;
            char *text = kelvin_type(t);
            bare_tags = false;
            Buf lit = {0}; /* a C string literal */
            buf_puts(&lit, "\"");
            for (const char *ch = text; *ch; ch++) {
                if (*ch == '"' || *ch == '\\')
                    buf_puts(&lit, "\\");
                buf_putn(&lit, ch, 1);
            }
            buf_puts(&lit, "\"");
            x = new_expr(E_STRING, name->pos);
            list_push(&x->items, lit.buf);
        } else { /* C's _Generic names a built-in type */
            x = new_expr(E_PROPERTY, name->pos);
            x->a = e;
            x->text = member;
        }
        return x;
    }
    if (!strcmp(member, "isNull")) {
        /* p.isNull is p == nullptr, a bool, of a pointer or a function
           (#50); a field wins where kelvinc is unsure */
        Decl *record;
        char c = expr_class(e, &record);
        if ((c == 's' && record_has_field(record, member)) || c == 'c' || c == 'u')
            return NULL;
        Type *t = value_type(e);
        if (t && t->kind == T_ARRAY)
            error_at(name->pos, "'.isNull' of an array: an array is never null; '&a[0]' is a pointer");
        if (!pointer_expr(e))
            error_at(name->pos, "'.isNull' is a property of pointers and functions%s%s", t ? ", and this is " : "",
                     t ? kelvin_type(t) : "");
        Expr *x = new_expr(E_PROPERTY, name->pos);
        x->a = e;
        x->text = member;
        x->is_bool = true;
        return x;
    }
    if (!strcmp(member, "addr") || !strcmp(member, "hex")) {
        /* p.addr is a pointer's or a function's address as a uintptr_t,
           and p.hex its text, 0x and all the digits (#37) */
        Decl *record;
        char c = expr_class(e, &record);
        Type *t = value_type(e);
        if (t && t->kind == T_ARRAY)
            error_at(name->pos, "'.%s' of an array: an array is no pointer; write '(&a[0]).%s'", member, member);
        if (pointer_expr(e)) {
            Expr *x = new_expr(E_PROPERTY, name->pos);
            x->a = e;
            x->text = member;
            x->op = "pointer";
            return x;
        }
        if (!strcmp(member, "addr")) {
            /* as for .size, a field wins where kelvinc is unsure */
            if ((c == 's' && record_has_field(record, member)) || c == 'c' || c == 'u')
                return NULL;
            error_at(name->pos, "'.addr' is a property of pointers and functions");
        }
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
        if (t && t->kind == T_FUNC)
            error_at(name->pos, "'.cstr' of a function: a function has no text");
        Expr *x = new_expr(E_PROPERTY, name->pos);
        x->a = e;
        x->text = member;
        x->type = c == 's' ? t : NULL;
        x->op = c == 'u' ? "unknown" : NULL;
        return x;
    }
    if (is_text && (c == 'n' || c == 's'))
        error_at(name->pos, "'.%s' is a property of integers%s", member,
                 !strcmp(member, "hex") ? ", of f32/f64, and of pointers and functions"
                 : !strcmp(member, "dec") ? " and of f32/f64"
                                          : "");
    if (is_text && c == 'f' && (!strcmp(member, "oct") || !strcmp(member, "bin")))
        error_at(name->pos, "'.%s' is a property of integers; f32 and f64 have .dec and .hex", member);
    Expr *x = new_expr(E_PROPERTY, name->pos);
    x->a = e;
    x->text = member;
    if (is_size && is_function_designator(e)) {
        /* a function's name is a function value (#31): its size is a
           pointer's, sizeof(&f), not C's sizeof of a function */
        Expr *a = new_expr(E_PREFIX, e->pos);
        a->op = "&";
        a->a = e;
        x->a = a;
    }
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

static Expr *text_in_buffer(Expr *e);

/* A template's text is stored in its block (#39), so a variable of an
   outer block, or a global, would keep it after it is gone; the
   function's own parameters end with its body */
static void reject_template_escape(Expr *target, Expr *value, Pos pos) {
    /* a borrow of a local owner too (#54) */
    if (target->kind == E_IDENT && value->kind == E_PREFIX && !strcmp(value->op, "&") && value->a->kind == E_IDENT &&
        is_owner(value_type(value->a))) {
        int b = binding_index(value->a->text), i = binding_index(target->text);
        int here = scope_marks.len ? (int)(intptr_t)scope_marks.data[scope_marks.len - 1] : 0;
        int globals = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
        if (b >= globals && b >= here && i >= 0 && i < here)
            error_at(pos, "a borrow of '%s' outlives it: '%s' is freed when this block ends, and '%s' is of an "
                          "outer one",
                     value->a->text, value->a->text, target->text);
        return;
    }
    Expr *text = target->kind == E_IDENT ? text_in_buffer(value) : NULL;
    if (!text || text->kind != E_TEMPLATE)
        return;
    int i = binding_index(target->text);
    int here = scope_marks.len ? (int)(intptr_t)scope_marks.data[scope_marks.len - 1] : 0;
    if (i >= here || (i >= params_start && i < params_end && here == params_end))
        return;
    error_at(pos, "a template's text lives until this block ends, and '%s' outlives it: make the text in the "
                  "block of '%s', or copy it, as in '%s := strdup(...)'",
             target->text, target->text, target->text);
}

static const char *assign_ops[] = {"=", ":=", "+=", "-=", "*=", "/=", "%=", "<<=", ">>=", "&=", "~=", "|=", NULL};

/* Is e the same value, or the same place, when evaluated twice: no
   call or assignment in it? */
static bool repeatable(Expr *e) {
    if (!e)
        return true;
    switch (e->kind) {
    case E_LITERAL:
    case E_STRING:
    case E_IDENT:
    case E_SIZEOF_TYPE:
    case E_SIZEOF_EXPR:
        return true;
    case E_FIELD:
    case E_DEREF:
    case E_CAST:
    case E_PROPERTY:
        return repeatable(e->a);
    case E_PREFIX:
        return strcmp(e->op, "++") && strcmp(e->op, "--") && repeatable(e->a);
    case E_INDEX:
        return repeatable(e->a) && repeatable(e->b);
    case E_TERNARY:
        return repeatable(e->a) && repeatable(e->b) && repeatable(e->c);
    case E_BINARY:
        for (int i = 0; assign_ops[i]; i++)
            if (!strcmp(e->op, assign_ops[i]))
                return false;
        return repeatable(e->a) && repeatable(e->b);
    default:
        return false;
    }
}

/* Is the operand at token j, with its postfixes, assigned to, as in
   `*p = 1`, `*p.x += 2` or `*(p + 1) = 3`? */
static bool assigned_after(int j) {
    j = is_p(&toks[j], "(") ? skip_group(j) : j + 1;
    for (;;) {
        if (is_p(&toks[j], ".") && toks[j + 1].kind == TK_IDENT)
            j += 2;
        else if (is_p(&toks[j], "[") || is_p(&toks[j], "("))
            j = skip_group(j);
        else if (is_p(&toks[j], "^"))
            j++;
        else
            break;
    }
    for (int k = 0; assign_ops[k]; k++)
        if (is_p(&toks[j], assign_ops[k]))
            return true;
    return is_p(&toks[j], "++") || is_p(&toks[j], "--");
}

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
        return t && (t->kind == T_ARRAY || is_bytes(t) || is_array_owner(t) || is_dict_owner(t))
                   ? let_target(e->a)
                   : NULL; /* a Bytes's byte too (#54), a Dictionary's value (#65) */
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

/* a let, a range's counter, each element of a sequence or a parameter
   cannot change: the target of an assignment or of p++ (#27, #51) */
static void reject_let_change(Expr *lhs, Token *t) {
    const char *let = let_target(lhs);
    if (let && let_kind(let) == LET_RANGE)
        error_at(t->pos, "'%s' counts the range and cannot change; copy it under another name, as in "
                         "'var k:%s = %s'", let, kelvin_type(lookup_type(let)), let);
    if (let && let_kind(let) == LET_EACH)
        error_at(t->pos, "'%s' is each element in turn and cannot change; copy it into a var under "
                         "another name",
                 let);
    if (let && let[0] == '$')
        error_at(t->pos, "'%s' is a parameter and cannot change; copy it into a var", let);
    if (let && let_kind(let) == LET_PARAM)
        error_at(t->pos, "'%s' is a let parameter and cannot change; write 'var %s' in the parameter list",
                 let, let);
    if (let)
        error_at(t->pos, "'%s' is a let and cannot change; declare it with var", let);
}

static Expr *parse_assign(void) {
    bool ok = assign_ok;
    assign_ok = false; /* nothing inside may assign */
    Expr *lhs = parse_conditional();
    Token *t = peek();
    if ((is_p(t, "++") || is_p(t, "--")) && !newline_before()) {
        /* p++ and p-- step a var pointer kelvinc sees, as statements
           (#51); C decides for a type it cannot see. On the next line,
           ++p starts a statement (#35), an error */
        if (!ok)
            error_at(t->pos, "'%s' is a statement in Kelvin, not a value: step the pointer on a line of its own",
                     t->text);
        advance();
        reject_let_change(lhs, t);
        Type *tt = value_type(lhs);
        if (is_cstr(tt))
            error_at(t->pos, "a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a "
                             "'var p:u8^ := s'");
        if (tt && tt->kind == T_FUNC)
            error_at(t->pos, "'%s' is for pointers, and this is a function", t->text);
        if (tt && tt->kind == T_ARRAY)
            error_at(t->pos, "'%s' is for pointers, and an array does not move: index it, or take a pointer, "
                             "'var p := a'",
                     t->text);
        if (tt && tt->kind == T_PTR && tt->elem->kind == T_BASE && !strcmp(tt->elem->name, "any"))
            error_at(t->pos, "an any^ cannot step: its element has no size");
        Decl *r;
        if (tt && tt->kind != T_PTR && !(tt->kind == T_BASE && type_class(tt, &r) == 'u'))
            error_at(t->pos, "'%s' is for pointers, and this is %s: write 'x %s= 1'", t->text, kelvin_type(tt),
                     t->text[0] == '+' ? "+" : "-");
        Expr *e = new_expr(E_POSTFIX, t->pos);
        e->op = t->text;
        e->a = lhs;
        assign_ok = ok;
        return e;
    }
    for (int i = 0; assign_ops[i]; i++)
        if (is_p(t, assign_ops[i])) {
            if (!ok)
                error_at(t->pos, "assignment is a statement in Kelvin, not a value: assign on a line of its own");
            advance();
            reject_let_change(lhs, t);
            /* a cstr's bytes never change, and it does not step (#52) */
            if ((lhs->kind == E_INDEX || lhs->kind == E_DEREF) && is_cstr(value_type(lhs->a)))
                error_at(t->pos, "a cstr is immutable (#52): to change text, copy it into a byte array, "
                                 "'var t:[u8](n)' and strcpy, or write through a 'var p:u8^ := s'");
            if ((!strcmp(t->text, "+=") || !strcmp(t->text, "-=")) && is_cstr(value_type(lhs)))
                error_at(t->pos, "a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step "
                                 "a 'var p:u8^ := s'");
            if (!strcmp(t->text, "+=") && builtin_owner(value_type(lhs))) {
                /* b += x is b.append(x) (#54, #55) */
                if (is_dict_owner(value_type(lhs)))
                    error_at(t->pos, "a Dictionary has no '+=': add an entry with d[k] = v");
                if (!owner_place(lhs))
                    error_at(t->pos, "'+=' on an owner that an expression gives: bind it to a variable first");
                if (let_target(lhs))
                    error_at(t->pos, "'%s' is a let and cannot change; declare it with var", let_target(lhs));
                Expr *x = new_expr(E_METHOD, t->pos);
                x->a = lhs;
                x->text = "append";
                x->op = (char *)builtin_owner(value_type(lhs));
                x->type = value_type(lhs);
                Expr *given = parse_assign();
                check_appended(given, x->op, "+=");
                if (x->op[0] == 'a')
                    x->text = (char *)array_append_kind(given, x->type);
                list_push(&x->items, given);
                assign_ok = ok;
                return x;
            }
            if (!strcmp(t->text, "=") && lhs->kind == E_INDEX && lhs->op && !strcmp(lhs->op, "dict")) {
                /* d[k] = v adds the entry, or replaces its value, freeing what it held (#65) */
                Expr *x = new_expr(E_METHOD, t->pos);
                x->a = lhs->a;
                x->text = "set";
                x->op = "dict";
                x->type = lhs->type;
                list_push(&x->items, lhs->b);
                Expr *v = case_value(lhs->type->elem);
                assign_ok = ok;
                reject_owner_copy(v, lhs->type->elem, t->pos);
                reject_record_mismatch(v, lhs->type->elem, t->pos);
                list_push(&x->items, v);
                return x;
            }
            if (!strcmp(t->text, "=") && lhs->kind == E_FIELD && lhs->op && !strcmp(lhs->op, "case")) {
                /* v.n = x sets the case and its value (#61): an owner moves in */
                Expr *x = new_expr(E_METHOD, t->pos);
                x->a = lhs->a;
                x->text = lhs->text;
                x->op = "case_set";
                x->target = lhs->target;
                Expr *v = case_value(lhs->type);
                assign_ok = ok;
                reject_owner_copy(v, lhs->type, t->pos);
                reject_record_mismatch(v, lhs->type, t->pos);
                move_argument(v, lhs->type, strfmt("case '%s'", lhs->text));
                list_push(&x->items, v);
                return x;
            }
            if (!strcmp(t->text, "=") || !strcmp(t->text, ":="))
                check_assign_op(t->text, target_type(lhs),
                                lhs->kind == E_IDENT ? strfmt("'%s'", lhs->text) : "this target", t->pos, NULL);
            Expr *e = new_expr(E_BINARY, t->pos);
            e->op = t->text;
            e->a = lhs;
            /* a target of a function type, or one kelvinc cannot see,
               may take an anonymous function (#32) */
            Type *target = value_type(lhs); /* also through a cast or a call */
            Decl *r;
            if (is_p(peek(), "{") &&
                (!target || target->kind == T_FUNC || (target->kind == T_BASE && type_class(target, &r) == 'u'))) {
                fn_at = cur;
                fn_type = target && target->kind == T_FUNC ? target : NULL;
            }
            e->b = parse_assign();
            assign_ok = ok;
            pick_overload(e->b, target_type(lhs));
            if (!strcmp(t->text, ":="))
                e->b = drop_cstr(e->b, target_type(lhs));
            if (!strcmp(t->text, "=")) { /* an owner takes a value and frees what it held (#54) */
                reject_owner_copy(e->b, target_type(lhs), t->pos);
                reject_record_mismatch(e->b, target_type(lhs), t->pos);
                if (lhs->kind == E_IDENT && is_owner(value_type(lhs)))
                    set_moved(lhs->text, false);
            }
            reject_template_escape(lhs, e->b, t->pos);
            /* z += w with an operator a struct defines is z = z + w (#42) */
            if (strlen(e->op) == 2 && e->op[1] == '=' && strchr("+-*/%", e->op[0])) {
                Expr *bin = new_expr(E_BINARY, t->pos);
                bin->op = strfmt("%c", e->op[0]);
                bin->a = lhs;
                bin->b = e->b;
                Expr *call = resolve_operator(bin, bin->op, lhs, e->b);
                if (call != bin) {
                    if (!repeatable(lhs))
                        error_at(lhs->pos, "with an operator a struct defines, 'x %s y' is 'x = x %s y', which evaluates "
                                           "x twice, so x may not hold a call",
                                 e->op, bin->op);
                    e->op = "=";
                    e->b = call;
                }
            }
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
/* An initializer, for a value of type t when kelvinc sees it (NULL
   otherwise). A list's items take the types of an array's elements or of
   a Kelvin struct's members, so that `{ $0 < $1 }` for a member of a
   function type is an anonymous function of that type (#32). */
static Expr *parse_initializer_for(Type *t) {
    Token *open = peek();
    if (is_p(open, "{") && t && t->kind == T_FUNC) {
        fn_at = cur; /* a member or variable of a function type (#32) */
        fn_type = t;
        return parse_assign();
    }
    if (signature_ahead(cur))
        return parse_assign(); /* { (a:i32):i32 in ... } (#32) */
    bool bracket = is_p(open, "[") && !zero_array_ahead(cur);
    if (is_p(open, "$") && is_p(peek2(), "[") && t && (is_array_owner(t) || is_dict_owner(t))) {
        /* $[...] of the declared Array or Dictionary type (#62, #65) */
        Token *d = advance();
        return array_of_list(d, t);
    }
    if (!bracket && !is_p(open, "{"))
        return parse_assign();
    if (!bracket && tagged_record(t)) /* {.n = 1.5} of an enum with values (#61) */
        return parse_case_initializer(t, tagged_record(t));
    /* an array is initialized with [...], a struct or union with {...}
       (#48); where only C sees the type, either is C's { } */
    Decl *record = NULL;
    char c = t && t->kind == T_BASE ? type_class(t, &record) : 0;
    if (bracket && t && t->kind != T_ARRAY && (t->kind != T_BASE || c != 'u'))
        error_at(open->pos, "'[...]' initializes an array, and this is %s: %s", kelvin_type(t),
                 c == 's' || c == 'c' ? "a struct or union is initialized with '{...}'" : "write a value");
    if (!bracket && t && t->kind == T_ARRAY)
        error_at(open->pos, "an array is initialized with '[...]', not '{...}' (#48)");
    if (c != 's')
        record = NULL;
    advance();
    bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
    brace_ends_condition = brace_in_for = false; /* a `{` inside is never a body */
    init_depth++;
    Expr *e = new_expr(E_INIT, open->pos);
    int next = 0;      /* the member of the next item without a designator */
    bool lost = false; /* C's current object is inside a member, which kelvinc does not follow */
    while (!is_p(peek(), bracket ? "]" : "}")) {
        Expr *d = NULL;
        Type *dt = t; /* the type that the designators reach */
        int links = 0;
        /* an item that starts with `[` is a nested array unless `=`
           follows the group: a designator, [2] = 5 (#48) */
        while (is_p(peek(), ".") || (is_p(peek(), "[") && is_p(&toks[skip_group(cur)], "="))) {
            links++;
            Token *tok = advance();
            Expr *x = new_expr(is_p(tok, ".") ? E_FIELD : E_INDEX, tok->pos);
            x->a = d;
            if (x->kind == E_FIELD) {
                /* cstr and the converters' names are keywords, but may be a
                   C struct's fields (#36) */
                x->text = is_kw(peek(), "cstr") || is_converter(peek()) ? advance()->text : expect_ident("a member name");
                Decl *r = NULL;
                Type *member = NULL;
                if (dt && dt->kind == T_BASE && type_class(dt, &r) == 's') {
                    for (int i = 0; i < r->members.len; i++) {
                        Var *m = r->members.data[i];
                        if (!strcmp(m->name, x->text)) {
                            member = m->type;
                            if (!d && r == record)
                                next = i;
                        }
                    }
                }
                dt = member;
            } else {
                x->b = parse_conditional();
                expect_p("]");
                dt = dt && dt->kind == T_ARRAY ? dt->elem : NULL;
            }
            d = x;
        }
        if (links == 1)
            lost = false; /* a designator of a member of t starts over */
        Type *item = d                                ? dt
                     : lost                           ? NULL
                     : t && t->kind == T_ARRAY        ? t->elem
                     : record && next < record->members.len ? ((Var *)record->members.data[next])->type
                                                      : NULL;
        if (d)
            expect_p("=");
        bool braced = is_p(peek(), "{") || is_p(peek(), "[");
        Expr *value = drop_cstr(parse_initializer_for(item), item); /* a cstr into a u8^ member (#52) */
        reject_owner_copy(value, item, value->pos);
        /* After `.a.f = ...`, or a struct or array member given a value
           that does not fill it, C goes on inside that member (brace
           elision), which kelvinc does not follow. A string fills an
           array of u8 or i8, and a value of the struct's own type fills
           a struct; a C typedef member is taken as a scalar. */
        Decl *r;
        char c = item && item->kind == T_BASE ? type_class(item, &r) : 0;
        Type *vt = braced ? NULL : value_type(value);
        bool fills = braced || (item && item->kind == T_ARRAY && value->kind == E_STRING) ||
                     (vt && vt->kind == T_BASE && item && item->kind == T_BASE && !strcmp(vt->name, item->name));
        if (links > 1 || (!fills && item && (item->kind == T_ARRAY || c == 's' || c == 'c')))
            lost = true;
        list_push(&e->designators, d);
        list_push(&e->items, value);
        next++;
        if (!accept_p(","))
            break;
    }
    init_depth--;
    brace_ends_condition = saved_brace;
    brace_in_for = saved_for;
    expect_p(bracket ? "]" : "}");
    e->bracket = bracket;
    return e;
}

static Expr *parse_initializer(void) { return parse_initializer_for(NULL); }

/* ---------- declarations shared by statements and top level ---------- */

/* The Kelvin type of a number literal: an integer literal is i64 and a
   floating literal is f64 (optionally negated). NULL otherwise. */
static const char *literal_type(Expr *e) {
    if (e->kind == E_PREFIX && (!strcmp(e->op, "-") || !strcmp(e->op, "+")))
        return literal_type(e->a);
    if (e->kind != E_LITERAL || e->text[0] == '\'' || !strcmp(e->text, "true") || !strcmp(e->text, "false") ||
        !strcmp(e->text, "nullptr"))
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

/* ---------- Array<T> (#57): a growable array of T, an owner ---------- */

/* the <T> of Array<T>: a value type that owns nothing, for now */
static Type *parse_array_elem(void) {
    if (!accept_p("<"))
        error_at(peek()->pos, "an Array names its element type: Array<T>");
    Type *elem = parse_type_in(TYPE_DECL);
    if (is_p(peek(), ">>")) /* Array<Array<T>>: >> closes two */
        toks[cur].text = ">";
    else if (!accept_p(">"))
        error_at(peek()->pos, "expected '>' after the element type of Array<T>");
    check_array_elem(elem);
    return elem;
}

/* Array([a, b, c]) (#58): the elements written, each as a fixed array's
   initializer item; a [...] among them is an Array in turn, so that
   Array([[0], [1, 2]]) is an Array<Array<i64>>. at is the Array's type
   when written, else it is inferred from the elements as a variable's
   type is (#47, #48). The C is a compound literal of the elements and
   their count, through A_from, which takes their bytes: an owner
   written there is moved in. */
/* Does the [...] at i hold a `:` at its top level that is no ?:'s, so that
   it is a Dictionary's entries (#65)? */
static bool list_is_dict(int i) {
    int end = skip_group(i), depth = 0, q = 0;
    for (int k = i + 1; k < end - 1; k++) {
        if (is_p(&toks[k], "(") || is_p(&toks[k], "[") || is_p(&toks[k], "{"))
            depth++;
        else if (is_p(&toks[k], ")") || is_p(&toks[k], "]") || is_p(&toks[k], "}"))
            depth--;
        else if (depth == 0 && is_p(&toks[k], "?"))
            q++;
        else if (depth == 0 && is_p(&toks[k], ":") && q > 0)
            q--;
        else if (depth == 0 && is_p(&toks[k], ":"))
            return true;
    }
    return false;
}

static Expr *array_of_list(Token *t, Type *at) {
    if ((at && is_dict_owner(at)) || (!at && list_is_dict(cur))) /* [k: v, ...] of a Dictionary (#65) */
        return dict_of_list(t, at, NULL, NULL);
    Token *open = expect_p("[");
    Type *elem = at ? at->elem : NULL;
    Expr *list = new_expr(E_INIT, open->pos);
    list->bracket = true;
    init_depth++;
    while (!is_p(peek(), "]")) {
        if (is_p(peek(), ".") || (is_p(peek(), "[") && is_p(&toks[skip_group(cur)], "=")))
            error_at(peek()->pos, "the elements of an Array are written in order, without designators");
        Expr *x;
        if (is_p(peek(), "[")) {
            if (at && !is_array_owner(elem))
                error_at(peek()->pos, "'[...]' here makes an Array, and an element of %s is %s", kelvin_type(at),
                         kelvin_type(elem));
            x = array_of_list(t, at ? elem : NULL);
        } else {
            x = drop_cstr(parse_initializer_for(elem), elem); /* a cstr into a u8^ element (#52) */
            reject_owner_copy(x, elem, x->pos);
        }
        list_push(&list->designators, NULL);
        list_push(&list->items, x);
        if (!accept_p(","))
            break;
    }
    init_depth--;
    expect_p("]");
    if (!at) {
        if (!list->items.len)
            error_at(open->pos, "Array([]) has no element type: write Array<T>()");
        Type *lt = list_type(list, open->pos);
        if (!lt)
            error_at(open->pos, "the elements have no one type kelvinc sees here: write Array<T>([...])");
        check_array_elem(lt->elem);
        at = array_type(t, lt->elem);
        elem = lt->elem;
        for (int i = 0; i < list->items.len; i++)
            reject_owner_copy(list->items.data[i], elem, ((Expr *)list->items.data[i])->pos);
    }
    Expr *e = new_expr(E_CALL, t->pos);
    e->a = new_expr(E_IDENT, t->pos);
    e->a->text = "Array";
    e->op = "array";
    e->type = at;
    if (!list->items.len)
        return e; /* Array<T>([]) is empty */
    Type *fixed = xcalloc(1, sizeof *fixed);
    fixed->kind = T_ARRAY;
    fixed->pos = open->pos;
    fixed->elem = elem;
    fixed->size = new_expr(E_LITERAL, open->pos);
    fixed->size->text = strfmt("%d", list->items.len);
    Expr *c = new_expr(E_COMPOUND, open->pos);
    c->type = fixed;
    c->a = list;
    list_push(&e->items, c);
    e->text = "list";
    return e;
}

/* what may be an element of an Array (#57) */
static void check_array_elem(Type *elem) {
    if (elem->kind == T_ARRAY || (elem->kind == T_BASE && !strcmp(elem->name, "any")))
        error_at(elem->pos, "an Array of %s is not here yet: an element is a value C returns", kelvin_type(elem));
}

/* the inside of $[...] that spells t: [T] for an Array<T>, else T */
static char *dollar_spelling(Type *t) {
    if (is_dict_owner(t))
        return strfmt("[%s: %s]", kelvin_type(t->key), dollar_spelling(t->elem));
    return is_array_owner(t) ? strfmt("[%s]", dollar_spelling(t->elem)) : kelvin_type(t);
}

/* $[T] (#64): Array<T>; a [...] inside is an Array in turn, as it is in
   $[[1, 0], [0, 1]], so $[[i64]] is Array<Array<i64>> */
static Type *parse_dollar_array(Token *at) {
    expect_p("[");
    Type *elem = is_p(peek(), "[") ? parse_dollar_array(peek()) : parse_type_in(TYPE_DECL);
    if (accept_p(":")) { /* $[K: V] is Dictionary<K, V> (#65) */
        Type *val = is_p(peek(), "[") ? parse_dollar_array(peek()) : parse_type_in(TYPE_DECL);
        if (is_p(peek(), "("))
            error_at(peek()->pos, "an Array grows, and has no count in its type: write $[%s: %s], and give the "
                                  "elements or a count where it is made",
                     kelvin_type(elem), dollar_spelling(val));
        expect_p("]");
        return dict_type(at, elem, val);
    }
    if (is_p(peek(), "("))
        error_at(peek()->pos, "an Array grows, and has no count in its type: write $[%s], and give the elements "
                              "or a count where it is made",
                 dollar_spelling(elem));
    expect_p("]");
    check_array_elem(elem);
    return array_type(at, elem);
}

/* Array<T> as a type: a T_BASE named by its element, with its C name,
   recorded once per program in the order of first use, with the
   top-level declaration that first uses it, where its C is emitted */
static Type *array_type(Token *at, Type *elem) {
    Type *t = xcalloc(1, sizeof *t);
    t->kind = T_BASE;
    t->pos = at->pos;
    t->elem = elem;
    t->name = strfmt("Array<%s>", kelvin_type(elem));
    t->cname = strfmt("_kv_array_%s", mangled_type(elem));
    for (int i = 0; i < program->arrays.len; i++)
        if (!strcmp(((Type *)program->arrays.data[i])->name, t->name))
            return t;
    list_push(&program->arrays, t);
    list_push(&program->array_decls, (void *)(intptr_t)program->decls.len);
    return t;
}

static bool is_array_owner(Type *t) {
    if (t && t->kind == T_TYPEOF)
        t = t->elem;
    return t && t->kind == T_BASE && t->cname && !strncmp(t->name, "Array<", 6);
}

/* ---------- Dictionary<K, V> (#65) ---------- */

static bool is_dict_owner(Type *t) {
    if (t && t->kind == T_TYPEOF)
        t = t->elem;
    return t && t->kind == T_BASE && t->cname && !strncmp(t->name, "Dictionary<", 11);
}

/* a key is an integer (hashed as a number) or a String (the text, kept
   as a copy, read with a cstr or a String) */
static void check_dict_key(Type *key) {
    static const char *ints[] = {"i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", NULL};
    if (is_cstr(key))
        error_at(key->pos, "a key of a Dictionary is a String, not a cstr: the Dictionary keeps a copy of the text, "
                           "and is read with a cstr or a String");
    if (is_string(key))
        return;
    for (int i = 0; key->kind == T_BASE && ints[i]; i++)
        if (!strcmp(key->name, ints[i]))
            return;
    error_at(key->pos, "a key of a Dictionary is an integer or a String, not %s", kelvin_type(key));
}

/* Dictionary<K, V> as a type: a T_BASE named by both, with its C name,
   recorded with the Arrays, in order of first use, for its C (#57) */
static Type *dict_type(Token *at, Type *key, Type *val) {
    check_dict_key(key);
    check_array_elem(val);
    Type *t = xcalloc(1, sizeof *t);
    t->kind = T_BASE;
    t->pos = at->pos;
    t->key = key;
    t->elem = val;
    t->name = strfmt("Dictionary<%s, %s>", kelvin_type(key), kelvin_type(val));
    t->cname = strfmt("_kv_dict_%s_%s", mangled_type(key), mangled_type(val));
    for (int i = 0; i < program->arrays.len; i++)
        if (!strcmp(((Type *)program->arrays.data[i])->name, t->name))
            return t;
    list_push(&program->arrays, t);
    list_push(&program->array_decls, (void *)(intptr_t)program->decls.len);
    return t;
}

static Type *parse_dict_types(Token *kw) {
    if (!accept_p("<"))
        error_at(peek()->pos, "a Dictionary names its key and value types: Dictionary<K, V>");
    Type *key = parse_type_in(TYPE_DECL);
    if (!accept_p(","))
        error_at(peek()->pos, "expected ',' between the key and value types of Dictionary<K, V>");
    Type *val = parse_type_in(TYPE_DECL);
    if (is_p(peek(), ">>")) /* Dictionary<K, Array<T>>: >> closes two */
        toks[cur].text = ">";
    else if (!accept_p(">"))
        error_at(peek()->pos, "expected '>' after the value type of Dictionary<K, V>");
    return dict_type(kw, key, val);
}

/* the key given to a Dictionary: text for String keys (a cstr, a template,
   or a String's text), an integer otherwise */
static Expr *dict_key(Expr *k, Type *dt) {
    Type *kt = value_type(k);
    if (is_string(dt->key)) {
        if (is_string(kt))
            return property(k, &(Token){.kind = TK_IDENT, .pos = k->pos, .text = "cstr"}, "cstr");
        if (k->kind == E_STRING || k->kind == E_TEMPLATE || is_cstr(kt) ||
            (kt && kt->kind == T_PTR && kt->elem->kind == T_BASE &&
             (!strcmp(kt->elem->name, "u8") || !strcmp(kt->elem->name, "i8"))))
            return k;
        error_at(k->pos, "a key of %s is text: a cstr, a template, or a String", kelvin_type(dt));
    }
    Decl *r;
    char c = expr_class(k, &r);
    if (c != 'i' && c != 'u')
        error_at(k->pos, "a key of %s is an integer%s", kelvin_type(dt), kt ? strfmt(", not %s", kelvin_type(kt)) : "");
    return k;
}

/* $[k: v, ...] and Dictionary<K, V>([k: v, ...]) (#65): the entries
   written; K and V inferred from the first entry as a variable's type
   is, every other entry alike, or given. The C sets each entry into an
   empty Dictionary; a value that owns is moved in */
static Expr *dict_of_list(Token *t, Type *dt, Token *open, Expr *first) {
    bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
    brace_ends_condition = brace_in_for = false;
    init_depth++;
    if (!open)
        open = expect_p("[");
    Expr *e = new_expr(E_CALL, t->pos);
    e->a = new_expr(E_IDENT, t->pos);
    e->a->text = "Dictionary";
    e->op = "dict";
    e->text = "list";
    e->type = dt;
    if (!first && accept_p(":")) { /* $[:]: empty */
        if (!dt)
            error_at(open->pos, "$[:] has no key and value types here: write Dictionary<K, V>(), or give the "
                                "variable a type, as in 'var d:$[String: i64] = $[:]'");
        expect_p("]");
        e->text = "";
        init_depth--;
        brace_ends_condition = saved_brace;
        brace_in_for = saved_for;
        return e;
    }
    Type *kt = dt ? dt->key : NULL, *vt = dt ? dt->elem : NULL;
    bool saved_annotation = ident_annotation_ok;
    for (Expr *k = first;; k = NULL) {
        if (!k) {
            if (is_p(peek(), "]"))
                break;
            ident_annotation_ok = false; /* the `:` after a key is the entry's */
            k = parse_assign();
            ident_annotation_ok = saved_annotation;
        }
        if (!accept_p(":"))
            error_at(peek()->pos, "an entry of a Dictionary is written key: value");
        Expr *v = is_p(peek(), "[") ? array_of_list(t, vt) : drop_cstr(parse_initializer_for(vt), vt);
        if (!dt) {
            Type *k0 = inferred_type(k, k->pos), *v0 = inferred_type(v, v->pos);
            if (k0 && is_cstr(k0))
                k0 = base_type("String", k->pos);
            if (!kt) {
                if (!k0 || !v0)
                    error_at(k->pos, "the %s of this entry has no type kelvinc sees: write Dictionary<K, V>([...])",
                             k0 ? "value" : "key");
                kt = k0;
                vt = v0;
            } else if (!k0 || strcmp(kelvin_type(k0), kelvin_type(kt))) {
                error_at(k->pos, "every key of a Dictionary has one type: this one is %s, the first %s",
                         k0 ? kelvin_type(k0) : "unseen", kelvin_type(kt));
            } else if (!v0 || strcmp(kelvin_type(v0), kelvin_type(vt))) {
                error_at(v->pos, "every value of a Dictionary has one type: this one is %s, the first %s",
                         v0 ? kelvin_type(v0) : "unseen", kelvin_type(vt));
            }
        }
        reject_owner_copy(v, vt, v->pos);
        reject_record_mismatch(v, vt, v->pos);
        list_push(&e->designators, k);
        list_push(&e->items, v);
        if (!accept_p(","))
            break;
    }
    expect_p("]");
    if (!dt)
        dt = e->type = dict_type(t, kt, vt);
    for (int i = 0; i < e->designators.len; i++)
        e->designators.data[i] = dict_key(e->designators.data[i], dt);
    init_depth--;
    brace_ends_condition = saved_brace;
    brace_in_for = saved_for;
    return e;
}

/* cstr (#52): a pointer to const u8 that kelvinc knows as text */
static Type *cstr_type(Pos pos) {
    Type *p = xcalloc(1, sizeof *p);
    p->kind = T_PTR;
    p->pos = pos;
    p->cstr = true;
    p->elem = base_type("u8", pos);
    p->elem->is_const = true;
    return p;
}

static bool is_cstr(Type *t) { return t && t->kind == T_PTR && t->cstr; }

/* ---------- owners (#54): Bytes, and what holds one ---------- */

static bool is_bytes(Type *t) {
    if (t && t->kind == T_TYPEOF)
        t = t->elem;
    return t && t->kind == T_BASE && !strcmp(t->name, "Bytes");
}

/* uchr (#56): a codepoint on the stack, shown as its UTF-8 */
static bool is_uchr(Type *t) {
    if (t && t->kind == T_TYPEOF)
        t = t->elem;
    return t && t->kind == T_BASE && !strcmp(t->name, "uchr");
}

/* c.utf32, a u32 (#56) */
static Expr *utf32_of(Expr *c) {
    Expr *x = new_expr(E_PROPERTY, c->pos);
    x->a = c;
    x->text = "utf32";
    x->op = "uchr";
    return x;
}

static bool is_string(Type *t) {
    if (t && t->kind == T_TYPEOF)
        t = t->elem;
    return t && t->kind == T_BASE && !strcmp(t->name, "String");
}

/* "bytes" or "string" for the built-in owners, NULL otherwise */
static const char *builtin_owner(Type *t) {
    return is_bytes(t) ? "bytes" : is_string(t) ? "string" : is_array_owner(t) ? "array" : is_dict_owner(t) ? "dict" : NULL;
}

/* An owner: a Bytes, a String, a Kelvin struct with an owner member, or an
   array of owners. A variable owns one, and its block frees it. */
static bool is_owner(Type *t) {
    if (!t)
        return false;
    if (t->kind == T_TYPEOF)
        return is_owner(t->elem);
    if (t->kind == T_ARRAY)
        return is_owner(t->elem);
    if (t->kind != T_BASE)
        return false;
    if (is_bytes(t) || is_string(t) || is_array_owner(t) || is_dict_owner(t))
        return true;
    Decl *r;
    if (type_class(t, &r) != 's' || !r)
        return false;
    for (int i = 0; i < r->members.len; i++)
        if (((Var *)r->members.data[i])->type && is_owner(((Var *)r->members.data[i])->type))
            return true;
    return false;
}

/* What append and insert take (#54, #55): a byte or a codepoint, text, a
   borrow of the same kind, or a value of it that an expression gives; an
   owner's place would be a copy, and a borrow of the other kind is read
   through its text or its bytes */
static void check_appended(Expr *given, const char *kind, const char *what) {
    const char *name = given->kind == E_IDENT ? given->text : "...";
    if (owner_place(given))
        error_at(given->pos, "'%s' of an owner would copy it: give a borrow, '&%s', or a copy, '%s.copy()'", what,
                 name, name);
    Type *t = value_type(given);
    Type *to = t && t->kind == T_PTR ? t->elem : NULL;
    const char *b = given->kind == E_PREFIX && given->a->kind == E_IDENT ? given->a->text : "b";
    if (to && is_bytes(to) && kind[0] == 's')
        error_at(given->pos, "a String takes text, not a borrow of a Bytes, which may not be UTF-8: give "
                             "'%s.string()', or '%s.cstr' up to a NUL",
                 b, b);
    if (to && is_string(to) && kind[0] == 'b')
        error_at(given->pos, "a Bytes takes bytes: give the String's bytes, 's.bytes'");
}

/* xs.append(x) (#57): an element, a borrow of an Array of the same
   elements (its elements are appended), or an Array an expression gives
   (appended and freed) */
static const char *array_append_kind(Expr *given, Type *array) {
    Type *t = value_type(given);
    if (t && t->kind == T_PTR && is_array_owner(t->elem) && !strcmp(t->elem->name, array->name))
        return "append_ref";
    if (is_array_owner(t) && !owner_place(given) && !strcmp(t->name, array->name))
        return "append_owned";
    return "append";
}

/* a place that owns: a variable, a field, an element, p^ */
static bool owner_place(Expr *e) {
    return is_owner(value_type(e)) &&
           (e->kind == E_IDENT || e->kind == E_FIELD || e->kind == E_INDEX || e->kind == E_DEREF);
}

/* an owner is never copied by = (O3): a place of an owner type may not
   initialize or be assigned to another; a value an expression gives moves */
static void reject_owner_copy(Expr *value, Type *target, Pos pos) {
    if (!is_owner(target) || !owner_place(value))
        return;
    char *what = value->kind == E_IDENT ? strfmt("'%s'", value->text) : "it";
    error_at(pos, "an owner is not copied by '=' (#54): copy its bytes with %s.copy(), or borrow it with ':= &%s'",
             what, value->kind == E_IDENT ? value->text : "...");
}

/* a struct or union takes a value of its own type: where kelvinc sees
   both as Kelvin records and they differ, it says so, as C's message
   would name the C struct, _kv_anonN for one with no tag (#59) */
static void reject_record_mismatch(Expr *value, Type *target, Pos pos) {
    Decl *rt, *rv;
    Type *vt = value_type(value);
    if (!target || target->kind != T_BASE || !vt || vt->kind != T_BASE)
        return;
    char ct = type_class(target, &rt), cv = type_class(vt, &rv);
    if ((ct != 's' && ct != 'c') || (cv != 's' && cv != 'c') || !rt || !rv || rt == rv)
        return;
    bare_tags = true;
    char *want = kelvin_type(unqualified(target)), *got = kelvin_type(unqualified(vt));
    bare_tags = false;
    error_at(pos, "%s is not %s: a %s takes a value of its own type%s", got, want, ct == 's' ? "struct" : "union",
             rt->spelling || rv->spelling ? ", and two structs with no tag are one type only when their members are "
                                            "written alike"
                                          : "");
}

static bool is_moved(const char *name) {
    int i = binding_index(name);
    return i >= 0 && scope_moved.data[i];
}

static void set_moved(const char *name, bool moved) {
    int i = binding_index(name);
    if (i >= 0)
        scope_moved.data[i] = (void *)(intptr_t)moved;
}

/* passing an owner by value moves it (O5): a local variable's name may
   be given, and is dead afterwards; a field or an element cannot be */
static void move_argument(Expr *arg, Type *param, const char *what) {
    if (!is_owner(param) || !is_owner(value_type(arg)))
        return;
    if (arg->kind == E_IDENT) {
        int i = binding_index(arg->text);
        int globals = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
        if (let_kind(arg->text) == LET_EACH)
            error_at(arg->pos, "'%s' is each element in turn, which its Array owns: pass a borrow, '&%s', or a copy",
                     arg->text, arg->text);
        if (i >= globals) {
            set_moved(arg->text, true);
            return;
        }
        error_at(arg->pos, "'%s' is a global owner, which cannot move into %s: pass a borrow, '&%s', or a copy",
                 arg->text, what, arg->text);
    }
    if (owner_place(arg))
        error_at(arg->pos, "an owner moves into %s only as a whole variable: pass a borrow, '&...', or a copy", what);
}

/* An implicit drop of a cstr's immutability (#52): where a u8^ (to u8
   that is not const) is declared, assigned or passed from a cstr value,
   kelvinc writes the cast, as `v as u8^` would */
static Expr *drop_cstr(Expr *v, Type *target) {
    if (!v || !target || target->kind != T_PTR || target->cstr || target->elem->kind != T_BASE ||
        strcmp(target->elem->name, "u8") || target->elem->is_const || !is_cstr(value_type(v)))
        return v;
    Expr *c = new_expr(E_CAST, v->pos);
    c->op = "as";
    c->a = v;
    c->type = target;
    return c;
}

/* The type of an initializer when none is written: an integer literal is
   an i64, a floating literal an f64, nullptr is an any^, and `v:T`,
   `v as T` or `T(v)` is a T. A bool is a bool (#24, #25): `true`, a
   comparison, &&, || and !, and any value kelvinc sees is a bool, such as
   a bool variable or a Kelvin function's bool result. Any other value
   whose type kelvinc sees has that type (#47). NULL otherwise. */
static Type *arg_type(Expr *e);
static Type *inferred_type(Expr *e, Pos pos);

/* T[] with [a, b, ...] is T[N] (#48): the length is the items' count,
   where none is designated, so that kelvinc knows it, as for T[N] */
static void count_items(Type *t, Expr *init) {
    if (!t || t->kind != T_ARRAY || !init || init->kind != E_INIT || !init->bracket)
        return;
    for (int i = 0; i < init->designators.len; i++)
        if (init->designators.data[i])
            return;
    if (!t->size) {
        t->size = new_expr(E_LITERAL, init->pos);
        t->size->text = strfmt("%d", init->items.len);
    }
    /* the rows of [[T]] count alike, as C needs every inner count: the
       first row's, which every row must match */
    if (t->elem->kind == T_ARRAY && !t->elem->size && init->items.len) {
        Expr *first = init->items.data[0];
        if (first->kind != E_INIT || !first->bracket)
            error_at(first->pos, "the rows of an array of arrays are written [...], or their count is written in "
                                 "the type, as in '[[T](n)]'");
        count_items(t->elem, first);
        for (int i = 1; i < init->items.len; i++) {
            Expr *row = init->items.data[i];
            if (row->kind != E_INIT || !row->bracket || row->items.len != first->items.len)
                error_at(row->pos, "every row of an array of arrays has the count of the first, %d, which C needs "
                                   "in the type",
                         first->items.len);
        }
    }
}

/* The type of [a, b, ...] (#48): T[N] where every item is a T kelvinc
   sees (a literal, a bool, a seen value, or a nested list of one type),
   none designated; NULL otherwise */
static Type *list_type(Expr *e, Pos pos) {
    if (!e->bracket || !e->items.len)
        return NULL;
    Type *elem = NULL;
    for (int i = 0; i < e->items.len; i++) {
        if (e->designators.data[i])
            return NULL;
        Expr *x = e->items.data[i];
        Type *t = x->kind == E_INIT ? list_type(x, pos) : inferred_type(x, pos);
        if (!t || (elem && strcmp(kelvin_type(elem), kelvin_type(t))))
            return NULL;
        elem = elem ? elem : t;
    }
    Type *a = xcalloc(1, sizeof *a);
    a->kind = T_ARRAY;
    a->pos = pos;
    a->elem = elem;
    a->size = new_expr(E_LITERAL, pos);
    a->size->text = strfmt("%d", e->items.len);
    return a;
}

static Type *inferred_type(Expr *e, Pos pos) {
    if (e->kind == E_INIT)
        return list_type(e, pos);
    if (e->kind == E_STRING) /* a string literal is a cstr (#52) */
        return cstr_type(pos);
    if (e->kind == E_FUNC && has_local_size(e->type))
        return NULL; /* a length that names a parameter needs a written type */
    if (e->kind == E_CAST || e->kind == E_FUNC)
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
    if (lit)
        return base_type(lit, pos);
    /* any other value whose type kelvinc sees (#47): a Kelvin function's
       or method's result, a variable, a field, p^, a[i], &x, a compound
       literal, a template's text; but not arithmetic, whose type is C's
       promotion of its operands, and not what only C sees */
    if (e->kind == E_BINARY || e->kind == E_POSTFIX || (e->kind == E_PREFIX && strcmp(e->op, "&")))
        return NULL;
    /* as overloading sees it (#41): &x of a let points to const, a character
       is a u8, an enumerator its enum, sizeof a size_t; a ?: only between
       two values of one type */
    Type *t = e->kind == E_TERNARY ? value_type(e) : arg_type(e);
    if (t && t->kind == T_ARRAY && e->kind == E_COMPOUND)
        return t; /* ([i32])[1, 2, 3] and [T](n) declare the array itself (#49) */
    if (t && t->kind == T_ARRAY) { /* an array is not copied: the pointer C makes of it */
        Type *p = xcalloc(1, sizeof *p);
        p->kind = T_PTR;
        p->pos = pos;
        p->elem = t->elem;
        return p;
    }
    return t;
}

/* name: type [= init], or (for variables) name = init with the type
   inferred from init */
/* names starting with _kv_ are kelvinc's, in the C it writes (#32, #38),
   and kv_ ones its runtime's */
static void reject_kv_name(Token *t) {
    if (t->kind == TK_IDENT && !strncmp(t->text, "_kv_", 4))
        error_at(t->pos, "names starting with _kv_ are kelvinc's own, in the C it writes: rename '%s'", t->text);
    if (t->kind == TK_IDENT && (!strncmp(t->text, "kv_", 3) || !strncmp(t->text, "KV_", 3) ||
                                !strcmp(t->text, "KELVIN_PRELUDE_H")))
        error_at(t->pos, "names starting with kv_ or KV_ are kelvinc's runtime's: rename '%s'", t->text);
}

/* [T](n) of a count C computes at run time is a VLA that is zero-filled
   after its declaration, which a let, const in C, cannot be (#49) */
/* an array of owners, as a variable, waits for its own change (#54) */
static void reject_owner_array(Var *v) {
    if (v->type && v->type->kind == T_ARRAY && is_owner(v->type->elem))
        error_at(v->pos, "an array of owners is not here yet: a struct may hold them");
}

static void reject_owner_array(Var *v);
static void reject_let_vla(Var *v, int let) {
    Expr *z = v->init;
    if (let && z && z->kind == E_COMPOUND && !z->a && v->type && v->type->kind == T_ARRAY && v->type->size &&
        v->type->size->kind != E_LITERAL)
        error_at(v->pos, "'%s' is a let of a count computed at run time, which C cannot fill: write 'var %s'", v->name,
                 v->name);
}

static Var *parse_var(bool with_init, int let) {
    Var *v = xcalloc(1, sizeof *v);
    v->pos = peek()->pos;
    reject_kv_name(peek());
    v->name = expect_ident("a name");
    char *what = strfmt("'%s'", v->name);
    if (with_init && (is_p(peek(), "=") || is_p(peek(), ":="))) {
        Token *op = advance();
        /* in scope from here, as in C, so the initializer sees it, as in
           `let point: i16 = sizeof(point)`; its type is filled in below */
        declare_binding(v->name, NULL, let);
        v->init = parse_initializer();
        v->type = inferred_type(v->init, v->pos);
        reject_let_vla(v, let);
        reject_owner_copy(v->init, v->type, v->init->pos);
        reject_owner_array(v);
        scope_types.data[scope_types.len - 1] = v->type;
        if (!v->type && v->init->kind == E_FUNC)
            error_at(v->pos, "'%s' needs a type: in %s, an array length names a parameter, which a function type "
                             "cannot carry; write a type without it, as in a pointer",
                     v->name, kelvin_type(v->init->type));
        if (!v->type)
            error_at(v->pos,
                     "'%s' needs a type: write '%s:T = ...' (or '%s:T := ...' for a reference); Kelvin infers a type "
                     "from literals, bools, values written 'v:T', 'v as T' or 'T(v)', anonymous functions that write "
                     "their parameters, and values whose type it sees, not from arithmetic or what only C sees",
                     v->name, v->name, v->name);
        check_assign_op(op->text, v->type, what, op->pos, v->init);
        return v;
    }
    expect_p(":");
    v->type = parse_type();
    if (with_init) /* a declaration: in scope before its initializer */
        declare_binding(v->name, v->type, let);
    if (with_init)
        reject_owner_array(v);
    if (with_init && (is_p(peek(), "=") || is_p(peek(), ":="))) {
        Token *op = advance();
        check_assign_op(op->text, v->type, what, op->pos, NULL);
        /* a function type types an anonymous function (#32) */
        v->init = parse_initializer_for(v->type);
        count_items(v->type, v->init);
        reject_let_vla(v, let);
        v->init = drop_cstr(v->init, v->type);
        reject_owner_copy(v->init, v->type, v->init->pos);
        reject_record_mismatch(v->init, v->type, v->init->pos);
        reject_owner_array(v);
        pick_overload(v->init, v->type);
    }
    return v;
}

/* let|var name[: type] [= or := init] {, ...} (#27): each name is in
   scope after its declarator. A let is C's const, so it needs a value,
   except in an extern declaration. */
static void parse_var_one(List *out, bool is_let, const char *storage) {
    Var *v = parse_var(true, is_let ? LET_VALUE : LET_NONE); /* declares it */
    v->is_let = is_let;
    if (is_let && !v->init && !(storage && !strcmp(storage, "extern")))
        error_at(v->pos, "a let needs a value: write 'let %s = ...', or 'var %s' if it changes later", v->name,
                 v->name);
    list_push(out, v);
}

static void parse_var_list(List *out, bool is_let, const char *storage) {
    do
        parse_var_one(out, is_let, storage);
    while (accept_p(","));
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
/* C's `T (*name)(...)` or `T *(*name)(...)` at token i: a pointer to a
   function, which Kelvin writes `name:(...):T` (#31); `how` is "var "
   where a declaration starts with var */
static void reject_c_fn_pointer(int i, const char *how) {
    int k = i;
    while (is_qualifier(&toks[k]))
        k++;
    if (is_kw(&toks[k], "struct") || is_kw(&toks[k], "union") || is_kw(&toks[k], "enum"))
        k++;
    if ((toks[k].kind != TK_IDENT && !is_base_word(&toks[k])) || kelvin_for_c_word(&toks[k]))
        return;
    const char *type = toks[k++].text;
    Buf stars = {0};
    buf_puts(&stars, "");
    for (; is_p(&toks[k], "*"); k++)
        buf_puts(&stars, "^");
    if (is_p(&toks[k], "(") && is_p(&toks[k + 1], "*") && toks[k + 2].kind == TK_IDENT && is_p(&toks[k + 3], ")") &&
        is_p(&toks[k + 4], "("))
        error_at(toks[i].pos, "'%s' looks like a C function-pointer declaration: write '%s%s:(...):%s%s' (#31)",
                 toks[k + 2].text, how, toks[k + 2].text, type, stars.buf);
}

/* Does a statement end before token i, which is on a new line and cannot
   go on with it, or is a `}` or the end of the file (#35)? */
static bool statement_ends_at(int i) {
    Token *t = &toks[i];
    if (is_p(t, "}") || t->kind == TK_EOF || t->kind == TK_FILE_END)
        return true;
    return line_break(t - 1, t) && (!continues_expression(t) || (is_p(t, "(") && at_statement_level()));
}

static void reject_c_declaration(void) {
    reject_c_fn_pointer(cur, "var ");
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
    /* T (*f)(...) and T *(*f)(...): a pointer to a function (#31) */
    if (is_p(&toks[i], "(") && is_p(&toks[i + 1], "*") && toks[i + 2].kind == TK_IDENT && is_p(&toks[i + 3], ")") &&
        is_p(&toks[i + 4], "(")) {
        int end = skip_group(i + 4);
        if (is_p(&toks[end], ";") || is_p(&toks[end], ",") || is_p(&toks[end], "="))
            error_at(pos, "'%s' looks like a C function-pointer declaration: write 'var %s:(...):%s%s%s%s' (#31)",
                     toks[i + 2].text, toks[i + 2].text, base_const ? "const " : "", base_volatile ? "volatile " : "",
                     type, suffix.buf);
    }
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
    List dims = {0}; /* each [N] of a C array, as written, for the hint (#49) */
    /* a `(` on the next line starts the next statement (#35) */
    while ((is_p(&toks[i], "(") && !line_break(&toks[i - 1], &toks[i])) || is_p(&toks[i], "[") ||
           is_p(&toks[i], "^")) {
        if (is_p(&toks[i], "^"))
            buf_puts(&suffix, "^");
        if (is_p(&toks[i], "(")) {
            function_pointer = function_pointer || is_p(&toks[i - 1], "^");
            function = true;
        }
        int end = is_p(&toks[i], "^") ? i + 1 : skip_group(i);
        if (is_p(&toks[i], "["))
            list_push(&dims, source_text(i + 1, end - 1));
        i = end;
    }
    /* also `size_t n` at the end of a line or before a `}` (#35) */
    if (!is_p(&toks[i], ";") && !is_p(&toks[i], ",") && !is_p(&toks[i], "=") && !statement_ends_at(i))
        return;
    /* `a * b` and `a ~ b` are expressions where C sees a is no type: a
       Kelvin variable or function (but `a * b = c` is no expression), or
       the one expression a body returns; and where b is declared in this
       block already, C could not declare it again */
    if ((suffix.len || block) && !storage && !base_const && !base_volatile && !strchr(type, ' ') &&
        ((binding_index(type) >= 0 && !is_p(&toks[i], "=")) || returned_statement(cur, i) ||
         (toks[name_at].kind == TK_IDENT && bound_here(toks[name_at].text))))
        return;
    const char *name = toks[name_at].text;
    if (block)
        error_at(pos, "'%s ~ %s' as a statement would be read by C as a block-pointer declaration; "
                      "declarations are written 'var name:type'", type, name);
    char *quals = strfmt("%s%s", base_const ? "const " : "", base_volatile ? "volatile " : "");
    if (function_pointer)
        error_at(pos, "'%s' looks like a C function-pointer declaration: write 'var %s:(...):%s%s' (#31)", name,
                 name, quals, type);
    if (function)
        error_at(pos, "functions are declared at the top level as 'let %s(...):%s%s%s'", name, quals, type, suffix.buf);
    char *spelled = strfmt("%s%s%s", quals, type, suffix.buf);
    for (int k = dims.len - 1; k >= 0; k--) /* int a[2][3] is [[i32](3)](2) (#49) */
        spelled = strfmt("[%s]%s%s%s", spelled, *(char *)dims.data[k] ? "(" : "", (char *)dims.data[k],
                         *(char *)dims.data[k] ? ")" : "");
    error_at(pos, "declarations are written 'var name:type', as in '%s%svar %s:%s'", storage ? storage : "",
             storage ? " " : "", name, spelled);
}

static Stmt *new_stmt(StmtKind kind, Pos pos) {
    Stmt *s = xcalloc(1, sizeof *s);
    s->kind = kind;
    s->pos = pos;
    return s;
}

/* #import, of a C header or a Kelvin file (#40), is for the top level */
static void reject_inner_import(void) {
    if (peek()->kind == TK_IMPORT || peek()->kind == TK_IMPORT_K)
        error_at(peek()->pos, "#import is for the top level of a file, outside functions, structs and blocks");
}

/* the statements of a block whose `{` (t) has been read, and its `}` */
static Stmt *parse_block_rest(Token *t) {
    Stmt *s = new_stmt(S_BLOCK, t->pos);
    open_scope();
    block_depth++;
    while (!is_p(peek(), "}")) {
        if (peek()->kind == TK_EOF || peek()->kind == TK_FILE_END)
            error_at(t->pos, "unterminated block");
        reject_inner_import();
        list_push(&s->stmts, parse_stmt());
    }
    block_depth--;
    close_scope();
    advance();
    return s;
}

static Stmt *parse_block(void) { return parse_block_rest(expect_p("{")); }

/* The end of a statement or a declaration: a `;`, or a new line, a `}`
   or the end of the file after it, as in Swift (#35) */
static void end_statement(void) {
    if (accept_p(";") || is_p(peek(), "}") || peek()->kind == TK_EOF || peek()->kind == TK_FILE_END || newline_before())
        return;
    if (cur == trailing_end)
        error_at(peek()->pos, "expected ';' or a new line after the trailing function, before what follows");
    error_at(peek()->pos, "expected ';' or a new line before %s", desc(peek()));
}

/* ---------- anonymous functions (#32) ---------- */

static Decl *new_decl(DeclKind kind, Pos pos, const char *storage);

static bool is_in(Token *t) { return t->kind == TK_IDENT && !strcmp(t->text, "in"); }

/* the index just past the type that starts at token i, a function type
   included, or -1 */
static int any_type_end(int i) {
    int dot = typeof_at(i);
    if (dot >= 0)
        return type_suffix_end(dot + 2); /* after ':', v.type is the type (#34) */
    if (!is_p(&toks[i], "("))
        return type_shape_end(i);
    int j = skip_group(i);
    return is_p(&toks[j], ":") ? any_type_end(j + 1) : j;
}

/* Does the `{` at token i open an anonymous function that writes its
   parameters, as in `{ (a:i32, b:i32):bool in ... }`? It does when `in`
   follows the parameters and the result type. Without the `in`, the
   shapes (a:T), (var a:T) and () still say so, unless an expression can
   go on there, as in the initializer items `(n:u8):i64,` (n annotated
   twice) and `(n:i64) * 2`. */
static bool signature_ahead(int i) {
    if (!is_p(&toks[i], "{") || !is_p(&toks[i + 1], "("))
        return false;
    int j = skip_group(i + 1);
    if (is_p(&toks[j], ":"))
        j = any_type_end(j + 1);
    if (j < 0)
        return false;
    if (is_in(&toks[j]))
        return true;
    Token *f = &toks[i + 2];
    bool shape = is_p(f, ")") || is_kw(f, "var") || (f->kind == TK_IDENT && is_p(&toks[i + 3], ":"));
    return shape && !continues_expression(&toks[j]) && !is_p(&toks[j], "}") && !is_p(&toks[j], ";");
}

/* the type that argument k of a call to `callee` takes, where kelvinc
   can see it: a Kelvin function's parameter, or a function value's */
static Type *call_param_type(Expr *callee, int k) {
    if (callee->kind == E_IDENT && !lookup_type(callee->text) && function_named(callee->text)) {
        /* the type all the overloads that have parameter k agree on (#41) */
        List all = overloads_of(callee->text, NULL);
        Type *t = NULL;
        for (int i = 0; i < all.len; i++) {
            Decl *f = all.data[i];
            if (k >= f->params.len)
                continue;
            Type *u = ((Var *)f->params.data[k])->type;
            if (t && strcmp(kelvin_type(unqualified(t)), kelvin_type(unqualified(u))))
                return NULL;
            t = u;
        }
        return t;
    }
    Type *t = value_type(callee);
    return t && t->kind == T_FUNC && k < t->params.len ? t->params.data[k] : NULL;
}

/* how many arguments a call to callee takes, where kelvinc sees a
   function that is not variadic; -1 otherwise */
static int call_arity(Expr *callee) {
    if (callee->kind == E_IDENT && !lookup_type(callee->text) && function_named(callee->text)) {
        /* the most any overload takes (#41) */
        List all = overloads_of(callee->text, NULL);
        int n = 0;
        for (int i = 0; i < all.len; i++) {
            Decl *f = all.data[i];
            if (f->variadic)
                return -1;
            n = f->params.len > n ? f->params.len : n;
        }
        return n;
    }
    Type *t = value_type(callee);
    return t && t->kind == T_FUNC && !t->variadic ? t->params.len : -1;
}

/* the method that recv.name(...) calls: the one of recv's type, or when
   kelvinc cannot see that type, the only method so named */
static Decl *method_named(Expr *recv, const char *name) {
    Type *rt = value_type(recv);
    bool seen = rt && rt->kind == T_BASE;
    Decl *found = NULL;
    int n = 0;
    for (int i = 0; i < functions.len; i++) {
        Decl *d = functions.data[i];
        if (!d->recv || strcmp(d->name, name) || (seen && strcmp(d->recv->name, rt->name)))
            continue;
        if (!found || strcmp(found->recv->name, d->recv->name))
            n++; /* a prototype and its definition are one method */
        found = d;
    }
    return n == 1 ? found : NULL;
}

/* print and println cannot show a function (#31) */
static void check_print_args(Expr *call) {
    if (call->a->kind != E_IDENT || (strcmp(call->a->text, "print") && strcmp(call->a->text, "println")))
        return;
    for (int i = 0; i < call->items.len; i++) {
        Expr *x = call->items.data[i];
        Type *t = value_type(x);
        if (t && t->kind == T_FUNC)
            error_at(x->pos, "%s cannot show a function: a function has no text", call->a->text);
    }
    /* the prelude's macro counts up to 16 values (P22); beyond, C's error
       would name a pasted token */
    if (call->items.len > 16)
        error_at(((Expr *)call->items.data[16])->pos, "%s takes up to 16 values, and this has %d: write two calls",
                 call->a->text, call->items.len);
}

/* An anonymous function as argument k of call, taking its types from
   the parameter it is passed to when kelvinc can see it; arity is how
   many arguments the call takes, or -1. One inside the parentheses is
   an expression, which may go on, as in `f({ (a:i64):i64 in a }(3))`;
   a trailing one is the argument itself. */
static Expr *anon_arg(Type *param, int arity, int k, Expr *call, bool trailing) {
    if (arity >= 0 && k >= arity) {
        const char *who = call->kind == E_METHOD ? strfmt("'.%s()'", call->text)
                          : call->kind == E_IDENT ? strfmt("'%s'", call->text)
                          : call->kind == E_FIELD && call->a && call->a->kind == E_IDENT
                              ? strfmt("'%s.%s'", call->a->text, call->text)
                              : "this function";
        error_at(peek()->pos, "%s takes %d argument%s, and this anonymous function would be argument %d", who, arity,
                 arity == 1 ? "" : "s", k + 1);
    }
    if (param && param->kind != T_FUNC) {
        Decl *r;
        char c = type_class(param, &r);
        bool aggregate = param->kind == T_ARRAY || (param->kind == T_BASE && (c == 's' || c == 'c'));
        if (!trailing && aggregate && !signature_ahead(cur))
            error_at(peek()->pos, "a list is not a value here: the parameter is %s, so write a compound literal, as "
                                  "in '(%s){...}'",
                     kelvin_type(param), kelvin_type(param));
        if (param->kind != T_TYPEOF && (param->kind != T_BASE || type_class(param, &r) != 'u'))
            error_at(peek()->pos, "an anonymous function cannot be passed here: the parameter is %s, not a function",
                     kelvin_type(param));
        /* a C typedef, which may name a function type */
        pending_note = strfmt("; it is argument %d, whose parameter is %s: is an argument missing?", k + 1,
                              kelvin_type(param));
        param = NULL;
    }
    if (trailing)
        return parse_anon_fn(param);
    fn_at = cur;
    fn_type = param;
    return parse_assign();
}

static Expr *text_in_buffer(Expr *e);
static bool has_effect(Expr *e);

/* Is e an assignment, or a comma list with one? */
static bool is_assignment(Expr *e) {
    if (e->kind != E_BINARY)
        return false;
    if (!strcmp(e->op, ","))
        return is_assignment(e->a) || is_assignment(e->b);
    for (int i = 0; assign_ops[i]; i++)
        if (!strcmp(e->op, assign_ops[i]))
            return true;
    return false;
}

/* Returning text in the function's own buffer (#21) is an error */
/* return b moves a local owner out (O4); a field or an element of one
   cannot go alone, and a borrow of a local owner dies with it (O6) */
static void return_owner(Expr *e) {
    if (e->kind == E_IDENT && is_owner(value_type(e))) {
        if (let_kind(e->text) == LET_EACH)
            error_at(e->pos, "'%s' is each element in turn, which its Array owns: return a copy, '%s.copy()'", e->text,
                     e->text);
        int i = binding_index(e->text);
        int globals = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
        if (i >= globals)
            set_moved(e->text, true);
        return;
    }
    if (owner_place(e))
        error_at(e->pos, "an owner is returned as a whole variable, which moves out: a part of one is copied with "
                         ".copy()");
    if (e->kind == E_PREFIX && !strcmp(e->op, "&") && e->a->kind == E_IDENT && is_owner(value_type(e->a))) {
        int i = binding_index(e->a->text);
        int globals = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
        if (i >= globals)
            error_at(e->pos, "a borrow of '%s' is returned, and '%s' is freed when this function returns: return "
                             "'%s' itself, which moves it out",
                     e->a->text, e->a->text, e->a->text);
    }
}

static void reject_returned_text(Expr *e, bool anon) {
    Expr *text = text_in_buffer(e);
    if (text && text->kind == E_TEMPLATE)
        error_at(text->pos, "a template's text lives in this function's block, which is gone once it returns: "
                            "the caller makes the text itself, as in 'println(`...`)'");
    if (text && anon)
        error_at(text->pos, "'.%s' text lives in a buffer of this function, which is gone once it returns: "
                            "the caller takes the text itself, as in '{ println($0.%s) }'",
                 text->text, text->text);
    if (text)
        error_at(text->pos, "'.%s' text lives in a buffer of this function, which is gone once it returns: "
                            "the caller takes the text itself, as in 'println(x.%s)'",
                 text->text, text->text);
}

/* Does kelvinc see that e has no value: a call of print or println, of a
   Kelvin function, method or function value with no result, or of
   _Pragma or asm, or a comma or ?: with one? */
static bool no_value(Expr *e) {
    switch (e->kind) {
    case E_CALL: {
        static const char *words[] = {"print", "println", "_Pragma", "__asm__", "__asm", "asm", NULL};
        if (e->a->kind == E_IDENT && binding_index(e->a->text) < 0)
            for (int i = 0; words[i]; i++)
                if (!strcmp(e->a->text, words[i]))
                    return true;
        Type *t = value_type(e->a);
        return t && t->kind == T_FUNC && !t->elem;
    }
    case E_METHOD: {
        Decl *m = method_named(e->a, e->text);
        return m && !m->ret;
    }
    case E_BINARY:
        return !strcmp(e->op, ",") && no_value(e->b);
    case E_TERNARY:
        return no_value(e->b) || no_value(e->c);
    default:
        return false;
    }
}

/* Does the statement expression e leave a value behind: one with no
   effect, or (with calls) a call of a Kelvin function, method or function
   value kelvinc sees has a result? */
static bool drops_value(Expr *e, bool calls) {
    if (!has_effect(e))
        return true;
    if (!calls)
        return false;
    switch (e->kind) {
    case E_CALL: {
        Type *t = value_type(e->a);
        return t && t->kind == T_FUNC && t->elem;
    }
    case E_METHOD: {
        Decl *m = method_named(e->a, e->text);
        return m && m->ret;
    }
    case E_BINARY:
        return !strcmp(e->op, ",") && drops_value(e->b, calls);
    case E_TERNARY:
        return drops_value(e->b, calls) || drops_value(e->c, calls);
    default:
        return false;
    }
}

/* The statement at the end of a path through s that drops a value, as
   in `if c { 1 } else { 2 }`, a case's last statement (one with no
   effect, before another case) or a block's; NULL if none */
static Stmt *dropped_at_end(Stmt *s, bool calls) {
    if (!s)
        return NULL;
    switch (s->kind) {
    case S_EXPR:
        return drops_value(s->expr, calls) ? s : NULL;
    case S_BLOCK:
        return s->stmts.len ? dropped_at_end(s->stmts.data[s->stmts.len - 1], calls) : NULL;
    case S_IF: {
        Stmt *b = dropped_at_end(s->body, calls);
        return b ? b : dropped_at_end(s->els, calls);
    }
    case S_LABEL:
        return dropped_at_end(s->body, calls);
    case S_SWITCH: {
        if (!s->body || s->body->kind != S_BLOCK)
            return dropped_at_end(s->body, calls);
        /* a case ends at the next (#63), so each case's last statement is
           at the end */
        List *l = &s->body->stmts;
        for (int k = 0; k < l->len; k++) {
            Stmt *next = k + 1 < l->len ? l->data[k + 1] : NULL;
            if (next && next->kind != S_CASE && next->kind != S_DEFAULT)
                continue;
            Stmt *d = dropped_at_end(l->data[k], calls);
            if (d)
                return d;
        }
        return NULL;
    }
    default:
        return NULL;
    }
}

/* A function with a result whose body is one expression returns it, as
   in `square(x:i64):i64 { x * x }` (#35), anonymous ones too (#32). main
   keeps C's rule that its end returns 0. One assignment or one call
   kelvinc sees has no value is an error there, as is a body that ends,
   on any path, in a value it drops; in main, one with no effect. */
static void implicit_return(Decl *d) {
    if (!d->ret || !d->body || !d->body->stmts.len)
        return;
    List *stmts = &d->body->stmts;
    Stmt *last = stmts->data[stmts->len - 1];
    if (stmts->len == 1 && last->kind == S_EXPR && !is_main(d)) {
        if (is_assignment(last->expr))
            error_at(last->pos, "an assignment has no value (#26), but this function has a result, of type %s: "
                                "assign, then 'return' a value",
                     kelvin_type(d->ret));
        if (no_value(last->expr))
            error_at(last->pos, "this has no value, but this function has a result, of type %s: write 'return' "
                                "with a value after it",
                     kelvin_type(d->ret));
        last->kind = S_RETURN;
        pick_overload(last->expr, d->ret);
        if (!d->text_method) /* T.cstr() returns its template to the caller's buffer (#53) */
            reject_returned_text(last->expr, d->anon);
        return_owner(last->expr);
        return;
    }
    Stmt *dropped = dropped_at_end(last, !is_main(d));
    if (dropped && is_main(d))
        error_at(dropped->pos, "main's end returns 0, as in C, so it does not return this value: write 'return' "
                               "before it");
    if (dropped)
        error_at(dropped->pos, "this value would be dropped: a body returns its value without 'return' only when "
                               "it is one expression, so write 'return' before it");
}

/* Does e do something as a statement: an assignment, a call, or a
   comma or ?: of those? */
static bool has_effect(Expr *e) {
    switch (e->kind) {
    case E_CALL:
    case E_METHOD:
        return true;
    case E_TERNARY:
        return has_effect(e->b) && has_effect(e->c);
    case E_BINARY:
        if (!strcmp(e->op, ","))
            return has_effect(e->a) && has_effect(e->b);
        for (int i = 0; assign_ops[i]; i++)
            if (!strcmp(e->op, assign_ops[i]))
                return true;
        return false;
    default:
        return false;
    }
}

/* The property in e whose text is in a buffer of the block that makes
   it, as .hex's is (#21), looking through `as`, ?: and the comma; NULL if
   none. .cstr of a string kelvinc sees is the string itself (P34). */
static Expr *text_in_buffer(Expr *e) {
    switch (e->kind) {
    case E_TEMPLATE: /* (#39); $`...` is a String on the heap (#67) */
        return e->op && !strcmp(e->op, "string") ? NULL : e;
    case E_CAST: /* i64(x.hex) is a number (#36) */
        return e->op && !strncmp(e->op, "text", 4) ? NULL : text_in_buffer(e->a);
    case E_TERNARY: {
        Expr *b = text_in_buffer(e->b);
        return b ? b : text_in_buffer(e->c);
    }
    case E_BINARY: {
        /* the comma's value, and pointer steps: text + 2, text - 1 */
        if (!strcmp(e->op, ","))
            return text_in_buffer(e->b);
        if (strcmp(e->op, "+") && strcmp(e->op, "-"))
            return NULL;
        Expr *a = text_in_buffer(e->a);
        return a ? a : !strcmp(e->op, "+") ? text_in_buffer(e->b) : NULL;
    }
    case E_PREFIX: /* &text[i] */
        return !strcmp(e->op, "&") && e->a->kind == E_INDEX ? text_in_buffer(e->a->a) : NULL;
    case E_PROPERTY: {
        /* .typename is a string literal C chooses (#34), .addr a number (#37) */
        if (!strcmp(e->text, "size") || !strcmp(e->text, "typename") || !strcmp(e->text, "type") ||
            !strcmp(e->text, "addr") || !strcmp(e->text, "count") || !strcmp(e->text, "isNull") ||
            !strcmp(e->text, "keys") || !strcmp(e->text, "values") || (e->op && !strcmp(e->op, "tagged")))
            return NULL; /* .count and .isNull are numbers too (#49, #50) */
        if (!strcmp(e->text, "next") || !strcmp(e->text, "prev"))
            return text_in_buffer(e->a);
        if (strcmp(e->text, "cstr") || e->a->kind == E_STRING)
            return strcmp(e->text, "cstr") ? e : NULL;
        Expr *inner = text_in_buffer(e->a); /* `...`.cstr is the template's text (#39) */
        if (inner)
            return inner;
        Type *t = value_type(e->a);
        bool string = t && t->kind == T_PTR && t->elem->kind == T_BASE &&
                      (!strcmp(t->elem->name, "u8") || !strcmp(t->elem->name, "i8"));
        return string ? NULL : e;
    }
    default:
        return NULL;
    }
}

/* a function's body, whose `{` (open) has been read */
static Stmt *parse_fn_body(Token *open) {
    int saved_first = body_first, saved_end = body_end;
    body_first = cur;
    body_end = skip_nested((int)(open - toks)) - 1;
    Stmt *s = parse_block_rest(open);
    body_first = saved_first;
    body_end = saved_end;
    return s;
}

/* An anonymous function's C name (#38): _kv_, the top-level declaration
   it is written in, and fn, numbered 1, 2, ... when it repeats, as in
   _kv_main_fn and _kv_main_fn1 */
static char *anon_name(void) {
    for (int n = top_name ? -1 : 0;; n++) {
        char *name = !top_name ? strfmt("_kv_fn%d", n)
                     : n < 0   ? strfmt("_kv_%s_fn", top_name)
                               : strfmt("_kv_%s_fn%d", top_name, n + 1);
        bool used = false;
        for (int i = 0; i < anon_names.len && !used; i++)
            used = !strcmp(anon_names.data[i], name);
        if (!used) {
            list_push(&anon_names, name);
            return name;
        }
    }
}

/* An anonymous function, from its `{` to its `}`: a static inline
   function of its own in C (#33), declared before the top-level
   declaration around it and defined after it. It encloses nothing, as C has no closures: it may
   use globals and functions, not the locals of the function around it.
   Its parameters are written, as in `{ (a:i32, b:i32):bool in ... }`,
   or come from ctx, the function type it is passed or assigned as, and
   are then $0, $1, ...; with neither, it has none. A body that is one
   expression is the result, as in `{ $0 < $1 }`, or without a result,
   may be one assignment, as in `{ total += $0 }`. */
static Expr *parse_anon_fn(Type *ctx) {
    Token *open = peek();
    bool written = signature_ahead(cur);
    Decl *d = new_decl(D_FN, open->pos, "static inline"); /* inline by default (#33) */
    d->name = anon_name();
    Decl *saved_fn = parsing_fn;
    int saved_start = params_start, saved_end = params_end, saved_anon = anon_start, saved_kind = anon_kind,
        saved_init = init_depth;
    const char *saved_note = anon_note;
    bool saved_signature = in_signature;
    in_signature = false;
    anon_note = pending_note;
    pending_note = NULL;
    d->anon = true;
    bool saved_assign = assign_ok, saved_brace = brace_ends_condition, saved_for = brace_in_for,
         saved_annotation = ident_annotation_ok, saved_body = stmt_is_body;
    assign_ok = brace_ends_condition = brace_in_for = stmt_is_body = false;
    ident_annotation_ok = true;
    init_depth = 0;
    open_scope();
    params_start = params_end = anon_start = scope_names.len;
    parsing_fn = d; /* from here, the names in its types are checked as in its body */
    if (written) {
        anon_kind = ANON_WRITTEN;
        in_signature = true;
        advance();
        expect_p("(");
        while (!is_p(peek(), ")")) {
            if (accept_p("...")) {
                if (d->params.len == 0)
                    error_at(open->pos, "a variadic function needs at least one named parameter");
                d->variadic = true;
                break;
            }
            bool mutable = accept_kw("var");
            reject_c_fn_pointer(cur, "");
            Var *p = parse_var(false, LET_NONE);
            p->is_let = !mutable;
            declare_binding(p->name, param_type(p->type), p->is_let ? LET_PARAM : LET_NONE);
            list_push(&d->params, p);
            if (!accept_p(","))
                break;
        }
        expect_p(")");
        bool result = accept_p(":");
        d->ret = result ? parse_type() : ctx ? ctx->elem : NULL;
        if (!result && has_local_size(d->ret))
            error_at(open->pos, "the result type, %s, has an array length or a .type written in another scope, which kelvinc "
                                "cannot carry into this function: write the result",
                     kelvin_type(d->ret));
        if (!is_in(peek()))
            error_at(peek()->pos, "expected 'in' after the parameters, as in '{ (a:i32):i32 in a * 2 }'");
        advance();
        in_signature = false;
    } else if (ctx) {
        for (int k = 0; k < ctx->params.len; k++) {
            Var *p = xcalloc(1, sizeof *p);
            p->name = strfmt("$%d", k);
            p->pos = open->pos;
            /* an array length that names a local or a parameter was written
               in another scope, where it means something else: the outer
               array becomes the pointer C makes of it, and a length
               anywhere else cannot be carried over */
            Type *pt = ctx->params.data[k];
            if (pt->kind == T_ARRAY && (!pt->size || pt->size_local))
                pt = param_type(pt);
            if (has_local_size(pt))
                error_at(open->pos, "the type of $%d, %s, has an array length or a .type written in another scope, which "
                                    "kelvinc cannot carry into this function: write its parameters, as in "
                                    "'{ (a:T):R in ... }'",
                         k, kelvin_type(pt));
            p->type = pt;
            p->is_let = true;
            declare_binding(p->name, param_type(p->type), LET_PARAM);
            list_push(&d->params, p);
        }
        d->ret = ctx->elem;
        if (has_local_size(d->ret))
            error_at(open->pos, "the result type, %s, has an array length or a .type written in another scope, which kelvinc "
                                "cannot carry into this function: write its parameters and result",
                     kelvin_type(d->ret));
        d->variadic = ctx->variadic;
        anon_kind = ANON_CONTEXT;
    } else {
        anon_kind = ANON_BARE;
    }
    params_end = scope_names.len;
    d->body = parse_fn_body(written ? open : expect_p("{"));
    /* one expression is the result, as in { $0 < $1 } (#32, #35); without
       a result, it must do something, as { total += $0 } does: `{x: 1}`
       is a label in a body, and a list where C's argument is meant */
    Stmt *only = d->body->stmts.len == 1 ? d->body->stmts.data[0] : NULL;
    while (only && only->kind == S_LABEL)
        only = only->body;
    if (only && only->kind == S_EXPR && !d->ret && !has_effect(only->expr)) {
        if (anon_kind == ANON_BARE)
            error_at(only->expr->pos, "a list is not a value here: write a compound literal, as in "
                                      "'(i32[3]){1, 2, 3}'; as a function with no parameters and no result, this "
                                      "would do nothing");
        error_at(only->expr->pos, "this function, of type %s, has no result, so its body would discard this "
                                  "value: write a call or an assignment, or give the type a result",
                 kelvin_type(fn_type_of(d)));
    }
    implicit_return(d);
    close_scope();
    parsing_fn = saved_fn;
    params_start = saved_start;
    params_end = saved_end;
    anon_start = saved_anon;
    anon_kind = saved_kind;
    init_depth = saved_init;
    anon_note = saved_note;
    in_signature = saved_signature;
    assign_ok = saved_assign;
    brace_ends_condition = saved_brace;
    brace_in_for = saved_for;
    ident_annotation_ok = saved_annotation;
    stmt_is_body = saved_body;
    list_push(&anon_fns, d);
    Expr *e = new_expr(E_FUNC, open->pos);
    e->text = d->name;
    e->type = fn_type_of(d);
    return e;
}

/* $k, or $[k] with a number k: parameter k of the innermost anonymous
   function (#32) */
static Expr *parse_dollar(void) {
    Token *t = advance();
    const char *digits = t->text + 1;
    bool bracket = !*digits;
    if (bracket) {
        if (!accept_p("["))
            error_at(t->pos, "'$' alone is not a value: $\"text\" is a String, $[a, b] an Array, and an anonymous "
                             "function's parameters are $[0], $[1], ..., or $0, $1, ...");
        Token *n = peek();
        if (n->kind != TK_NUMBER || strspn(n->text, "0123456789") != strlen(n->text))
            error_at(n->pos, "$[...] takes a number, as in $[0]: each parameter may have a type of its own");
        advance();
        expect_p("]");
        digits = n->text;
    }
    /* the spelling as written, for messages */
    char *name = bracket ? strfmt("$[%s]", digits) : t->text;
    if (digits[0] == '0' && digits[1]) {
        const char *rest = digits + strspn(digits, "0");
        error_at(t->pos, "'%s' has a leading zero: write %s", name,
                 strfmt(bracket ? "$[%s]" : "$%s", *rest ? rest : "0"));
    }
    /* more digits than a parameter count has is out of range, without
       converting them */
    int k = strlen(digits) > 6 ? 1000000 : atoi(digits);
    if (anon_start < 0) {
        int at = (int)(t - toks);
        const char *hint =
            init_depth ? "; there, '{' starts an initializer list, so an anonymous function writes its parameters, "
                         "as in '{ (a:i64):i64 in a + 1 }'"
            : body_after_call >= 0 && at > body_after_call && at < skip_nested(body_after_call)
                ? "; in the head of if, while or for, a '{' after a call starts the body, so pass the function "
                  "inside the parentheses"
            : block_after_call >= 0 && at > block_after_call && at < skip_nested(block_after_call)
                ? "; a trailing function starts on the line of the call's ')': on the next line, '{' starts a "
                  "block"
                : "";
        error_at(t->pos, "'%s' is a parameter of an anonymous function, and this is not in one%s", name, hint);
    }
    if (in_signature)
        error_at(t->pos, "'%s' cannot be used in the parameters or result of the function it names", name);
    if (anon_kind == ANON_BARE)
        error_at(t->pos, "kelvinc cannot see this anonymous function's parameters, so '%s' has no type: write "
                         "them, as in '{ (a:i32, b:i32):bool in ... }'%s",
                 name, anon_note ? anon_note : "");
    if (k < 0 || k >= parsing_fn->params.len)
        error_at(t->pos, "'%s': this anonymous function has %d parameter%s", name, parsing_fn->params.len,
                 parsing_fn->params.len == 1 ? "" : "s");
    Var *p = parsing_fn->params.data[k];
    int i = binding_index(p->name);
    if (i < params_start || i >= params_end)
        error_at(t->pos, "'%s' is '%s', which a local name hides here", name, p->name);
    Expr *e = new_expr(E_IDENT, t->pos);
    e->text = p->name;
    return e;
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
   or `struct p`. `again: n = 0;` stays a label before a statement.
   Returns whether it is instead an annotation that is the statement's
   expression (#35): one an operator follows, as in `n:i64 * 2`, or the
   one a body returns, as in `{ n:i64 }`. */
static bool reject_bare_declaration(int i) {
    int first = i;
    if (is_kw(&toks[i], "static") || is_kw(&toks[i], "extern"))
        i++;
    if (toks[i].kind != TK_IDENT || !is_p(&toks[i + 1], ":"))
        return false;
    Token *t = &toks[i + 2];
    if (first == i && t->kind == TK_IDENT && !is_base_word(t) && !tag_name_ahead(t, false)) {
        /* a C typedef kelvinc cannot see, as in `{ n:size_t }`, annotates
           a name it sees as the expression a body returns; anywhere else
           `name:` is a label, as in `again: n = 0` */
        int end = type_shape_end(i + 2);
        if (end < 0 || binding_index(toks[i].text) < 0 || i != body_first || !parsing_fn || !parsing_fn->ret ||
            is_main(parsing_fn))
            return false;
        Token *e = &toks[end];
        return binary_prec(e) > 0 || is_kw(e, "as") || is_p(e, "?") || returned_statement(i, end);
    }
    if (!is_base_word(t) && !is_qualifier(t) && !is_kw(t, "struct") && !is_kw(t, "union") && !is_kw(t, "enum") &&
        !tag_name_ahead(t, false) && !is_p(t, "("))
        return false;
    if (is_p(t, "(")) {
        /* `again: (x) = 1;` and `out: (i64(n));` are labels */
        Token *in = &toks[i + 3];
        bool typed = is_p(in, ")") || (is_base_word(in) && !is_p(in + 1, "(")) || is_qualifier(in) ||
                     is_kw(in, "struct") || is_kw(in, "union") || is_kw(in, "enum") ||
                     is_p(&toks[skip_group(i + 2)], ":");
        if (!typed)
            return false;
    }
    int end = is_p(t, "(") ? any_type_end(i + 2) : type_shape_end(i + 2);
    if (end < 0)
        return false;
    Token *e = &toks[end];
    if (first == i && !is_p(t, "(") && (binary_prec(e) > 0 || is_kw(e, "as") || is_p(e, "?")))
        return true;
    /* `n:i32` at the end of a line or before a `}` too (#35) */
    bool ends = is_p(e, ";") || statement_ends_at(end);
    if (first == i && !is_p(t, "(") && ends && returned_statement(i, end))
        return true;
    if (is_p(e, "=") || is_p(e, ":=") || is_p(e, ",") || ends)
        error_at(toks[i].pos, "declarations start with let or var: write 'var %s:...', or 'let %s:...' if it "
                              "never changes",
                 toks[i].text, toks[i].text);
    return false;
}

static Stmt *parse_declaration(void) {
    Stmt *s = new_stmt(S_VAR, peek()->pos);
    s->storage = parse_storage();
    bool is_let = accept_kw("let");
    if (!is_let && !accept_kw("var"))
        error_at(peek()->pos, "expected 'let' or 'var'");
    bool saved = static_init;
    static_init = s->storage && !strcmp(s->storage, "static");
    parse_var_list(&s->vars, is_let, s->storage);
    static_init = saved;
    return s;
}

/* one label of a case: of an enum with values, a case's bare name (#61);
   otherwise C's constant expression */
static void parse_case_label(Stmt *s) {
    if (switch_record && peek()->kind == TK_IDENT && (is_p(peek2(), ":") || is_p(peek2(), ","))) {
        int k;
        Var *c = case_named(switch_record, peek()->text, &k);
        if (!c)
            error_at(peek()->pos, "%s has no case '%s': the cases are %s", record_spelling(switch_record),
                     peek()->text, case_list(switch_record));
        Token *cn = advance();
        s->expr = new_expr(E_LITERAL, cn->pos);
        s->expr->text = strfmt("%d", k);
        s->name = c->name;
        return;
    }
    bool saved = ident_annotation_ok;
    ident_annotation_ok = false;
    s->expr = parse_conditional();
    ident_annotation_ok = saved;
}

/* the Kelvin enum (C's kind) that t names, with its enumerators */
static Decl *plain_enum_of(Type *t) {
    if (t && t->kind == T_TYPEOF)
        t = t->elem;
    if (!t || t->kind != T_BASE || strncmp(t->name, "enum ", 5))
        return NULL;
    Decl *r = record_named(t->name + 5);
    return r && r->kind == D_ENUM && r->has_body ? r : NULL;
}

/* A switch's block (#63): it starts with a case, no case is empty before
   another (a case ends at the next: write `case a, b:` for one body), and
   every value is handled: every case of an enum with values, every
   enumerator of a Kelvin enum, or `default:`. One exhaustive by its cases
   is marked closed, for C. */
static void check_switch(Stmt *s) {
    List *l = &s->body->stmts;
    if (!l->len || (((Stmt *)l->data[0])->kind != S_CASE && ((Stmt *)l->data[0])->kind != S_DEFAULT))
        error_at(l->len ? ((Stmt *)l->data[0])->pos : s->body->pos, "a switch's block starts with 'case' or 'default:'");
    bool has_default = false;
    List labels = {0}; /* Stmt *: every case label, chains included */
    for (int k = 0; k < l->len; k++) {
        Stmt *x = l->data[k];
        if (x->kind == S_DEFAULT)
            has_default = true;
        if (x->kind != S_CASE && x->kind != S_DEFAULT)
            continue;
        for (Stmt *c = x; c && c->kind == S_CASE; c = c->els)
            list_push(&labels, c);
        Stmt *next = k + 1 < l->len ? l->data[k + 1] : NULL;
        if (next && (next->kind == S_CASE || next->kind == S_DEFAULT))
            error_at(next->pos, "a case ends at the next case, and the one before this has no body: write 'case a, "
                                "b:' to share a body, or 'break' to do nothing");
    }
    if (has_default)
        return;
    Decl *tr = tagged_record(s->type), *pe = tr ? NULL : plain_enum_of(s->type);
    Decl *r = tr ? tr : pe;
    if (!r)
        error_at(s->pos, "a switch handles every value: add 'default:'");
    Buf missing = {0};
    buf_puts(&missing, "");
    int n = 0;
    for (int i = 0; i < r->members.len; i++) {
        Var *m = r->members.data[i];
        bool found = false;
        for (int k = 0; !found && k < labels.len; k++) {
            Stmt *c = labels.data[k];
            found = tr ? c->name && !strcmp(c->name, m->name)
                       : c->expr->kind == E_IDENT && !strcmp(c->expr->text, m->name);
        }
        if (!found)
            buf_printf(&missing, "%s%s", n++ ? ", " : "", m->name);
    }
    if (n)
        error_at(s->pos, "switch on %s is not exhaustive: %s %s missing; write every %s, or add 'default:'",
                 tr ? record_spelling(tr) : pe->name, missing.buf, n == 1 ? "is" : "are", tr ? "case" : "enumerator");
    s->closed = true;
}

/* The condition of if, while or do (#23): a bool, with no parentheses
   needed, as in `if n > 0 { ... }` */
static Expr *parse_condition(const char *what) {
    if (is_p(peek(), "(")) {
        /* C's `if (x) y = 1;`: the body must be a block */
        Token *after = after_matching_paren(cur);
        /* after `do { } while (n > 0)`, the next line is the next statement (#35) */
        if (!strcmp(what, "do") && after && line_break(after - 1, after))
            after = NULL;
        if (after && (after->kind == TK_IDENT || after->kind == TK_NUMBER || after->kind == TK_STRING ||
                      after->kind == TK_TPL_HEAD ||
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
/* Where the binding of name that C will see sits, or -1: inside an
   anonymous function, the function around it is out of sight (#32) */
static int visible_binding(const char *name) {
    int locals = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
    for (int i = scope_names.len - 1; i >= 0; i--) {
        if (anon_start >= 0 && i >= locals && i < anon_start)
            continue;
        if (!strcmp(scope_names.data[i], name))
            return i;
    }
    return -1;
}

/* Does the declared length of an array parameter, evaluated again in the
   body, still give what it gave at the call? It does when it is made of
   numbers, lets and C's constants (BUFSIZ), with no call, no var and no
   name that a local hides (#30). */
static bool length_holds(Expr *e) {
    switch (e->kind) {
    case E_LITERAL:
    case E_SIZEOF_TYPE:
        return true;
    case E_IDENT: {
        int i = visible_binding(e->text);
        if (i < 0)
            return true; /* a C constant */
        if (i >= params_end)
            return false; /* a local hides it */
        /* a let, or a function or enumerator (no type); not a var */
        return (int)(intptr_t)scope_lets.data[i] != LET_NONE || !scope_types.data[i];
    }
    case E_BINARY:
        return length_holds(e->a) && length_holds(e->b);
    case E_PREFIX:
        return strcmp(e->op, "&") && length_holds(e->a);
    case E_TERNARY:
        return length_holds(e->a) && length_holds(e->b) && length_holds(e->c);
    case E_CAST:
    case E_SIZEOF_EXPR:
        return length_holds(e->a);
    case E_PROPERTY:
        return !strcmp(e->text, "size") && length_holds(e->a);
    default:
        return false;
    }
}

/* Is e part of a value that C discards at the end of the statement that
   makes it, a field of what a call or ?: returns? An array there is gone
   before the loop runs. A row of an array that kelvinc cannot see is
   taken to be one too. */
static bool in_temporary(Expr *e) {
    if (e->kind == E_INDEX) {
        Type *t = value_type(e->a);
        return (!t || t->kind == T_ARRAY) && in_temporary(e->a);
    }
    if (e->kind != E_FIELD || !e->a)
        return false;
    Expr *b = e->a;
    return b->kind == E_CALL || b->kind == E_METHOD || b->kind == E_TERNARY || in_temporary(b);
}

/* Is e main's argv, or a step from it along .next or .prev? Kelvin writes
   it u8^^, and C insists on char ** (P13). */
static bool from_main_argv(Expr *e) {
    if (e->kind == E_PROPERTY && (!strcmp(e->text, "next") || !strcmp(e->text, "prev")))
        return from_main_argv(e->a);
    if (e->kind != E_IDENT || !parsing_fn || parsing_fn->recv || strcmp(parsing_fn->name, "main") ||
        parsing_fn->params.len < 2)
        return false;
    return param_named(e->text) == parsing_fn->params.data[1];
}

/* for x in s { } (#30): each element of a sequence that ends at a
   terminator, chosen by s's type. A pointer to numbers or pointers gives
   s^, s.next^, ... up to the first 0 or nullptr, and a nullptr s is
   empty; a pointer to a struct with a `next` field gives each node's
   pointer along next, up to nullptr; an array of known length gives its
   elements, stopping early at a 0 or nullptr (an array of structs gives
   all of them). A let array parameter has the length it was declared
   with; a var one may have moved, so it is a pointer. A pointer kelvinc
   cannot see, such as getenv()'s, is walked like a pointer. x is a let,
   of the element's type unless written `for x:T in s`, and s is
   evaluated once. */
static Stmt *parse_for_each(Stmt *s, Type *written) {
    s->kind = S_FOR_EACH;
    Expr *seq = s->expr;
    Type *t = value_type(seq);
    Var *param = seq->kind == E_IDENT ? param_named(seq->text) : NULL;
    if (param && param->is_let && param->type->kind == T_ARRAY && param->type->size) {
        if (!length_holds(param->type->size))
            error_at(seq->pos,
                     "for over %s: its declared length uses a call, a var or a name that a local hides, so it "
                     "may not be what it was at the call; index it, as in 'for i in 0..<n'",
                     param->name);
        t = param->type;
        s->step = t->size;
    }
    if ((!t || t->kind == T_ARRAY) && in_temporary(seq))
        error_at(seq->pos, "for over an array in a value that a call or '?:' returns: C discards the value before "
                           "the loop runs, so copy it into a let first, as in 'let v = make(); for x in v.xs'");
    Type *elem = NULL;
    Decl *record = NULL;
    if (is_dict_owner(t)) { /* its entries, in order (#65): the key, or key and value */
        if (!owner_place(seq))
            error_at(seq->pos, "for over a Dictionary that an expression gives: bind it to a variable first");
        s->each = EACH_DICT;
        elem = t->key;
    } else if (is_bytes(t) || is_string(t) || is_array_owner(t)) {
        /* its count bytes, NULs included (#54); a String's codepoints
           (#55); an Array's elements (#57) */
        if (!owner_place(seq))
            error_at(seq->pos, "for over a %s that an expression gives: bind it to a variable first",
                     is_bytes(t) ? "Bytes" : is_string(t) ? "String" : "Array");
        s->each = is_string(t) ? EACH_STRING : EACH_BYTES;
        elem = is_array_owner(t) ? t->elem : base_type(is_bytes(t) ? "u8" : "uchr", seq->pos);
    } else if (!t) {
        s->each = EACH_UNSEEN;
    } else if (t->kind == T_ARRAY) {
        if (!t->size)
            error_at(seq->pos, "a flexible array member has no length to walk: index it");
        elem = t->elem;
        if (elem->kind == T_ARRAY)
            error_at(seq->pos, "for over an array of arrays: index it, as in 'for x in a[0]'");
        char c = elem->kind == T_BASE ? type_class(elem, &record) : 'n';
        s->each = c == 's' || c == 'c' ? EACH_RECORDS : EACH_ARRAY;
    } else if (t->kind == T_PTR) {
        elem = t->elem;
        char c = elem->kind == T_BASE ? type_class(elem, &record) : 'n';
        if (elem->kind == T_BASE && !strcmp(elem->name, "any"))
            error_at(seq->pos, "an any^ has no elements to walk: convert it first, as in 'p as u8^'");
        if (c == 'c')
            error_at(seq->pos, "for over %s: kelvinc cannot see its fields, so it cannot follow a next field",
                     kelvin_type(t));
        if (c == 's') {
            Var *next = NULL;
            for (int i = 0; i < record->members.len; i++) {
                Var *m = record->members.data[i];
                if (!strcmp(m->name, "next"))
                    next = m;
            }
            if (!next || next->type->kind != T_PTR)
                error_at(seq->pos, "for over %s: a list is followed through a pointer field named next, and %s "
                                   "has none",
                         kelvin_type(t), kelvin_type(elem));
            s->each = EACH_LIST;
            elem = t; /* the loop variable is the node's pointer */
            if (written && written->kind != T_PTR)
                error_at(written->pos, "the loop variable of a list is each node's pointer, %s, not %s",
                         kelvin_type(t), kelvin_type(written));
        } else {
            s->each = EACH_POINTER;
            s->from_argv = elem->kind == T_PTR && from_main_argv(seq);
        }
    } else {
        Decl *r;
        if (type_class(t, &r) != 'u')
            error_at(seq->pos, "for x in s walks a pointer, a list or an array, and this is %s; for a count, "
                               "write 'for i in 0..<n'",
                     kelvin_type(t));
        s->each = EACH_UNSEEN; /* a C typedef, such as a char pointer */
    }
    if (s->name2 && s->each != EACH_DICT)
        error_at(s->pos, "two loop variables walk a Dictionary's entries, 'for k, v in d', and this is %s",
                 t ? kelvin_type(t) : "not one");
    /* the hidden pointer reads s's elements; only x takes a written type */
    s->elem = s->each == EACH_DICT ? t->elem : elem;
    Type *x = written ? written : elem;
    /* x is a copy, so it drops the element's qualifiers */
    if (x) {
        Type *plain = xcalloc(1, sizeof *plain);
        *plain = *x;
        plain->is_const = plain->is_volatile = false;
        x = plain;
    }
    s->type = x;
    open_scope();
    if (strcmp(s->name, "_"))
        declare_binding(s->name, x, LET_EACH);
    if (s->name2 && strcmp(s->name2, "_")) {
        Type *vt = xcalloc(1, sizeof *vt);
        *vt = *s->elem;
        vt->is_const = vt->is_volatile = false;
        declare_binding(s->name2, vt, LET_EACH);
    }
    if (!is_p(peek(), "{"))
        error_at(peek()->pos, "expected '{': the body of 'for' is a block, as in 'for %s in s { ... }'", s->name);
    s->body = parse_block();
    close_scope();
    return s;
}

static Stmt *parse_for_in(Pos pos) {
    Stmt *s = new_stmt(S_FOR_IN, pos);
    Token *name = peek();
    reject_kv_name(name);
    s->name = advance()->text;
    if (accept_p(",")) { /* for k, v in d: a Dictionary's entries (#65) */
        reject_kv_name(peek());
        s->name2 = expect_ident("the value's name, as in 'for k, v in d'");
    }
    Type *written = accept_p(":") ? parse_type() : NULL;
    if (peek()->kind != TK_IDENT || strcmp(peek()->text, "in"))
        error_at(peek()->pos, "expected 'in', as in 'for %s in 0..<n { ... }', or 'for (...)'", s->name);
    advance();
    int prec = binary_prec(&(Token){.kind = TK_PUNCT, .text = "<<"});
    bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
    brace_ends_condition = brace_in_for = true; /* `for c in s {` */
    s->expr = parse_binary(prec);
    brace_ends_condition = saved_brace;
    brace_in_for = saved_for;
    if (is_p(peek(), ".."))
        error_at(peek()->pos, "expected '..<' or '...' in a range, as in '0..<n' or '1...n'");
    if (!is_p(peek(), "...") && !is_p(peek(), "..<"))
        return parse_for_each(s, written);
    if (s->name2)
        error_at(pos, "two loop variables walk a Dictionary's entries, 'for k, v in d': a range counts with one");
    if (accept_p("..."))
        s->closed = true;
    else if (!accept_p("..<"))
        error_at(peek()->pos, "expected '..<' or '...' in a range, as in '0..<n' or '1...n'");
    bool saved = brace_ends_condition;
    saved_for = brace_in_for;
    brace_ends_condition = brace_in_for = true;
    s->step = parse_binary(prec);
    brace_ends_condition = saved;
    brace_in_for = saved_for;
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
    plain->unqual = plain->kind == T_TYPEOF; /* also those __typeof__ keeps (#34) */
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

static Stmt *parse_stmt_here(void);

/* Does the block at token i hold a label, which goto may reach? */
static bool holds_label(int i) {
    if (!is_p(&toks[i], "{"))
        return false;
    int end = skip_nested(i);
    for (int k = i + 1; k < end; k++)
        if (toks[k].kind == TK_IDENT && is_p(&toks[k + 1], ":") &&
            (is_p(&toks[k - 1], "{") || is_p(&toks[k - 1], "}") || is_p(&toks[k - 1], ";") ||
             line_break(&toks[k - 1], &toks[k])))
            return true;
    return false;
}

static Stmt *parse_stmt(void) {
    int saved = stmt_start;
    stmt_start = cur;
    Stmt *s = parse_stmt_here();
    stmt_start = saved;
    return s;
}

static Stmt *parse_stmt_here(void) {
    Token *t = peek();
    Pos pos = t->pos;
    bool as_body = stmt_is_body;
    stmt_is_body = false;

    if (is_p(t, "{"))
        return parse_block();
    if (accept_p(";"))
        return new_stmt(S_EMPTY, pos);
    if (binding_ahead(cur)) {
        int at = cur + 1 + (is_kw(t, "static") || is_kw(t, "extern"));
        reject_c_fn_pointer(at, "var ");
        if (function_shape(at) == 2 && params_ahead(at + 1))
            error_at(toks[at].pos, "a function is declared at the top level; here a let holds an anonymous one, as in "
                                   "'let %s:(T):R := { (a:T):R in ... }' (#32, #45)",
                     toks[at].text);
        if (as_body)
            error_at(pos, "a declaration cannot be the body of a statement or follow a label; put it in a block, "
                          "or write 'label: ;' before it");
        Stmt *s = parse_declaration();
        end_statement();
        return s;
    }
    bool annotation = reject_bare_declaration(cur);
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
        end_statement();
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
        /* switch v { case a: ... case b, c: ... default: ... } (#63): no
           parentheses needed, a case ends at the next, every value is
           handled; of an enum with values, on its case (#61) */
        Stmt *s = new_stmt(S_SWITCH, pos);
        bool saved_brace = brace_ends_condition;
        brace_ends_condition = true;
        s->expr = parse_expr();
        brace_ends_condition = saved_brace;
        if (!is_p(peek(), "{"))
            error_at(peek()->pos, "expected '{': the body of 'switch' is a block of cases, as in 'switch v { case a: ... }'");
        Decl *tr = tagged_record(value_type(s->expr));
        s->type = value_type(s->expr); /* for the check of its cases */
        if (tr) {
            Expr *x = new_expr(E_PROPERTY, s->expr->pos);
            x->a = s->expr;
            x->text = "case";
            x->op = "tagged";
            s->expr = x;
        }
        Decl *saved = switch_record;
        int saved_depth = case_depth;
        switch_record = tr;
        case_depth = block_depth + 1;
        s->body = parse_block();
        case_depth = saved_depth;
        switch_record = saved;
        check_switch(s);
        return s;
    }
    if (accept_kw("case")) {
        if (case_depth < 0)
            error_at(pos, "'case' outside a switch");
        if (case_depth != block_depth)
            error_at(pos, "a case is written at the top of the switch's block, not inside a statement of it");
        Stmt *s = new_stmt(S_CASE, pos), *last = s;
        for (;;) {
            parse_case_label(last);
            if (!accept_p(","))
                break;
            Stmt *more = new_stmt(S_CASE, peek()->pos); /* case a, b: one body for both */
            last->els = more;
            last = more;
        }
        expect_p(":");
        return s;
    }
    if (accept_kw("default")) {
        if (case_depth < 0)
            error_at(pos, "'default' outside a switch");
        if (case_depth != block_depth)
            error_at(pos, "'default' is written at the top of the switch's block, not inside a statement of it");
        expect_p(":");
        return new_stmt(S_DEFAULT, pos);
    }
    if (accept_kw("break")) {
        end_statement();
        return new_stmt(S_BREAK, pos);
    }
    if (accept_kw("continue")) {
        end_statement();
        return new_stmt(S_CONTINUE, pos);
    }
    if (accept_kw("return")) {
        Stmt *s = new_stmt(S_RETURN, pos);
        /* a function type types an anonymous function (#32) */
        Type *ret = parsing_fn && parsing_fn->ret && parsing_fn->ret->kind == T_FUNC ? parsing_fn->ret : NULL;
        if (is_p(peek(), "{") && ret) {
            fn_at = cur;
            fn_type = ret;
        }
        /* `return` at the end of a line takes the value on the next line
           in a function with a result, as in Swift, and in one without, has
           nothing to return (#35) */
        bool result = parsing_fn && parsing_fn->ret;
        if (!is_p(peek(), ";") && !is_p(peek(), "}") && peek()->kind != TK_EOF && peek()->kind != TK_FILE_END &&
            (result || !newline_before())) {
            s->expr = parse_expr();
            pick_overload(s->expr, result ? parsing_fn->ret : NULL);
        }
        /* the function's own buffers are gone once it returns (#32, #35) */
        if (s->expr && result && !parsing_fn->text_method)
            reject_returned_text(s->expr, parsing_fn->anon);
        if (s->expr && result)
            return_owner(s->expr);
        bool semicolon = is_p(peek(), ";");
        end_statement();
        Token *n = peek();
        if (!s->expr && !semicolon && !as_body && !is_p(n, "}") && n->kind != TK_EOF && n->kind != TK_FILE_END &&
            !is_kw(n, "case") &&
            !is_kw(n, "default") && !(n->kind == TK_IDENT && is_p(n + 1, ":")) && !holds_label((int)(n - toks)))
            error_at(n->pos, "this never runs: in a function with no result, 'return' ends at the end of its line, "
                             "and this follows it in the same block");
        return s;
    }
    if (accept_kw("goto")) {
        Stmt *s = new_stmt(S_GOTO, pos);
        s->name = expect_ident("a label");
        end_statement();
        return s;
    }
    if (t->kind == TK_IDENT && is_p(peek2(), ":") && !annotation) {
        Stmt *s = new_stmt(S_LABEL, pos);
        reject_kv_name(peek());
        s->name = advance()->text;
        advance();
        s->body = parse_body();
        return s;
    }
    if (t->kind == TK_IDENT && !strcmp(t->text, "_Pragma") && is_p(peek2(), "(") &&
        peek_at(2)->kind == TK_STRING && is_p(peek_at(3), ")") &&
        (is_p(peek_at(4), ";") || is_p(peek_at(4), "}") || peek_at(4)->kind == TK_EOF || peek_at(4)->kind == TK_FILE_END ||
         line_break(peek_at(3), peek_at(4)))) {
        pragma_statement = true;
        Stmt *s = new_stmt(S_EXPR, pos);
        s->expr = parse_assignments();
        pragma_statement = false;
        end_statement();
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
    bool saved = ident_annotation_ok;
    ident_annotation_ok = ident_annotation_ok || annotation; /* n:point */
    s->expr = parse_assignments();
    ident_annotation_ok = saved;
    end_statement();
    /* a Bytes an expression gives, unbound, is freed at once (O4) */
    if (builtin_owner(value_type(s->expr)) && !owner_place(s->expr)) {
        Expr *drop = new_expr(E_CALL, pos);
        drop->a = new_expr(E_IDENT, pos);
        Type *dt = value_type(s->expr);
        drop->a->text = is_bytes(dt) ? "kv_bytes_discard" : is_string(dt) ? "kv_string_discard"
                                                                            : strfmt("%s_discard", dt->cname);
        drop->op = "c";
        list_push(&drop->items, s->expr);
        s->expr = drop;
    } else if (is_owner(value_type(s->expr)) && !owner_place(s->expr)) {
        error_at(pos, "a struct that owns is given and dropped here: bind it to a variable, which frees it");
    }
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

/* the operators a Kelvin struct may define (#42) */
static bool overloadable_op(Token *t) {
    static const char *ops[] = {"+", "-", "*", "/", "%", "==", "!=", "<", "<=", ">", ">=", NULL};
    for (int i = 0; ops[i]; i++)
        if (is_p(t, ops[i]))
            return true;
    return false;
}

/* What starts at token i at the top level: 1 a method `type.name(`, 2 a
   function `name(`, 3 an operator `+(` (#42), 4 another `op(`, which no
   struct may define, or 0 none of these */
static int function_shape(int i) {
    Token *t = &toks[i];
    if ((t->kind == TK_IDENT || is_base_word(t)) && is_p(t + 1, ".") && (t[2].kind == TK_IDENT || is_kw(&t[2], "cstr")) &&
        is_p(t + 3, "("))
        return 1; /* T.cstr() defines a struct's text (#53) */
    if (t->kind == TK_IDENT && is_p(t + 1, "("))
        return 2;
    if (overloadable_op(t) && is_p(t + 1, "("))
        return 3;
    if (t->kind == TK_PUNCT && is_p(t + 1, "(") && !is_p(t, "(") && !is_p(t, ";"))
        return 4;
    return 0;
}

/* Do parameters follow the `(` at token i: `)`, `...`, `var` or `name:`?
   Otherwise `name(` is a call or C's statement words, such as _Pragma */
static bool params_ahead(int i) {
    Token *t = &toks[i + 1];
    return is_p(t, ")") || is_p(t, "...") || is_kw(t, "var") || (t->kind == TK_IDENT && is_p(t + 1, ":"));
}

static void check_overload(Decl *d, Token *name);

static Decl *parse_fn(Pos pos, const char *storage) {
    Decl *d = new_decl(D_FN, pos, storage);
    Token *name = peek();
    d->imported = name->imported;
    if (name->kind == TK_PUNCT) { /* +(a:T, b:U):R, an operator (#42) */
        d->op = advance()->text;
        d->name = strfmt("operator%s", d->op);
    } else {
        reject_kv_name(name);
        d->name = expect_ident("a function name");
    }
    if (!strcmp(d->name, "print") || !strcmp(d->name, "println"))
        error_at(name->pos, "'%s' is part of the Kelvin prelude and cannot be redefined", d->name);
    if (!d->op)
        declare_name(d->name);
    open_scope();
    params_start = scope_names.len;
    expect_p("(");
    while (!is_p(peek(), ")")) {
        if (accept_p("...")) {
            if (d->params.len == 0)
                error_at(pos, "a variadic function needs at least one named parameter");
            d->variadic = true;
            break;
        }
        bool mutable = accept_kw("var"); /* parameters are lets unless var (#27) */
        reject_c_fn_pointer(cur, "");
        Var *p = parse_var(false, LET_NONE);
        p->is_let = !mutable;
        p->number = numeric_type(param_type(p->type));
        declare_binding(p->name, param_type(p->type), p->is_let ? LET_PARAM : LET_NONE);
        list_push(&d->params, p);
        if (!accept_p(","))
            break;
    }
    expect_p(")");
    params_end = scope_names.len;
    if (accept_p(":")) {
        d->ret = parse_type();
        if (typeof_names_local(d->ret))
            error_at(d->ret->pos, "the result type, %s, names a parameter, which C has not seen where it writes the "
                                  "result: write the type itself",
                     kelvin_type(d->ret));
    }
    check_overload(d, name);
    list_push(&functions, d);
    /* a prototype ends with `;` or a new line (#35); a body is a block */
    if (!accept_p(";") && (is_p(peek(), "{") || !(newline_before() || peek()->kind == TK_EOF))) {
        parsing_fn = d;
        d->body = parse_fn_body(expect_p("{"));
        parsing_fn = NULL;
        implicit_return(d);
    }
    close_scope();
    return d;
}

/* A function's overloads (#41) differ in their parameter types; one of
   the same types is its prototype or definition, with the same result.
   main has one form. An operator (#42) takes one or two values, at least
   one of a Kelvin struct or union, and has a result. */
static void check_overload(Decl *d, Token *name) {
    if (d->op) {
        int n = d->params.len;
        if ((n != 2 && !(n == 1 && !strcmp(d->op, "-"))) || d->variadic)
            error_at(name->pos, "operator %s takes %s", d->op, !strcmp(d->op, "-") ? "one or two values" : "two values");
        bool record = false;
        for (int k = 0; k < n; k++)
            record = record || kelvin_record(((Var *)d->params.data[k])->type);
        if (!record)
            error_at(name->pos, "an operator is for a Kelvin struct or union: at least one of its values must be one");
        if (!d->ret)
            error_at(name->pos, "operator %s has no result: write its type, as in 'let %s(...):T'", d->op, d->op);
    }
    for (int i = 0; i < functions.len; i++) {
        Decl *e = functions.data[i];
        if (e->recv || (d->op ? !e->op || strcmp(e->op, d->op) : e->op || strcmp(e->name, d->name)))
            continue;
        if (!strcmp(d->name, "main") && strcmp(signature(e), signature(d)))
            error_at(name->pos, "main cannot be overloaded: it is C's main, with one form");
        if (strcmp(signature(e), signature(d)))
            continue;
        if ((!e->ret) != (!d->ret) || (e->ret && strcmp(kelvin_type(e->ret), kelvin_type(d->ret))))
            error_at(name->pos, "'%s' is declared with these parameter types already, with another result: "
                                "overloads differ in their parameter types",
                     d->op ? d->op : d->name);
    }
}

/* type.name(params): T { ... }, a method with an implicit `self`. The
   receiver is a struct or union declared earlier, or a built-in type. */
static void check_text_method(Decl *d, Token *name);

static Decl *parse_method(Pos pos, const char *storage) {
    Token *recv = advance();
    advance(); /* . */
    Token *name = peek();
    Decl *d = new_decl(D_FN, pos, storage);
    reject_kv_name(name);
    /* T.cstr() defines a struct's or union's text (#53) */
    d->text_method = is_kw(name, "cstr");
    d->name = d->text_method ? advance()->text : expect_ident("a method name");
    d->recv_name = recv->text;
    if (!strcmp(d->name, "toString") || !strcmp(d->name, "fmt"))
        error_at(name->pos, "%s() " SHELVED_HINT, d->name);
    if (d->text_method && recv->kind == TK_KEYWORD)
        error_at(name->pos, "a built-in type's text is fixed: '.cstr' may be defined for a struct or a union (#53)");
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
    params_start = scope_names.len;
    declare_typed("self", d->recv);
    expect_p("(");
    while (!is_p(peek(), ")")) {
        if (accept_p("...")) {
            d->variadic = true;
            break;
        }
        bool mutable = accept_kw("var"); /* parameters are lets unless var (#27) */
        reject_c_fn_pointer(cur, "");
        Var *p = parse_var(false, LET_NONE);
        p->is_let = !mutable;
        p->number = numeric_type(param_type(p->type));
        declare_binding(p->name, param_type(p->type), p->is_let ? LET_PARAM : LET_NONE);
        list_push(&d->params, p);
        if (!accept_p(","))
            break;
    }
    expect_p(")");
    params_end = scope_names.len;
    if (accept_p(":")) {
        d->ret = parse_type();
        if (typeof_names_local(d->ret))
            error_at(d->ret->pos, "the result type, %s, names a parameter, which C has not seen where it writes the "
                                  "result: write the type itself",
                     kelvin_type(d->ret));
    }
    list_push(&functions, d);
    /* a prototype ends with `;` or a new line (#35); a body is a block */
    if (!accept_p(";") && (is_p(peek(), "{") || !(newline_before() || peek()->kind == TK_EOF))) {
        parsing_fn = d;
        d->body = parse_fn_body(expect_p("{"));
        parsing_fn = NULL;
        if (d->text_method)
            check_text_method(d, name); /* before the body's last value is its result */
        implicit_return(d);
    }
    if (d->text_method && !d->body)
        error_at(name->pos, "'.cstr' of %s needs its body here: a prototype is not needed", d->recv_name);
    close_scope();
    return d;
}

/* T.cstr() (#53): no parameters, a cstr result, a body that is one
   template literal, whose text kelvinc writes into the caller's buffer
   as the derived text would be; one per type */
static void check_text_method(Decl *d, Token *name) {
    if (d->params.len || d->variadic)
        error_at(name->pos, "'.cstr' takes no parameters: it is a property, read as 'v.cstr'");
    if (!d->ret || !is_cstr(d->ret))
        error_at(name->pos, "'.cstr' gives a cstr: write '%s.cstr():cstr'", d->recv_name);
    Stmt *only = d->body->stmts.len == 1 ? d->body->stmts.data[0] : NULL;
    if (!only || (only->kind != S_RETURN && only->kind != S_EXPR) || !only->expr ||
        (only->expr->kind != E_TEMPLATE && only->expr->kind != E_STRING))
        error_at(name->pos, "the body of '.cstr' is one template literal, as in '{ `(${self.x}, ${self.y})` }': its "
                            "text goes into the caller's buffer, which kelvinc sizes from the template (#53)");
    for (int i = 0; i < functions.len; i++) {
        Decl *e = functions.data[i];
        if (e != d && e->text_method && !strcmp(e->recv_name, d->recv_name))
            error_at(name->pos, "'.cstr' of %s is defined already", d->recv_name);
    }
}

static Decl *parse_record(Pos pos, DeclKind kind) {
    /* enum T { none; some: i32 }: a case with a value makes an enum with
       values, a tagged union, a struct in C (#61) */
    bool tagged = kind == D_ENUM && peek()->kind == TK_IDENT && is_p(peek2(), "{") && brace_has_colon(cur + 1);
    Decl *d = new_decl(tagged ? D_STRUCT : kind, pos, NULL);
    d->tagged = tagged;
    if (kind == D_ENUM && is_p(peek(), "{"))
        d->name = NULL; /* anonymous enum: a group of int constants */
    else {
        reject_kv_name(peek());
        d->name = expect_ident("a tag name");
    }
    list_push(&records, d);
    if (accept_p("{")) {
        d->has_body = true;
        if (tagged)
            parse_cases(d);
        while (!tagged && !is_p(peek(), "}")) {
            reject_inner_import();
            if (kind == D_ENUM) {
                Var *v = xcalloc(1, sizeof *v);
                v->pos = peek()->pos;
                reject_kv_name(peek());
                v->name = expect_ident("an enumerator");
                declare_name(v->name);
                if (accept_p("="))
                    v->init = parse_conditional();
                list_push(&d->members, v);
                if (!accept_p(","))
                    break;
            } else {
                do {
                    reject_c_fn_pointer(cur, "");
                    Var *m = parse_var(false, LET_NONE);
                    if (kind == D_UNION && is_owner(m->type))
                        error_at(m->pos, "a union cannot hold an owner (#54): which member to free is unknown");
                    list_push(&d->members, m);
                } while (accept_p(","));
                end_statement();
            }
        }
        expect_p("}");
    }
    end_statement();
    return d;
}

/* {x:f64, y:f64} (#59): a struct with no tag, by its members alone. One
   spelling is one C struct, _kv_anonN, declared before the top-level
   declaration that first writes it, so that two written alike are one
   type; its derived .cstr, free and take come with it as any struct's */
static Type *parse_anon_record(DeclKind kind, bool tagged) {
    Token *open = expect_p("{");
    Decl *d = new_decl(kind, open->pos, NULL);
    d->has_body = true;
    d->tagged = tagged;
    bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
    brace_ends_condition = brace_in_for = false;
    if (tagged)
        parse_cases(d);
    while (!tagged && !is_p(peek(), "}")) {
        reject_inner_import();
        do {
            reject_c_fn_pointer(cur, "");
            Var *m = parse_var(false, LET_NONE);
            if (kind == D_UNION && is_owner(m->type))
                error_at(m->pos, "a union cannot hold an owner (#54): which member to free is unknown");
            list_push(&d->members, m);
        } while (accept_p(","));
        end_statement();
    }
    brace_ends_condition = saved_brace;
    brace_in_for = saved_for;
    expect_p("}");
    if (!d->members.len)
        error_at(open->pos, "%s with no tag names its %s: %s", tagged ? "an enum" : kind == D_UNION ? "a union" : "a struct",
                 tagged ? "cases" : "members", tagged ? "enum{i:i32, f:f32}" : kind == D_UNION ? "union{i:i32, f:f32}" : "{x:f64, y:f64}");
    Buf b = {0};
    buf_puts(&b, tagged ? "enum{" : kind == D_UNION ? "union{" : "{");
    for (int i = 0; i < d->members.len; i++) {
        Var *m = d->members.data[i];
        if (m->type)
            buf_printf(&b, "%s%s: %s", i ? ", " : "", m->name, kelvin_type(m->type));
        else
            buf_printf(&b, "%s%s", i ? ", " : "", m->name);
    }
    buf_puts(&b, "}");
    Decl *same = NULL;
    for (int i = 0; !same && i < anon_records.len; i++)
        if (!strcmp(((Decl *)anon_records.data[i])->spelling, b.buf))
            same = anon_records.data[i];
    if (!same) {
        d->name = strfmt("_kv_anon%d", anon_records.len + 1);
        d->spelling = b.buf;
        list_push(&anon_records, d);
        list_push(&records, d);
        list_push(&program->decls, d);
        same = d;
    }
    return base_type(tag_type_name(same), open->pos);
}

static Decl *anon_record_of(Type *t) {
    if (!t || t->kind != T_BASE || !t->name)
        return NULL;
    const char *n = !strncmp(t->name, "struct _kv_anon", 15) ? t->name + 7 : !strncmp(t->name, "union _kv_anon", 14) ? t->name + 6 : NULL;
    Decl *r = n ? record_named(n) : NULL;
    return r && r->spelling ? r : NULL;
}

/* ---------- an enum with values (#61): a tagged union ---------- */

/* Is there a `:` at depth 1 inside the {...} group at i? */
static bool brace_has_colon(int i) {
    int end = skip_nested(i);
    for (int k = i + 1, depth = 0; k < end; k++) {
        if (is_p(&toks[k], "(") || is_p(&toks[k], "[") || is_p(&toks[k], "{"))
            depth++;
        else if (is_p(&toks[k], ")") || is_p(&toks[k], "]") || is_p(&toks[k], "}"))
            depth--;
        else if (depth == 0 && is_p(&toks[k], ":"))
            return true;
    }
    return false;
}

/* the cases of enum T { none; some: i32 }: a name, with a value's type
   after `:` or none, separated by `,`, `;` or a line break */
static void parse_cases(Decl *d) {
    while (!is_p(peek(), "}")) {
        reject_inner_import();
        do {
            Var *v = xcalloc(1, sizeof *v);
            v->pos = peek()->pos;
            reject_kv_name(peek());
            v->name = expect_ident("a case name");
            if (case_named(d, v->name, NULL))
                error_at(v->pos, "case '%s' is written twice", v->name);
            if (accept_p(":"))
                v->type = parse_type_in(TYPE_DECL);
            if (is_p(peek(), "="))
                error_at(peek()->pos, "a case of an enum with values is known by its name, not by a number");
            list_push(&d->members, v);
        } while (accept_p(","));
        end_statement();
    }
    if (d->members.len > 255)
        error_at(d->pos, "an enum with values has up to 255 cases: its tag is one byte");
}

/* the value given to a case (#61): an expression, or, for a case of a
   struct or array type, its initializer list, as (T){...} */
static Expr *case_value(Type *t) {
    Decl *r;
    bool list = is_p(peek(), "{") && t && ((t->kind == T_BASE && type_class(t, &r) == 's') || t->kind == T_ARRAY);
    Expr *v;
    if (list) {
        v = new_expr(E_COMPOUND, peek()->pos);
        v->type = t;
        v->a = parse_initializer_for(t);
        count_items(t, v->a);
    } else {
        v = parse_assign();
        pick_overload(v, t);
        v = drop_cstr(v, t);
    }
    return v;
}

static Var *case_named(Decl *r, const char *name, int *index) {
    for (int i = 0; i < r->members.len; i++) {
        Var *m = r->members.data[i];
        if (!strcmp(m->name, name)) {
            if (index)
                *index = i;
            return m;
        }
    }
    return NULL;
}

/* the record of t, if it is an enum with values */
static Decl *tagged_record(Type *t) {
    Decl *r = NULL;
    if (t && type_class(t, &r) == 's' && r && r->tagged)
        return r;
    return NULL;
}

static char *case_list(Decl *r) {
    Buf b = {0};
    buf_puts(&b, "");
    for (int i = 0; i < r->members.len; i++)
        buf_printf(&b, "%s%s", i ? ", " : "", ((Var *)r->members.data[i])->name);
    return b.buf;
}

/* the spelling of a record in a message: its name, or its members */
static char *record_spelling(Decl *r) {
    if (r->spelling)
        return r->spelling;
    return r->name;
}

/* {.n = 1.5} or {.none} of an enum with values (#61): one case, by its
   name; in C, {.tag = k, .u.n = 1.5} */
static Expr *parse_case_initializer(Type *t, Decl *r) {
    (void)t;
    Token *open = expect_p("{");
    Expr *e = new_expr(E_INIT, open->pos);
    bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
    brace_ends_condition = brace_in_for = false;
    init_depth++;
    if (is_p(peek(), "}")) { /* {}: the first case, zeroed */
        init_depth--;
        brace_ends_condition = saved_brace;
        brace_in_for = saved_for;
        advance();
        return e;
    }
    Var *first = r->members.data[0];
    if (!accept_p("."))
        error_at(peek()->pos, "a case of %s is written by its name: {.%s%s}", record_spelling(r), first->name,
                 first->type ? " = ..." : "");
    Token *cn = peek();
    char *name = expect_ident("a case name");
    int k;
    Var *c = case_named(r, name, &k);
    if (!c)
        error_at(cn->pos, "%s has no case '%s': the cases are %s", record_spelling(r), name, case_list(r));
    Expr *tag = new_expr(E_FIELD, cn->pos);
    tag->text = "tag";
    Expr *kv = new_expr(E_LITERAL, cn->pos);
    kv->text = strfmt("%d", k);
    list_push(&e->designators, tag);
    list_push(&e->items, kv);
    if (c->type) {
        if (!accept_p("="))
            error_at(peek()->pos, "case '%s' carries a value: write {.%s = ...}", c->name, c->name);
        Expr *v = drop_cstr(parse_initializer_for(c->type), c->type);
        reject_owner_copy(v, c->type, v->pos);
        reject_record_mismatch(v, c->type, v->pos);
        Expr *u = new_expr(E_FIELD, cn->pos);
        u->text = "u";
        Expr *d = new_expr(E_FIELD, cn->pos);
        d->a = u;
        d->text = c->name;
        list_push(&e->designators, d);
        list_push(&e->items, v);
    } else if (is_p(peek(), "=")) {
        error_at(peek()->pos, "case '%s' carries no value: write {.%s}", c->name, c->name);
    }
    if (accept_p(",") && !is_p(peek(), "}"))
        error_at(peek()->pos, "an enum with values holds one case at a time: write one");
    init_depth--;
    brace_ends_condition = saved_brace;
    brace_in_for = saved_for;
    expect_p("}");
    return e;
}

/* A top-level declaration and the anonymous functions in it (#32):
   declared before it, so that it may use them, and defined after it, so
   that they may use it and everything it declares */
static void add_top_decl(Program *prog, Decl *d) {
    if (anon_fns.len && (d->kind == D_STRUCT || d->kind == D_UNION) && d->name) {
        Decl *tag = xcalloc(1, sizeof *tag); /* struct s; for the prototypes */
        *tag = *d;
        tag->has_body = false;
        tag->members = (List){0};
        list_push(&prog->decls, tag);
    }
    for (int i = 0; i < anon_fns.len; i++) {
        Decl *proto = xcalloc(1, sizeof *proto);
        *proto = *(Decl *)anon_fns.data[i];
        proto->body = NULL;
        list_push(&prog->decls, proto);
    }
    list_push(&prog->decls, d);
    for (int i = 0; i < anon_fns.len; i++)
        list_push(&prog->decls, anon_fns.data[i]);
    anon_fns.len = 0;
}

Program *parse(Token *tokens, int ntoks) {
    (void)ntoks;
    c_called = (List){0};
    toks = tokens;
    cur = 0;
    anon_fns = (List){0};
    anon_records = (List){0};
    anon_names = (List){0};
    top_name = NULL;
    anon_start = -1;
    fn_at = -1;
    trailing_end = -1;
    stmt_start = 0;
    pending_note = anon_note = NULL;
    body_after_call = block_after_call = -1;
    body_first = body_end = -1;
    init_depth = 0;
    in_signature = false;
    scope_names = (List){0};
    scope_types = (List){0};
    scope_lets = (List){0};
    scope_moved = (List){0};
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
    program = prog;
    while (peek()->kind != TK_EOF) {
        Token *t = peek();
        if (t->kind == TK_IMPORT_K || t->kind == TK_FILE_END) { /* where an imported file begins and ends (#40) */
            advance();
            continue;
        }
        if (t->kind == TK_IMPORT) {
            Decl *d = new_decl(D_IMPORT, t->pos, NULL);
            d->name = advance()->text;
            list_push(&prog->decls, d);
            continue;
        }
        stmt_start = cur;
        top_name = NULL;
        const char *storage = parse_storage();
        /* a function, a method and an operator are lets (#45) */
        bool binding = is_kw(peek(), "let") || is_kw(peek(), "var");
        int shape = function_shape(cur + binding);
        if (shape && shape != 4) {
            if (shape == 2)
                reject_c_fn_pointer(cur + binding, "var ");
            Token *n = &toks[cur + binding];
            char *how = strfmt("%s%slet %s%s%s(...)", storage ? storage : "", storage ? " " : "", n->text,
                               shape == 1 ? "." : "", shape == 1 ? n[2].text : "");
            if (!binding && !params_ahead(cur + (shape == 1 ? 3 : 1)))
                error_at(n->pos, "expected a declaration (let name(...):type, let or var name, struct, union, enum), "
                                 "found %s: a statement goes in a function",
                         desc(n));
            if (!binding)
                error_at(n->pos, "a function is declared with let: write '%s'", how);
            if (is_kw(peek(), "var"))
                error_at(peek()->pos, "a function is a let: write '%s', or, for a variable holding a function, "
                                      "'var f:(T):R := g'",
                         how);
            advance();
        } else if (shape == 4 && binding) {
            advance();
        }
        if ((peek()->kind == TK_IDENT || is_base_word(peek())) && is_p(peek2(), ".") &&
            (peek_at(2)->kind == TK_IDENT || is_kw(peek_at(2), "cstr")) && is_p(peek_at(3), "(")) {
            top_name = strfmt("%s_%s", peek()->text, peek_at(2)->text);
            add_top_decl(prog, parse_method(t->pos, storage));
        } else if (peek()->kind == TK_IDENT && is_p(peek2(), "(")) {
            reject_c_fn_pointer(cur, "var ");
            top_name = peek()->text;
            add_top_decl(prog, parse_fn(t->pos, storage));
        } else if (overloadable_op(peek()) && is_p(peek2(), "(")) {
            add_top_decl(prog, parse_fn(t->pos, storage)); /* +(a:T, b:U):R { ... } (#42) */
        } else if (peek()->kind == TK_PUNCT && is_p(peek2(), "(") && !is_p(peek(), "(") && !is_p(peek(), ";")) {
            error_at(peek()->pos, "'%s' cannot be defined: an operator a struct defines is one of + - * / %% == != "
                                  "< <= > >=, or unary -, and 'x op= y' is 'x = x op y'",
                     peek()->text);
        } else if (is_kw(peek(), "let") || is_kw(peek(), "var")) {
            /* one declaration per global, each after the anonymous
               functions' prototypes in its initializer (#32), so that
               those may use the globals before it */
            bool is_let = is_kw(advance(), "let");
            do {
                Decl *d = new_decl(D_VAR, t->pos, storage);
                top_name = peek()->kind == TK_IDENT ? peek()->text : NULL;
                parse_var_one(&d->members, is_let, storage);
                add_top_decl(prog, d);
            } while (accept_p(","));
            end_statement();
        } else if (peek()->kind == TK_IDENT && (is_p(peek2(), ":") || is_p(peek2(), "=") || is_p(peek2(), ":="))) {
            error_at(peek()->pos, "declarations start with let or var: write 'var %s ...', or 'let %s ...' if it "
                                  "never changes",
                     peek()->text, peek()->text);
        } else if (!storage && accept_kw("struct")) {
            top_name = peek()->kind == TK_IDENT ? peek()->text : NULL;
            add_top_decl(prog, parse_record(t->pos, D_STRUCT));
        } else if (!storage && accept_kw("union")) {
            top_name = peek()->kind == TK_IDENT ? peek()->text : NULL;
            add_top_decl(prog, parse_record(t->pos, D_UNION));
        } else if (!storage && accept_kw("enum")) {
            top_name = peek()->kind == TK_IDENT ? peek()->text : NULL;
            add_top_decl(prog, parse_record(t->pos, D_ENUM));
        } else {
            error_at(peek()->pos, "expected a declaration (let name(...):type, let or var name, struct, union, enum), found %s", desc(peek()));
        }
    }
    name_functions();
    return prog;
}
