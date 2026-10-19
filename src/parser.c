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

static bool is_kw(Token *t, const char *kw);
static bool is_converter(Token *t);
static int skip_group(int i);

/* Is the token a member's name after `.`: a name, or cstr, a converter's
   name, case or union, which are keywords? */
static bool member_name_token(Token *t) {
    return t->kind == TK_IDENT || is_kw(t, "cstr") || is_converter(t) || is_kw(t, "case") || is_kw(t, "union");
}

/* Is `.x` at token i self.x (#139): a member's name after the `.`, in a
   body that has self? */
static int implicit_self_at = -1; /* the token of the `.` that an implicit self begins (#139) */
static bool self_member_ahead(int i) {
    return toks[i].kind == TK_PUNCT && !strcmp(toks[i].text, ".") && member_name_token(&toks[i + 1]) &&
           binding_index("self") >= 0;
}

/* Is the item of an initializer at token i a designator, `.x = v` or
   `[2] = v`, the chain followed by `=`? In a function, `.x` that is not
   one is self.x, or an error where there is no self (#139) */
static bool designator_ahead(int i) {
    int j = i;
    for (;;) {
        if (toks[j].kind == TK_PUNCT && !strcmp(toks[j].text, ".") && member_name_token(&toks[j + 1]))
            j += 2;
        else if (toks[j].kind == TK_PUNCT && !strcmp(toks[j].text, "["))
            j = skip_group(j);
        else
            break;
    }
    return j > i && toks[j].kind == TK_PUNCT && !strcmp(toks[j].text, "=");
}

static bool at_statement_level(void);

/* Does the new line at token i start a statement, .x being self.x (#139,
   #142)? A .member on a new line goes on with the expression before it
   (#35), but where there is self, a line that starts with .x is self's: a
   chain over several lines goes inside parentheses there */
static bool self_statement_at(int i) {
    return i > 0 && i != implicit_self_at && self_member_ahead(i) && line_break(&toks[i - 1], &toks[i]) &&
           at_statement_level();
}

/* Is name declared in the innermost scope? */
static bool bound_here(const char *name) {
    return scope_marks.len && binding_index(name) >= (int)(intptr_t)scope_marks.data[scope_marks.len - 1];
}

/* the function or method being parsed, and where its parameters sit in
   scope_names */
static Decl *parsing_fn;
bool lib_mode;

/* Is the token from a module's header, M.kh (#146), where a prototype is
   the library's own function? */
static bool in_kh(Pos p) {
    size_t n = p.file ? strlen(p.file) : 0;
    return n > 3 && !strcmp(p.file + n - 3, ".kh");
}
static List modules_imported; /* char *: the modules brought in so far, IO, OS, JSON (#143) */

static bool module_imported(const char *name) {
    for (int i = 0; i < modules_imported.len; i++)
        if (!strcmp(modules_imported.data[i], name))
            return true;
    return false;
}

/* IO (#144) and OS with SYS (#145) are modules: a program imports them */
static void require_module(const char *name, Pos pos) {
    bool sys = !strcmp(name, "SYS");
    if (module_imported(sys ? "OS" : name))
        return;
    if (sys)
        error_at(pos, "SYS comes with OS, a module: write '#import <OS>' at the top of the file");
    error_at(pos, "%s is a module: write '#import <%s>' at the top of the file", name, name);
}
static bool infer_anon_result; /* .map { ... } (#80): the result is the body's, where kelvinc sees it */
static bool bare_tags; /* kelvin_type spells a struct bare, as point (#59) */
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
/* expression statements that give an owner and drop it (O4): decided
   when the function's body ends, since its one expression is returned
   (#81); a Bytes, a String, an Array, a Dictionary or a Set is freed at
   once, a struct that owns is an error */
static List pending_drops;
static void finish_drops(int from);
/* the structs with no tag (#59), Decl *, one per spelling, in order of first use */
static List anon_records;
static List anon_words; /* Decl *: the top-level enums with values that have no tag, whose cases are words (#120) */
static bool self_scope;    /* Self names the receiver's type (#140): in extend T { } and in a member of T */
static Token *self_tok;    /* that T, or NULL */
static Type *self_spelled; /* or its spelling, a type with no tag */
static bool in_extend;     /* inside extend T { } (#130): its members name no receiver */
static Token *ext_tok;     /* that T */
static Type *ext_spelled;  /* or its spelling, extend enum{...} { } */
static List type_attrs;    /* char *: the C names of the type attributes, point__count (#133) */
static void add_top_decl(Program *prog, Decl *d);
static void reject_attribute_member(Type *recv, Token *name);
static void flatten_commas(Expr *e, List *out);
static Decl *choose_subscript(const char *name, List *args, Pos pos, const char *type);
static Var *case_named(Decl *r, const char *name, int *k);
static Expr *case_maker(Token *t, Token *cn, Decl *r, Var *c);

/* the case `name` of a top-level anonymous enum with values (#120), if any */
static Var *anon_word(const char *name, Decl **r, int *k) {
    for (int i = 0; i < anon_words.len; i++) {
        Var *c = case_named(anon_words.data[i], name, k);
        if (c) {
            *r = anon_words.data[i];
            return c;
        }
    }
    return NULL;
}
static List anon_names;     /* their C names, _kv_main_fn and so on (#38) */
static const char *top_name; /* the top-level declaration being parsed */
static int anon_start = -1;
/* the temporaries of the expression being parsed (#187): owners that an
   expression gives, held in hidden locals until the postfix chain, or the
   comparison, they are used in is done; NULL where none can be held */
static List *chain_temps;
static int temp_serial;
static Decl *nested_outer; /* the function a function being parsed is defined inside (#180) */
static List proto_copies;  /* the prototype copies of hoisted functions and their originals, in pairs (#180) */
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
        if (i >= global_end) { /* a local: a function defined in the block (#180), or a variable */
            for (int j = functions.len - 1; j >= 0; j--) {
                Decl *d = functions.data[j];
                if (d->nested_in && !d->recv && d->bind_index == i && !strcmp(d->name, name))
                    return d;
            }
            return NULL;
        }
        for (int j = 0; j < functions.len; j++) {
            Decl *d = functions.data[j];
            if (!d->recv && !d->nested_in && !strcmp(d->name, name))
                return d;
        }
        return NULL;
    }
    return NULL;
}

/* Is name bound in a block, not at the top level? (#180) */
static bool bound_in_block(const char *name) {
    int global_end = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
    for (int i = scope_names.len - 1; i >= 0; i--)
        if (!strcmp(scope_names.data[i], name))
            return i >= global_end;
    return false;
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
                                   "u64", "u128", "f32", "f64", "bool", "_Complex", "any", "cstr", "Bytes", "String", "uchr", "Array", "Dictionary", "Set", "Optional", "Result", "IO", NULL};

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
    return is_base_word(t) && !is_kw(t, "any") && !is_kw(t, "_Complex") && !is_kw(t, "cstr") && !is_kw(t, "Bytes") && !is_kw(t, "String") && !is_kw(t, "Array") && !is_kw(t, "Dictionary") && !is_kw(t, "Set") && !is_kw(t, "Optional") && !is_kw(t, "Result") && !is_kw(t, "IO");
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
static bool is_in(Token *t);
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
/* A receiver spelled as a type at token i, `enum{...}`, `union{...}` or
   `{...}`, followed by `.name(` (#121): the index of the `.`, or -1 */
static int spelled_receiver(int i) {
    int open = is_p(&toks[i], "{") ? i
               : (is_kw(&toks[i], "enum") || is_kw(&toks[i], "union") || is_kw(&toks[i], "struct")) && is_p(&toks[i + 1], "{")
                   ? i + 1
                   : -1;
    if (open < 0)
        return -1;
    int j = skip_nested(open);
    return is_p(&toks[j], ".") && (toks[j + 1].kind == TK_IDENT || is_kw(&toks[j + 1], "cstr")) &&
                   (is_p(&toks[j + 2], "(") || is_p(&toks[j + 2], ":") || is_p(&toks[j + 2], "="))
               ? j
               : -1; /* .name( a method; .name: or .name = an attribute (#131, #133) */
}

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
        else if ((is_p(&toks[i], "?") || is_p(&toks[i], "??")) &&
                 (line_break(&toks[i], &toks[i + 1]) || !starts_operand(&toks[i + 1]) || is_in(&toks[i + 1])))
            i++; /* T? is Optional<T> (#72), T?? twice; a ? b : c and x ?? y go on with an operand; `in` ends an
                    anonymous function's result type, {(a:T):U? in ...} (#114) */
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
static bool is_io(Type *t);
static bool is_io_std(Expr *e);
static bool number_expr(Expr *e);
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
static bool eq_operand_ok(Expr *x);
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
    if (is_p(&toks[i], "$") && is_p(&toks[i + 1], "{")) /* ${K: V}, a Dictionary<K, V> (#70) */
        return type_suffix_end(skip_nested(i + 1));
    if (is_kw(&toks[i], "Result") && is_p(&toks[i + 1], "<")) { /* Result<T, U> (#75) */
        int e = type_shape_end(i + 2);
        if (e < 0 || !is_p(&toks[e], ","))
            return -1;
        e = type_shape_end(e + 1);
        if (e < 0 || (!is_p(&toks[e], ">") && !is_p(&toks[e], ">>")))
            return -1;
        return type_suffix_end(is_p(&toks[e], ">>") ? e : e + 1);
    }
    if (is_kw(&toks[i], "Optional") && is_p(&toks[i + 1], "<")) { /* Optional<T> (#72) */
        int e = type_shape_end(i + 2);
        if (e < 0 || (!is_p(&toks[e], ">") && !is_p(&toks[e], ">>")))
            return -1;
        return type_suffix_end(is_p(&toks[e], ">>") ? e : e + 1);
    }
    if (is_kw(&toks[i], "Set") && is_p(&toks[i + 1], "<")) { /* Set<T> (#71) */
        int e = type_shape_end(i + 2);
        if (e < 0 || (!is_p(&toks[e], ">") && !is_p(&toks[e], ">>")))
            return -1;
        return type_suffix_end(is_p(&toks[e], ">>") ? e : e + 1);
    }
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
            return type_suffix_end(i); /* T? too, as {(a:T):U? in ...} writes it (#114) */
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
static Type *pipe_type(Token *at);
static Type *stat_type(Token *at);
static Type *temp_type(Token *at);
static Type *anon_struct(Token *at, const char *spec);
static const char *struct_spec(const char *gives);
static Type *parse_dollar_array(Token *at);
static Type *parse_dollar_dict(Token *at);
static Type *dict_type(Token *at, Type *key, Type *val);
static bool is_dict_owner(Type *t);
static Type *set_type(Token *at, Type *elem);
static char owner_letter(const char *kind);
static Type *optional_type(Token *at, Type *inner);
static Type *variant_type(Token *at, const char *kind, Type *a, Type *b);
static Decl *optional_record(Type *t);
static Decl *variant_record(Type *t);
static int value_case(Decl *r);
static Expr *optional_of(Expr *v, Type *target, Pos pos);
static Type *parse_optional_type(Token *kw);
static Type *parse_result_type(Token *kw);
static Expr *variant_constructor(Token *t, Type *vt);
static bool starts_operand(Token *t);
static bool is_set_owner(Type *t);
static bool showable(Type *t);
static Type *parse_set_type(Token *kw);
static Expr *set_of_list(Token *t, Type *st, Token *open, Expr *first);
static Type *parse_dict_types(Token *kw);
static Expr *dict_of_list(Token *t, Type *dt, Token *open, Expr *first);
static Expr *dict_key(Expr *k, Type *dt);
static Expr *string_of_literal(Expr *x, Type *target);
static Type *inferred_type(Expr *e, Pos pos);
static Expr *property(Expr *e, Token *name, char *member);
static bool is_text_type(Type *t);
static bool is_text_expr(Expr *e);
static Type *array_type(Token *at, Type *elem);
static Decl *anon_record_of(Type *t);
static void reject_kv_name(Token *t);
static void parse_cases(Decl *d);
static void set_no_eq(Decl *d);
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
/* Self is the receiver's type, T, inside extend T { } and in a method,
   an attribute or a subscript of T, as Swift's Self (#140): the token
   becomes T's. A type with no tag has no name, so Self there is only a
   type, read in parse_type_in */
static void self_word(Token *t) {
    if (t->kind != TK_IDENT || strcmp(t->text, "Self"))
        return;
    if (!self_scope)
        error_at(t->pos, "'Self' is the type's name inside 'extend T { }' and in a method, an attribute or a subscript "
                         "of T: here there is no T");
    if (self_spelled)
        error_at(t->pos, "'Self' here is a type with no tag, which has no name to call a function by: write a method, "
                         "or the type's spelling");
    t->text = self_tok->text;
    t->kind = self_tok->kind;
}

static void rewrite_self(int i, Token *recv);

/* `:()` after the parameters: no result, C's void, written out (#141);
   `:():R` is a function type as the result */
static bool void_result_ahead(void) {
    return is_p(peek(), "(") && is_p(peek2(), ")") && !is_p(peek_at(2), ":");
}

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
                                           is_kw(n, "enum") ||
                                           (is_p(n, "(") && is_p(peek_at(2), ")") && !is_p(peek_at(3), ":"))));
    if (result) {
        advance();
        if (void_result_ahead()) { /* (T):() gives nothing (#141) */
            advance();
            advance();
        } else
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
    if (is_kw(peek(), "Result")) { /* Result<T, U> (#75) */
        Token *kw = advance();
        Type *t = parse_result_type(kw);
        t->is_const = base->is_const;
        t->is_volatile = base->is_volatile;
        parse_qualifiers(t);
        type_start = cur;
        return parse_type_suffixes(t, ctx);
    }
    if (is_kw(peek(), "Optional")) { /* Optional<T> (#72) */
        Token *kw = advance();
        Type *t = parse_optional_type(kw);
        t->is_const = base->is_const;
        t->is_volatile = base->is_volatile;
        parse_qualifiers(t);
        type_start = cur;
        return parse_type_suffixes(t, ctx);
    }
    if (is_kw(peek(), "Set")) { /* Set<T> (#71) */
        Token *kw = advance();
        if (base->is_const || base->is_volatile)
            error_at(base->pos, "a qualifier of a Set is the variable's: a let does not change");
        Type *t = parse_set_type(kw);
        type_start = cur;
        return parse_type_suffixes(t, ctx);
    }
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
    if (is_p(peek(), "$")) { /* $[T] is Array<T>, $[[T]] Array<Array<T>> (#64); ${K: V} Dictionary<K, V> (#70) */
        Token *d = advance();
        if (!is_p(peek(), "[") && !is_p(peek(), "{"))
            error_at(d->pos, "'$' before a type: $[T] is Array<T> and ${K: V} Dictionary<K, V>, as $[a, b] and ${k: v} "
                             "are the values; a String is written String");
        if (base->is_const || base->is_volatile)
            error_at(base->pos, "a qualifier of an Array or a Dictionary is the variable's: a let does not change");
        Type *t = is_p(peek(), "{") ? parse_dollar_dict(d) : parse_dollar_array(d);
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
        if (peek()->kind == TK_IDENT && !strcmp(peek()->text, "Self") && self_scope && self_spelled) {
            /* Self of a type with no tag (#140): its spelling */
            advance();
            Type *t = xcalloc(1, sizeof *t);
            *t = *self_spelled;
            t->is_const = base->is_const;
            t->is_volatile = base->is_volatile;
            parse_qualifiers(t);
            type_start = cur;
            return parse_type_suffixes(t, ctx);
        }
        self_word(peek()); /* Self is T (#140) */
        reject_c_int_name(peek());
        Token *name = peek();
        if (name->kind != TK_IDENT && (!is_base_word(name) || is_kw(name, "_Complex")))
            error_at(name->pos, "expected a type, found %s", desc(name));
        if (is_kw(name, "IO"))
            require_module("IO", name->pos); /* the type too (#144) */
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
        if ((is_p(tok, "?") || is_p(tok, "??")) && ctx != TYPE_AS) { /* T? is Optional<T> (#72); T?? twice */
            advance();
            t = optional_type(tok, t);
            if (is_p(tok, "??"))
                t = optional_type(tok, t);
        } else if (accept_p("^")) {
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
static Type *arg_type(Expr *e);
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
static void borrow_temps(Expr *call, Decl *d);
static void reject_owners_to_c(Expr *call);
static List overloads_of(const char *name, const char *op);
static List method_candidates(Expr *recv, const char *name);
static Decl *parse_nested_fn(Pos pos);
static Expr *make_temp(Expr *src, const char *what);
static Expr *wrap_temps(Expr *body, List *temps);
static Type *arithmetic_type(Expr *e);
static const char *number_kind(Type *t);
static int call_args_ahead(int i);
static Type *method_param_type(List *cands, Decl *m, int k);
static bool method_takes_none(Expr *recv, const char *name);
static Decl *choose(List *cands, Expr **args, int nargs, List *maybe, Pos pos, const char *what);
static char *signature(Decl *d);
static bool user_operator_on(const char *op, Type *t);
static Expr *resolve_operator(Expr *e, const char *op, Expr *a, Expr *b);
static Expr *parse_initializer_for(Type *t);
static void count_items(Type *t, Expr *init);
static void check_print_args(Expr *call);
static void print_records_as_text(Expr *call);
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

/* Does the [...] at i hold a `..<` or `...` at its top level: a slice (#68)? */
static bool bracket_is_slice(int i) {
    int end = skip_group(i);
    for (int k = i + 1, depth = 0; k < end - 1; k++) {
        if (is_p(&toks[k], "(") || is_p(&toks[k], "[") || is_p(&toks[k], "{"))
            depth++;
        else if (is_p(&toks[k], ")") || is_p(&toks[k], "]") || is_p(&toks[k], "}"))
            depth--;
        else if (depth == 0 && (is_p(&toks[k], "..<") || is_p(&toks[k], "...")))
            return true;
    }
    return false;
}

/* At the top level of a statement, a `(` on a new line starts the next
   statement, as in Swift, rather than calling what went before (#35);
   an operator, `.member` or `[` there goes on with the expression */
static bool self_statement_at(int i);
static bool line_ends_expression(void) {
    return (is_p(peek(), "(") && newline_before() && at_statement_level()) || self_statement_at(cur);
}

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

/* An owner an expression gives, held (#187): a hidden let of its type,
   bound here, for the expression to use as a place, and freed once the
   chain around it is done; where none is open, the error what */
static Expr *make_temp(Expr *src, const char *what) {
    if (!chain_temps)
        error_at(src->pos, "%s", what);
    Type *t = unqualified(value_type(src));
    char *name = strfmt("_kv_tmp%d", ++temp_serial);
    declare_binding(name, t, LET_VALUE);
    Expr *tmp = new_expr(E_TEMP, src->pos);
    tmp->a = src;
    tmp->text = name;
    tmp->type = t;
    list_push(chain_temps, tmp);
    Expr *id = new_expr(E_IDENT, src->pos);
    id->text = name;
    return id;
}

/* body, inside the temporaries made for it (#187), the last made innermost;
   a pointer would point into what is freed, so it is an error, and an owner
   that is a place inside one is copied out before it goes */
static Expr *wrap_temps(Expr *body, List *temps) {
    if (!temps->len)
        return body;
    Type *rt = value_type(body);
    if (rt && (rt->kind == T_PTR || rt->kind == T_ARRAY) && body->kind != E_TEMPLATE) { /* a template's text is the block's */
        Expr *first = temps->data[0];
        error_at(body->pos, "this is %s into a %s that an expression gives, which is freed once the expression is done: "
                            "bind it to a variable first",
                 rt->kind == T_PTR ? "a pointer" : "an array", kelvin_type(first->type));
    }
    bool copy = rt && is_owner(rt) && owner_place(body);
    for (int i = temps->len - 1; i >= 0; i--) {
        Expr *t = temps->data[i];
        t->b = body;
        if (copy && i == temps->len - 1) { /* the innermost copies the place out */
            t->op = "copy";
            t->from = unqualified(rt);
        }
        body = t;
    }
    temps->len = 0;
    return body;
}

static Expr *parse_postfix_steps(Expr *e);
static Expr *parse_primary(void);

/* an operand that an expression gives, held in the list of the operator
   it is an operand of (#187), which wraps the operator's result */
static Expr *hold_operand(Expr *x, List *held) {
    List *saved = chain_temps;
    chain_temps = held;
    Expr *r = make_temp(x, "an operand that an expression gives: bind it to a variable first");
    chain_temps = saved;
    return r;
}

/* the postfix steps after e, with the temporaries they hold (#187) */
static Expr *parse_postfix_ops(Expr *e) {
    List temps = {0}, *saved = chain_temps;
    chain_temps = &temps;
    e = parse_postfix_steps(e);
    chain_temps = saved;
    return wrap_temps(e, &temps);
}

/* a primary and its postfix steps, a template's values among them, with
   the temporaries they hold (#187) */
static Expr *parse_postfix_chain(void) {
    List temps = {0}, *saved = chain_temps;
    chain_temps = &temps;
    Expr *e = parse_postfix_steps(parse_primary());
    chain_temps = saved;
    return wrap_temps(e, &temps);
}

static Expr *parse_postfix_steps(Expr *e) {
    for (;;) {
        if (line_ends_expression() || cur == postfix_stop)
            return e;
        Token *t = peek();
        if (is_p(peek(), "[") && is_string(value_type(e)) && !bracket_is_slice(cur))
            error_at(peek()->pos, "a String is not indexed by codepoint, which would walk it: walk it with 'for c in "
                                  "s', or index its bytes, 's.bytes^[i]'; a slice, 's[lo..<hi]', copies codepoints");
        if (is_p(peek(), "[") && is_bytes(value_type(e)) && !owner_place(e)) /* held (#187) */
            e = make_temp(e, "indexing a Bytes that an expression gives: bind it to a variable first");
        if (accept_p("[")) {
            bool saved = ident_annotation_ok;
            bool saved_brace = brace_ends_condition;
            ident_annotation_ok = true;
            brace_ends_condition = false;
            Expr *x = new_expr(E_INDEX, t->pos);
            x->a = e;
            bool slice = false, closed = false;
            if (is_p(peek(), "..<") || is_p(peek(), "...")) { /* [..<hi], [...hi] (#68) */
                slice = true;
                closed = is_p(peek(), "...");
                advance();
                x->c = parse_expr();
            } else {
                x->b = parse_expr();
                if (is_p(peek(), "..<") || is_p(peek(), "...")) { /* [lo..<hi], [lo...hi], [lo...] (#68) */
                    slice = true;
                    closed = is_p(peek(), "...");
                    advance();
                    if (!is_p(peek(), "]"))
                        x->c = parse_expr();
                    else if (!closed)
                        error_at(peek()->pos, "a slice to the end is written [lo...]; '..<' needs an end");
                    else
                        closed = false; /* [lo...] is lo..<count */
                }
            }
            ident_annotation_ok = saved;
            brace_ends_condition = saved_brace;
            expect_p("]");
            {
                /* v[i], v[r, c] of a type with a subscript (#136): its getter,
                   chosen by the indices' types; it wins over #117's indexing */
                Decl *sr;
                Type *vt0 = value_type(e);
                char *gname = vt0 && type_class(unqualified(vt0), &sr) == 's' && sr && sr->name
                                  ? strfmt("%s.[]", sr->name)
                                  : NULL;
                if (gname && function_named(gname)) {
                    if (slice)
                        error_at(t->pos, "a slice is no subscript of %s: index it with v[i]", sr->name);
                    if (is_owner(vt0) && !owner_place(e)) /* held (#187) */
                        e = make_temp(e, "a subscript of an owner that an expression gives: bind it to a variable first");
                    List args = {0};
                    flatten_commas(x->b, &args);
                    Decl *chosen = choose_subscript(gname, &args, t->pos, sr->name);
                    for (int k = 0; k < args.len; k++) {
                        Type *pt = ((Var *)chosen->params.data[k + 1])->type;
                        Expr *a = args.data[k];
                        pick_overload(a, pt);
                        a = optional_of(string_of_literal(a, pt), pt, a->pos);
                        move_argument(a, pt, strfmt("the subscript of %s", sr->name));
                        args.data[k] = a;
                    }
                    Expr *c = new_expr(E_CALL, t->pos);
                    c->a = e;
                    c->op = "subscript_get";
                    c->target = chosen;
                    c->items = args;
                    c->type = chosen->ret;
                    e = c;
                    continue;
                }
            }
            Decl *jr = tagged_record(value_type(e));
            if (jr) {
                /* v[k] of an enum with values (#117): through its case that is a
                   Dictionary for text, or an Array for an integer, as j["key"]
                   and j[i] of a JSON; checked as the case and the index are */
                Var *dc = NULL, *ac = NULL;
                for (int i = 0; i < jr->members.len; i++) {
                    Var *c = jr->members.data[i];
                    if (c->type && is_dict_owner(c->type) && !dc)
                        dc = c;
                    if (c->type && is_array_owner(c->type) && !ac)
                        ac = c;
                }
                Expr *k = x->b ? x->b : x->c;
                bool text = k && !slice && (is_text_expr(k) || is_string(value_type(k)) || is_bytes(value_type(k)));
                Var *c = text ? dc : ac;
                if (!c)
                    error_at(t->pos, "%s is not indexed with %s: %s", record_spelling(jr), text ? "text" : "an integer",
                             dc && !text  ? "its Dictionary case takes text"
                             : ac && text ? "its Array case takes an integer"
                                          : "no case of it is a Dictionary or an Array");
                Expr *f = new_expr(E_FIELD, t->pos);
                f->a = e;
                f->text = c->name;
                f->op = "case";
                f->type = c->type;
                f->target = jr;
                e = f;
                x->a = f;
            }
            if (slice) {
                /* xs[lo..<hi] (#68): a copy of the elements, or of a String's
                   codepoints, or of a Bytes's bytes, of a place */
                Type *st = value_type(e);
                if (!is_array_owner(st) && !is_string(st) && !is_bytes(st))
                    error_at(t->pos, "a slice [lo..<hi] is of an Array, a String or a Bytes, and this is %s",
                             st ? kelvin_type(st) : "not one");
                if (!owner_place(e)) { /* held (#187) */
                    e = make_temp(e, "a slice of an owner that an expression gives: bind it to a variable first");
                    x->a = e;
                }
                for (int k = 0; k < 2; k++) {
                    Expr *bound = k ? x->c : x->b;
                    Decl *r;
                    char c = bound ? expr_class(bound, &r) : 'i';
                    if (c != 'i' && c != 'u')
                        error_at(bound->pos, "a slice's bounds are integers, and this is %s",
                                 value_type(bound)    ? kelvin_type(value_type(bound))
                                 : literal_type(bound) ? literal_type(bound)
                                                       : "not one");
                }
                x->op = "slice";
                x->text = closed ? "closed" : "open";
                x->type = unqualified(st);
                e = x;
                continue;
            }
            if ((is_bytes(value_type(e)) || is_array_owner(value_type(e)) || is_dict_owner(value_type(e))) &&
                !owner_place(e)) { /* held (#187) */
                e = make_temp(e, "'[]' of an owner that an expression gives: bind it to a variable first");
                x->a = e;
            }
            if (is_set_owner(value_type(e)))
                error_at(t->pos, "a Set is not indexed: test an element with '.has(x)', or walk it with 'for x in s'");
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
            if (x->a->kind == E_IDENT && (!strcmp(x->a->text, "ok") || !strcmp(x->a->text, "err")) &&
                !function_named(x->a->text) && binding_index(x->a->text) < 0 && x->items.len == 1) {
                x->op = "word"; /* ok(v), err(e): a Result's case where one is expected (#75) */
                e = x;
                continue;
            }
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
            char *member = is_kw(name, "cstr") || is_converter(name) || is_kw(name, "case") || is_kw(name, "union")
                               ? advance()->text /* .case of an enum with values (#61), .union of a Set (#71) */
                               : expect_ident("a member or method name");
            /* a `(` on the next line starts the next statement (#35) */
            bool call = is_p(peek(), "(") && !line_ends_expression();
            if (!strcmp(member, "pretty")) {
                /* v.pretty (#124): the value's text indented, a line for each
                   item of a [] or {}, as a String; where print shows it, it
                   is printed where it stands. A field of that name wins */
                Decl *record;
                Type *vt = value_type(e);
                bool field = type_class(vt, &record) == 's' && record_has_field(record, member);
                if (!field) {
                    if (!showable(vt))
                        error_at(name->pos, "'.pretty' is the text, indented, of a struct, an enum with values, an "
                                            "Optional, a Result, an Array, a Dictionary or a Set; this is %s, whose text "
                                            "is '.cstr'",
                                 vt ? kelvin_type(vt) : "a value kelvinc cannot see");
                    if (is_owner(vt) && !owner_place(e)) /* held (#187) */
                        e = make_temp(e, "'.pretty' of an owner that an expression gives: bind it to a variable first");
                    Expr *x = new_expr(E_PROPERTY, name->pos);
                    x->a = e;
                    x->text = "pretty";
                    x->op = "pretty";
                    x->recv_type = unqualified(vt);
                    x->type = base_type("String", name->pos);
                    if (call) {
                        /* x.pretty(n) (#127): n spaces a level, 0 to 10, as JS
                           clamps JSON.stringify's space; a literal is checked */
                        advance();
                        if (is_p(peek(), ")"))
                            error_at(peek()->pos, "'.pretty(n)' takes the spaces a level, an integer from 0 to 10; "
                                                  "two is '.pretty'");
                        Expr *w = parse_assign();
                        expect_p(")");
                        Decl *wr;
                        char wc = expr_class(w, &wr);
                        if ((wc != 'i' && wc != 'u') || is_text_expr(w))
                            error_at(w->pos, "'.pretty(n)' takes the spaces a level, an integer from 0 to 10, and this "
                                             "is %s",
                                     is_text_expr(w) ? "text" : value_type(w) ? kelvin_type(value_type(w)) : "not one");
                        if (w->kind == E_LITERAL && (strtoll(w->text, NULL, 0) < 0 || strtoll(w->text, NULL, 0) > 10))
                            error_at(w->pos, "'.pretty(n)' indents 0 to 10 spaces a level, as JSON.stringify's space "
                                             "does, and this is %s",
                                     w->text);
                        x->b = w;
                    }
                    e = x;
                    continue;
                }
            }
            if (call && is_converter(name) && !converter_is_field(e, member))
                error_at(name->pos, "'.%s' takes no arguments: read text in a base with %s(text, base)", member,
                         member);
            if (call && !is_method_name(member)) { /* a function of the type is called by the type's name (#111) */
                Decl *record;
                if (expr_class(e, &record) == 's' && record && record->name &&
                    function_named(strfmt("%s.%s", record->name, member)))
                    error_at(name->pos, "'%s' is a function of %s, not a method: call it as %s.%s(...)", member,
                             record->name, record->name, member);
            }
            if (call && (!strcmp(member, "toString") || !strcmp(member, "fmt")) && !is_method_name(member)) {
                /* a field of that name that kelvinc can see, or one of a
                   struct it cannot see, is called as in C */
                Decl *record;
                char c = expr_class(e, &record);
                if (c != 'c' && c != 'u' && !(c == 's' && record_has_field(record, member)))
                    error_at(name->pos, "%s() " SHELVED_HINT, member);
            }
            Decl *tr = tagged_record(value_type(e)); /* an enum with values (#61) */
            Decl *vr = variant_record(value_type(e));
            if (vr && (call || (is_p(peek(), "{") && !brace_ends_condition && !line_starts_statement())) &&
                (!strcmp(member, "map") || !strcmp(member, "mapErr") || !strcmp(member, "flatMap")) &&
                !method_named(e, member)) {
                /* x.map(f), x.map { ... } (#80): a U? or a Result<U, E> of f's
                   result, of the value when that is the case; r.mapErr(g) a
                   Result<T, F> of g's, of the err; x.flatMap(f) (#81) f's own
                   U? or Result<U, E>, of the value */
                bool to_err = !strcmp(member, "mapErr"), flat = !strcmp(member, "flatMap");
                Type *vt = unqualified(value_type(e));
                int vc = value_case(vr);
                if (to_err && optional_record(vt))
                    error_at(name->pos, "'.mapErr' is a Result's: an Optional's none carries nothing to map");
                Var *from = vr->members.data[to_err ? 1 - vc : vc];
                Type *ctx = xcalloc(1, sizeof *ctx);
                ctx->kind = T_FUNC;
                ctx->pos = name->pos;
                list_push(&ctx->params, from->type);
                Expr *x = new_expr(E_METHOD, name->pos);
                x->a = e;
                x->text = member;
                Expr *f;
                if (call) {
                    advance();
                    bool saved = ident_annotation_ok, saved_brace = brace_ends_condition;
                    ident_annotation_ok = true;
                    brace_ends_condition = false;
                    if (is_p(peek(), ")"))
                        error_at(peek()->pos, "'.%s' takes a function of the %s: write '.%s(f)' or '.%s { ... }'", member,
                                 from->name, member, member);
                    infer_anon_result = true;
                    f = is_p(peek(), "{") ? anon_arg(ctx, 1, 0, x, false) : parse_assign();
                    infer_anon_result = false;
                    if (is_p(peek(), ","))
                        error_at(peek()->pos, "'.%s' takes one function", member);
                    ident_annotation_ok = saved;
                    brace_ends_condition = saved_brace;
                    expect_p(")");
                    if (is_p(peek(), "{") && !brace_ends_condition && !line_starts_statement())
                        error_at(peek()->pos, "'.%s' takes one function, and this would be a second", member);
                } else {
                    infer_anon_result = true;
                    f = anon_arg(ctx, 1, 0, x, true);
                    infer_anon_result = false;
                    if (at_statement_level())
                        trailing_end = cur;
                }
                Type *ft = value_type(f);
                if (!ft || ft->kind != T_FUNC || ft->params.len != 1 || !ft->elem)
                    error_at(f->pos, "'.%s' takes a function of one parameter, the %s, with a result, and this is %s", member,
                             from->name, ft ? kelvin_type(ft) : "not one");
                if (strcmp(kelvin_type(unqualified(ft->params.data[0])), kelvin_type(from->type)))
                    error_at(f->pos, "'.%s' calls its function with the %s, %s, and this takes %s", member, from->name,
                             kelvin_type(from->type), kelvin_type(ft->params.data[0]));
                if (is_owner(vt) && owner_place(e))
                    error_at(name->pos, "'.%s' would move the %s out of %s, which keeps it: map the call itself, or '%s.copy()'",
                             member, from->name, e->kind == E_IDENT ? strfmt("'%s'", e->text) : "it",
                             e->kind == E_IDENT ? e->text : "...");
                Type *u = unqualified(ft->elem);
                Var *other = vr->members.data[to_err ? vc : 1 - vc];
                if (flat) {
                    /* f gives the new value itself: an Optional's, or a Result's with the same err */
                    Decl *fr = variant_record(u);
                    bool opt = optional_record(vt) != NULL;
                    if (!fr || (optional_record(u) != NULL) != opt ||
                        (!opt && strcmp(kelvin_type(((Var *)fr->members.data[1])->type), kelvin_type(other->type))))
                        error_at(f->pos, "'.flatMap' takes a function that gives %s, and this gives %s",
                                 opt ? "an Optional, a U?" : strfmt("a Result<U, %s>", kelvin_type(other->type)),
                                 kelvin_type(u));
                    x->type = u;
                } else {
                    x->type = optional_record(vt) ? variant_type(name, "opt", u, NULL)
                              : to_err            ? variant_type(name, "res", other->type, u)
                                                  : variant_type(name, "res", u, other->type);
                }
                x->op = flat ? "flat_map" : to_err ? "map_err" : "map";
                list_push(&x->items, f);
                x->from = vt;
                x->target = vr;
                e = x;
                continue;
            }
            if ((!strcmp(member, "map") || !strcmp(member, "filter") || !strcmp(member, "reduce")) && value_type(e) &&
                is_array_owner(unqualified(value_type(e))) &&
                (call || (is_p(peek(), "{") && !brace_ends_condition && !line_starts_statement()))) {
                /* xs.map(f), xs.map { ... } (#182): an Array<U> of f of each
                   element, U f's result, whatever it is; xs.filter { ... } (#184)
                   an Array<T> of the elements f says true for; xs.reduce(init)
                   { ... } (#184) the value of f of the value so far and each
                   element, from init, of init's type. An element that is an
                   owner is given to f as a copy, which f owns; an Array an
                   expression gives is held and freed after (#183) */
                bool is_map = !strcmp(member, "map"), is_filter = !strcmp(member, "filter");
                Type *at = unqualified(value_type(e));
                bool temporary = !owner_place(e);
                Expr *x = new_expr(E_METHOD, name->pos);
                x->a = e;
                x->text = member;
                Expr *f = NULL, *init = NULL;
                Type *acc = NULL;
                bool saved = ident_annotation_ok, saved_brace = brace_ends_condition;
                if (!is_map && !is_filter) {
                    if (!call)
                        error_at(name->pos, "'.reduce' takes the value to start from: write '.reduce(init) { ... }' or "
                                            "'.reduce(init, f)'");
                    advance();
                    ident_annotation_ok = true;
                    brace_ends_condition = false;
                    if (is_p(peek(), ")") || is_p(peek(), "{"))
                        error_at(peek()->pos, "'.reduce' takes the value to start from first: '.reduce(0) { $0 + $1 }'");
                    init = parse_assign();
                    acc = value_type(init) ? unqualified(value_type(init)) : arg_type(init);
                    if (!acc)
                        error_at(init->pos, "'.reduce' starts from a value of a type kelvinc sees: write it, as in "
                                            "'0 as int64' or 'x:T'");
                }
                Type *ctx = xcalloc(1, sizeof *ctx);
                ctx->kind = T_FUNC;
                ctx->pos = name->pos;
                if (acc)
                    list_push(&ctx->params, acc);
                list_push(&ctx->params, at->elem);
                ctx->elem = is_filter ? base_type("bool", name->pos) : acc; /* map's is inferred */
                int arity = acc ? 2 : 1;
                if (acc) { /* after init: ', f)' or ')' and a trailing function */
                    if (accept_p(",")) {
                        f = is_p(peek(), "{") ? anon_arg(ctx, arity, 1, x, false) : parse_assign();
                        expect_p(")");
                    } else {
                        expect_p(")");
                        if (!is_p(peek(), "{") || brace_ends_condition || line_starts_statement())
                            error_at(peek()->pos, "'.reduce(init)' takes a function after it: '.reduce(0) { $0 + $1 }'");
                        f = anon_arg(ctx, arity, 1, x, true);
                        if (at_statement_level())
                            trailing_end = cur;
                    }
                    ident_annotation_ok = saved;
                    brace_ends_condition = saved_brace;
                } else if (call) {
                    advance();
                    ident_annotation_ok = true;
                    brace_ends_condition = false;
                    if (is_p(peek(), ")"))
                        error_at(peek()->pos, "'.%s' takes a function of an element: write '.%s(f)' or '.%s { ... }'",
                                 member, member, member);
                    infer_anon_result = is_map;
                    f = is_p(peek(), "{") ? anon_arg(ctx, 1, 0, x, false) : parse_assign();
                    infer_anon_result = false;
                    if (is_p(peek(), ","))
                        error_at(peek()->pos, "'.%s' takes one function", member);
                    ident_annotation_ok = saved;
                    brace_ends_condition = saved_brace;
                    expect_p(")");
                    if (is_p(peek(), "{") && !brace_ends_condition && !line_starts_statement())
                        error_at(peek()->pos, "'.%s' takes one function, and this would be a second", member);
                } else {
                    infer_anon_result = is_map;
                    f = anon_arg(ctx, 1, 0, x, true);
                    infer_anon_result = false;
                    if (at_statement_level())
                        trailing_end = cur;
                }
                Type *ft = value_type(f);
                if (!ft || ft->kind != T_FUNC || ft->params.len != arity || !ft->elem)
                    error_at(f->pos, "'.%s' takes a function of %s, with a result, and this is %s", member,
                             acc ? "two parameters, the value so far and an element" : "one parameter, an element",
                             ft ? kelvin_type(ft) : "not one");
                if (strcmp(kelvin_type(unqualified(ft->params.data[arity - 1])), kelvin_type(at->elem)))
                    error_at(f->pos, "'.%s' calls its function with each element, %s, and this takes %s", member,
                             kelvin_type(at->elem), kelvin_type(ft->params.data[arity - 1]));
                if (is_filter && strcmp(kelvin_type(unqualified(ft->elem)), "bool"))
                    error_at(f->pos, "'.filter' takes a function that says whether to keep an element, a bool, and this "
                                     "gives %s",
                             kelvin_type(ft->elem));
                if (acc && (strcmp(kelvin_type(unqualified(ft->params.data[0])), kelvin_type(acc)) ||
                            strcmp(kelvin_type(unqualified(ft->elem)), kelvin_type(acc))))
                    error_at(f->pos, "'.reduce' calls its function with the value so far, %s, and keeps what it gives, "
                                     "and this is %s",
                             kelvin_type(acc), kelvin_type(ft));
                if (init)
                    move_argument(init, acc, "'.reduce'"); /* an owner to start from moves in (O5) */
                x->type = is_map ? array_type(name, unqualified(ft->elem)) : is_filter ? at : acc;
                x->op = strfmt("array_%s%s", member, temporary ? "_tmp" : "");
                x->from = at;
                list_push(&x->items, f);
                if (init)
                    list_push(&x->items, init);
                e = x;
                continue;
            }
            if ((!strcmp(member, "reverse") || !strcmp(member, "reversed")) && call && value_type(e) &&
                is_array_owner(unqualified(value_type(e)))) {
                /* xs.reverse() in place, xs.reversed() a new Array (#186): the
                   elements in the other order, moved as they are */
                bool in_place = !strcmp(member, "reverse");
                Type *at = unqualified(value_type(e));
                bool temporary = !owner_place(e);
                if (in_place && temporary)
                    error_at(name->pos, "'.reverse' reverses an Array in place, and this one an expression gives would "
                                        "be lost: bind it, or write '.reversed()'");
                if (in_place && let_target(e))
                    error_at(name->pos, "'%s' is a let and cannot change; declare it with var, or write '.reversed()'",
                             let_target(e));
                advance();
                if (!is_p(peek(), ")"))
                    error_at(peek()->pos, "'.%s' takes nothing: '.%s()'", member, member);
                expect_p(")");
                Expr *x = new_expr(E_METHOD, name->pos);
                x->a = e;
                x->from = at;
                x->text = member;
                x->op = in_place ? "array_reverse" : temporary ? "array_reversed_tmp" : "array_reversed";
                x->type = in_place ? NULL : at;
                e = x;
                continue;
            }
            if ((!strcmp(member, "sort") || !strcmp(member, "sorted")) && value_type(e) &&
                is_array_owner(unqualified(value_type(e))) &&
                (call || (is_p(peek(), "{") && !brace_ends_condition && !line_starts_statement()))) {
                /* xs.sort(), xs.sort { ... }, xs.sorted(), xs.sorted { ... } (#185):
                   in place, or a new Array, by f, which says whether its first
                   goes before its second, or by < of the elements: a number's,
                   a uchr's codepoint, the bytes of a String, a Bytes or a cstr,
                   or a struct's own operator <; a stable merge sort */
                bool in_place = !strcmp(member, "sort");
                Type *at = unqualified(value_type(e));
                Type *elem = unqualified(at->elem);
                bool temporary = !owner_place(e);
                if (in_place && temporary)
                    error_at(name->pos, "'.sort' sorts an Array in place, and this one an expression gives would be lost: "
                                        "bind it, or write '.sorted()'");
                if (in_place && let_target(e))
                    error_at(name->pos, "'%s' is a let and cannot change; declare it with var, or write '.sorted()'",
                             let_target(e));
                Expr *x = new_expr(E_METHOD, name->pos);
                x->a = e;
                x->from = at;
                Type *ctx = xcalloc(1, sizeof *ctx);
                ctx->kind = T_FUNC;
                ctx->pos = name->pos;
                list_push(&ctx->params, elem);
                list_push(&ctx->params, elem);
                ctx->elem = base_type("bool", name->pos);
                Expr *f = NULL;
                bool saved = ident_annotation_ok, saved_brace = brace_ends_condition;
                if (call) {
                    advance();
                    ident_annotation_ok = true;
                    brace_ends_condition = false;
                    if (!is_p(peek(), ")"))
                        f = is_p(peek(), "{") ? anon_arg(ctx, 2, 0, x, false) : parse_assign();
                    if (is_p(peek(), ","))
                        error_at(peek()->pos, "'.%s' takes one function, the comparator, or none", member);
                    ident_annotation_ok = saved;
                    brace_ends_condition = saved_brace;
                    expect_p(")");
                }
                if (!f && is_p(peek(), "{") && !brace_ends_condition && !line_starts_statement()) {
                    f = anon_arg(ctx, 2, 0, x, true);
                    if (at_statement_level())
                        trailing_end = cur;
                }
                if (f) {
                    Type *ft = value_type(f);
                    if (!ft || ft->kind != T_FUNC || ft->params.len != 2 || !ft->elem ||
                        strcmp(kelvin_type(unqualified(ft->elem)), "bool") ||
                        strcmp(kelvin_type(unqualified(ft->params.data[0])), kelvin_type(elem)) ||
                        strcmp(kelvin_type(unqualified(ft->params.data[1])), kelvin_type(elem)))
                        error_at(f->pos, "'.%s' takes a comparator of two elements, (%s, %s):bool, true where the first "
                                         "goes before the second, and this is %s",
                                 member, kelvin_type(elem), kelvin_type(elem), ft ? kelvin_type(ft) : "not one");
                    x->text = "fn";
                    list_push(&x->items, f);
                } else if (is_string(elem) || is_bytes(elem)) {
                    x->text = is_string(elem) ? "string" : "bytes";
                } else if (is_uchr(elem)) {
                    x->text = "uchr";
                } else if (is_cstr(elem)) {
                    x->text = "cstr";
                } else if (elem->kind == T_BASE && number_kind(elem)) {
                    x->text = "num";
                } else {
                    List cands = overloads_of(NULL, "<");
                    Decl *lt = NULL;
                    char *want = kelvin_type(elem);
                    for (int i = 0; i < cands.len && !lt; i++) {
                        Decl *d = cands.data[i];
                        if (d->params.len == 2 && !strcmp(kelvin_type(unqualified(((Var *)d->params.data[0])->type)), want) &&
                            !strcmp(kelvin_type(unqualified(((Var *)d->params.data[1])->type)), want))
                            lt = d;
                    }
                    if (!lt) {
                        bare_tags = true;
                        char *shown = kelvin_type(elem);
                        bare_tags = false;
                        error_at(name->pos, "'.%s' compares the elements with <, and %s has none: give a comparator, "
                                            "'.%s { $0.x < $1.x }', or define one, as in 'let <(a:%s, b:%s):bool { ... }'",
                                 member, want, member, shown, shown);
                    }
                    x->text = "op";
                    x->target = lt;
                }
                x->op = in_place ? "array_sort" : temporary ? "array_sorted_tmp" : "array_sorted";
                x->type = in_place ? NULL : at;
                e = x;
                continue;
            }
            if (tr && call && !strcmp(member, "is")) {
                /* v.is(name): is that the current case? Of a place, when
                   the record owns: a value an expression gives would be
                   lost with what it holds (#99) */
                if (is_owner(value_type(e)) && !owner_place(e)) /* held (#187) */
                    e = make_temp(e, "'.is' of an owner that an expression gives: bind it to a variable first");
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
            /* a method of the program on a String or a Bytes, extend String { } (#156), before the built-in
               ones, but for a call with no argument where every one of the program's takes some (#164) */
            const char *okind = call && (!method_named(e, member) || (is_p(peek2(), ")") && !method_takes_none(e, member)))
                                    ? builtin_owner(value_type(e))
                                    : NULL;
            if (okind) {
                char ok = owner_letter(okind);
                /* a Bytes method (#54): append, insert, remove, clear,
                   reserve, compact, copy, string; a String's (#55): append,
                   clear, reserve, compact, copy; on a place; those that
                   change it, not on a let or through a read-only borrow */
                static const struct { const char *name; int arity; bool changes; const char *of; } methods[] = {
                    {"append", 1, true, "bsa"}, {"insert", 2, true, "ba"}, {"remove", 2, true, "ba"},
                    {"clear", 0, true, "bsa"}, {"reserve", 1, true, "bsa"}, {"compact", 0, true, "bsa"},
                    {"copy", 0, false, "bsadt"}, {"string", 0, false, "b"}, {"pop", 0, true, "a"},
                    {"escape", 0, false, "bs"}, {"unescape", 0, false, "s"},
                    {"starts", 1, false, "s"}, {"ends", 1, false, "s"}, {"trim", 0, false, "s"}, /* (#177) */
                    {"toBase64", -1, false, "b"},
                    {"has", 1, false, "dts"}, {"find", 1, false, "ds"}, {"get", 2, false, "d"},
                    {"remove", 1, true, "dt"}, {"clear", 0, true, "dt"}, {"reserve", 1, true, "dt"},
                    {"insert", 1, true, "t"}, {"union", 1, false, "t"}, {"intersection", 1, false, "t"},
                    {"difference", 1, false, "t"}, {"write", 1, false, "i"}, {"flush", 0, false, "i"},
                    {"close", 0, true, "i"}, {"read", 1, false, "i"},
                    {"print", -1, false, "i"}, {"println", -1, false, "i"}, {"seek", 1, false, "i"},
                    {"rewind", 0, false, "i"}, {"kill", 1, false, "i"},   {"glob", 1, false, "i"},
                    {"chmod", 1, false, "i"},  {"chown", 2, false, "i"},  {"truncate", 1, false, "i"},
                    {"remove", 0, false, "i"}, {"rename", 1, true, "i"},  {"utime", 2, false, "i"},
                    {"touch", 0, false, "i"},  {"join", 1, false, "i"}};
                int which = -1;
                for (size_t k = 0; k < sizeof methods / sizeof methods[0]; k++)
                    if (!strcmp(member, methods[k].name) && strchr(methods[k].of, ok))
                        which = (int)k;
                if (which < 0)
                    error_at(name->pos, ok == 'b'
                                            ? "a Bytes has no method '%s': append, insert, remove, clear, reserve, escape, "
                                              "compact, copy, string and toBase64, and the properties count, capacity, "
                                              "at, cstr and isUTF8"
                                        : ok == 's'
                                            ? "a String has no method '%s': append, clear, reserve, compact, copy, escape, unescape, "
                                              "find, has, starts, ends and trim, and the properties count, bytes and cstr"
                                        : ok == 'd'
                                            ? "a Dictionary has no method '%s': has, find, get, remove, clear, reserve "
                                              "and copy, and the property count"
                                        : ok == 't'
                                            ? "a Set has no method '%s': insert, has, remove, clear, reserve, copy, "
                                              "union, intersection and difference, and the properties count and elements"
                                        : ok == 'i'
                                            ? "an IO has no method '%s': see documents/io.md for write, print, println, "
                                              "flush, close, read(n), seek(n), rewind, kill, glob, chmod, chown, truncate, "
                                              "remove, rename, utime, touch and join, and its properties; it is not copied"
                                            : "an Array has no method '%s': append, insert, remove, pop, clear, "
                                              "reserve, compact and copy, and the properties count, capacity and at",
                             member);
                if (!owner_place(e) && !is_io_std(e)) {
                    if (methods[which].changes) /* a change to what is freed at once would be lost */
                        error_at(name->pos, "'.%s' changes a%s %s, and this one an expression gives would be lost: bind it "
                                            "to a variable first",
                                 member, ok == 'i' || ok == 'a' ? "n" : "",
                                 ok == 'b' ? "Bytes" : ok == 's' ? "String" : ok == 'd' ? "Dictionary" : ok == 't' ? "Set" : ok == 'i' ? "IO" : "Array");
                    e = make_temp(e, "a method of an owner that an expression gives: bind it to a variable first"); /* held (#187) */
                }
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
                if (methods[which].arity >= 0 && x->items.len != methods[which].arity)
                    error_at(name->pos, "'.%s' takes %d argument%s", member, methods[which].arity,
                             methods[which].arity == 1 ? "" : "s");
                if (ok == 'i' && (!strcmp(member, "seek") || !strcmp(member, "kill"))) /* a bool: whether it could (#84, #91) */
                    x->is_bool = true;
                if (ok == 's' && x->items.len == 1 &&
                    (!strcmp(member, "find") || !strcmp(member, "has") || !strcmp(member, "starts") || !strcmp(member, "ends"))) {
                    /* s.find(text), s.has(&t) (#177): text, a cstr, or a String borrowed */
                    Expr *a = x->items.data[0];
                    Type *at = value_type(a);
                    bool borrow = a->kind == E_PREFIX && !strcmp(a->op, "&") && is_string(value_type(a->a));
                    if (!borrow && !is_text_expr(a) && !(at && is_cstr(at)))
                        error_at(a->pos, "'.%s' takes text, a cstr, or a String borrowed, '&t', and this is %s", member,
                                 at && is_string(at) ? "a String: write '&'" : at ? kelvin_type(at) : "not text");
                    x->is_bool = strcmp(member, "find") != 0;
                }
                if (ok == 'b' && !strcmp(member, "toBase64")) {
                    /* b.toBase64(url, nopad) (#155): the words, in either order */
                    if (x->items.len > 2)
                        error_at(name->pos, "'.toBase64' takes the words url and nopad, in either order, or nothing");
                    for (int i = 0; i < x->items.len; i++) {
                        Expr *w = x->items.data[i];
                        if (w->kind != E_IDENT || (strcmp(w->text, "url") && strcmp(w->text, "nopad")) ||
                            (i == 1 && !strcmp(w->text, ((Expr *)x->items.data[0])->text)))
                            error_at(w->pos, "'.toBase64' takes the words url and nopad, in either order, or nothing: "
                                             "url for the URL-safe alphabet, nopad for no '=' at the end");
                    }
                    x->type = base_type("String", name->pos);
                }
                if (ok == 'i') { /* the OS's work on its path (#101): the arguments by kind, and what each gives */
                    static const struct { const char *name, *args, *gives; } ops[] = {
                        {"glob", "t", "listdir"}, {"chmod", "i", "bool"},   {"chown", "ii", "bool"}, {"truncate", "i", "bool"},
                        {"remove", "", "bool"},   {"rename", "t", "bool"},  {"utime", "ff", "bool"}, {"touch", "", "bool"},
                        {"join", "t", "string"},
                    };
                    for (size_t k = 0; k < sizeof ops / sizeof ops[0]; k++) {
                        if (strcmp(member, ops[k].name))
                            continue;
                        for (int i = 0; i < x->items.len; i++) {
                            Expr *a = x->items.data[i];
                            Type *at = value_type(a);
                            Decl *ar;
                            char ac = at ? type_class(at, &ar) : 0;
                            char want = ops[k].args[i];
                            if (want == 'i' || want == 'f') { /* a number, or a name only C sees */
                                bool fine = !at || (want == 'f' ? (ac == 'i' || ac == 'f' || number_expr(a))
                                                                : ac == 'i' || number_expr(a));
                                if (!fine || is_text_expr(a))
                                    error_at(a->pos, "argument %d of '.%s' is %s, and this is %s", i + 1, member,
                                             want == 'f' ? "a number" : "an integer", at ? kelvin_type(at) : "not one");
                            } else if (is_string(at) || is_bytes(at)) {
                                if (!owner_place(a)) /* held (#187) */
                                    a = make_temp(a, "an argument that an expression gives: bind it to a variable first");
                                x->items.data[i] = property(a, &(Token){.kind = TK_IDENT, .pos = a->pos, .text = "cstr"}, "cstr");
                            } else if ((at && !is_text_expr(a)) || number_expr(a)) {
                                error_at(a->pos, "an argument of '.%s' is text, a String or a Bytes, and this is %s", member,
                                         at ? kelvin_type(at) : "a number");
                            }
                        }
                        if (!strcmp(ops[k].gives, "bool")) /* the operations: true when done (#108) */
                            x->type = base_type("bool", name->pos), x->is_bool = true;
                        else if (!strcmp(ops[k].gives, "string"))
                            x->type = base_type("String", name->pos);
                        else /* glob: an Array straight, as listdir (#106) */
                            x->type = array_type(name, base_type("String", name->pos));
                    }
                }
                if (ok == 'i' && (!strcmp(member, "print") || !strcmp(member, "println"))) {
                    /* f.print(...), f.println(...) (#83): as print, to the IO */
                    for (int i = 0; i < x->items.len; i++) {
                        Expr *v = x->items.data[i];
                        Type *vt = value_type(v);
                        if (vt && vt->kind == T_FUNC)
                            error_at(v->pos, "'.%s' cannot show a function: a function has no text", member);
                    }
                    print_records_as_text(x);
                    if (x->items.len > 16)
                        error_at(((Expr *)x->items.data[16])->pos,
                                 "'.%s' takes up to 16 values, and this has %d: write two calls", member, x->items.len);
                }
                Expr *given = which == 0 ? x->items.data[0] : which == 1 ? x->items.data[1] : NULL;
                if (given)
                    check_appended(given, okind, member);
                if (given && which == 0 && ok == 'a')
                    x->text = (char *)array_append_kind(given, x->type);
                if (ok == 't' && (!strcmp(member, "union") || !strcmp(member, "intersection") ||
                                        !strcmp(member, "difference"))) {
                    /* the set algebra takes a borrow of a Set of the same elements (#71) */
                    Expr *o = x->items.data[0];
                    Type *ot = value_type(o);
                    if (!(ot && ot->kind == T_PTR && is_set_owner(ot->elem) && !strcmp(ot->elem->name, x->type->name)))
                        error_at(o->pos, "'.%s' takes a borrow of another %s, '&other'", member, kelvin_type(x->type));
                }
                if (ok == 'i' && !strcmp(member, "write")) {
                    /* f.write(x) (#82): text, a borrow of a String or a Bytes,
                       or one an expression gives, written and freed */
                    Expr *a = x->items.data[0];
                    Type *at = value_type(a);
                    Type *bt = a->kind == E_PREFIX && !strcmp(a->op, "&") ? value_type(a->a)
                               : at && at->kind == T_PTR                    ? at->elem /* a String^ held (#82) */
                                                                            : NULL;
                    if (bt && (is_bytes(bt) || is_string(bt)))
                        x->text = is_bytes(bt) ? "write_bytes" : "write_string";
                    else if ((is_bytes(at) || is_string(at)) && !owner_place(a))
                        x->text = is_bytes(at) ? "write_owned_bytes" : "write_owned_string";
                    else if (is_bytes(at) || is_string(at))
                        error_at(a->pos, "'.write' takes a borrow of a %s, '&%s'", is_bytes(at) ? "Bytes" : "String",
                                 a->kind == E_IDENT ? a->text : "...");
                    else if (!at || is_text_expr(a))
                        x->text = "write_text";
                    else
                        error_at(a->pos, "'.write' takes text, a borrow of a String or a Bytes ('&s'), or one an "
                                         "expression gives, and this is %s",
                                 kelvin_type(at));
                }
                if ((ok == 'd' || ok == 't') && (!strcmp(member, "has") || !strcmp(member, "find") ||
                                                           !strcmp(member, "get") || !strcmp(member, "remove") ||
                                                           !strcmp(member, "insert"))) {
                    x->items.data[0] = dict_key(x->items.data[0], x->type); /* the key, by its kind (#65) */
                    x->is_bool = !strcmp(member, "has") || !strcmp(member, "remove") || !strcmp(member, "insert");
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
                if (m && is_owner(value_type(e)) && !owner_place(e) && !is_io_std(e)) { /* the receiver, held (#156, #187) */
                    e = make_temp(e, "a method of an owner that an expression gives: bind it to a variable first");
                    x->a = e;
                }
                /* methods of one name on the receiver, overloaded by their
                   parameter types (#158): an anonymous argument takes the
                   type of the one that has a function there */
                List mcands = method_candidates(e, member);
                int arity = m && !m->variadic && mcands.len < 2 ? m->params.len : -1;
                while (!is_p(peek(), ")")) {
                    int k = x->items.len;
                    list_push(&x->items, is_p(peek(), "{") ? anon_arg(method_param_type(&mcands, m, k), arity, k, x, false)
                                                           : parse_assign());
                    if (!accept_p(","))
                        break;
                }
                ident_annotation_ok = saved;
                brace_ends_condition = saved_brace;
                expect_p(")");
                if (is_p(peek(), "{") && !brace_ends_condition && !line_starts_statement()) {
                    int k = x->items.len;
                    list_push(&x->items, anon_arg(method_param_type(&mcands, m, k), arity, k, x, true));
                    if (at_statement_level())
                        trailing_end = cur;
                } else if (is_p(peek(), "{") && brace_ends_condition) {
                    body_after_call = cur;
                } else if (is_p(peek(), "{")) {
                    int k = x->items.len;
                    reject_trailing_on_next_line(method_param_type(&mcands, m, k));
                    block_after_call = cur;
                }
                Decl *chosen = mcands.len == 1 ? mcands.data[0] : NULL;
                if (mcands.len > 1) { /* the overload the arguments fit (#158), as a function's (#41) */
                    List maybe;
                    const char *what = strfmt("'.%s' of %s", member, kelvin_type(value_type(e)));
                    chosen = choose(&mcands, (Expr **)x->items.data, x->items.len, &maybe, name->pos, what);
                    if (!chosen && maybe.len == 1)
                        chosen = maybe.data[0];
                    if (!chosen)
                        error_at(name->pos, "%s takes no such arguments: it has %d overloads, and these fit %s", what,
                                 mcands.len, maybe.len ? "more than one of them: convert an argument, as in 'x as f64'" : "none");
                }
                if (chosen) { /* an owner given by value moves into the method (O5), as into a function */
                    x->method = chosen;
                    borrow_temps(x, chosen); /* an owner an expression gives, lent where a borrow is taken (#187) */
                    for (int k = 0; k < x->items.len && k < chosen->params.len; k++)
                        move_argument(x->items.data[k], param_type(((Var *)chosen->params.data[k])->type),
                                      strfmt("'.%s'", member));
                }
                e = x;
                continue;
            }
            if (tr && !call && !strcmp(member, "case")) { /* v.case: the tag, a u8 (#61) */
                if (is_owner(value_type(e)) && !owner_place(e)) /* held (#187) */
                    e = make_temp(e, "'.case' of an owner that an expression gives: bind it to a variable first");
                Expr *x = new_expr(E_PROPERTY, t->pos);
                x->a = e;
                x->text = "case";
                x->op = "tagged";
                e = x;
                continue;
            }
            {
                /* v.x, a computed attribute (#131): its getter, as v.x() of a
                   method would be, with no parentheses; a field wins */
                Decl *g = method_named(e, member);
                Decl *record;
                Type *grt = value_type(e); /* an attribute of another type is not this value's (#168): p.count of a cstr */
                if (g && g->attribute && grt && (grt->kind != T_BASE || strcmp(grt->name, g->recv->name)))
                    g = NULL;
                if (g && g->attribute && !(expr_class(e, &record) == 's' && record_has_field(record, member))) {
                    if (call)
                        error_at(name->pos, "'%s' is an attribute of %s: read it as '.%s', with no parentheses", member,
                                 g->recv_name, member);
                    if (is_owner(value_type(e)) && !owner_place(e)) /* the receiver, held (#152, #187) */
                        e = make_temp(e, "an attribute of an owner that an expression gives: bind it to a variable first");
                    Expr *x = new_expr(E_METHOD, name->pos);
                    x->a = e;
                    x->text = member;
                    x->attr = true;
                    e = x;
                    continue;
                }
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
                if (is_owner(value_type(e)) && !owner_place(e)) /* as .is (#99), held (#152, #187) */
                    e = make_temp(e, "a case of an owner that an expression gives: bind it to a variable first");
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
            if (is_owner(value_type(e)) && !owner_place(e)) /* make().name: the struct held, the field copied out (#187) */
                e = make_temp(e, "a member of an owner that an expression gives: bind it to a variable first");
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
    if (e && e->kind == E_TEMP) /* (#187) what its body is */
        return e->b ? shown_type(e->b) : NULL;
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
        if (is_owner(vt) && !owner_place(v) && !(v->kind == E_PROPERTY && v->op && !strcmp(v->op, "pretty")))
            v = make_temp(v, "a value that an expression gives in a template: bind it to a variable first"); /* held (#187) */
        Decl *record;
        if (type_class(value_type(v), &record) == 's')
            v = property(v, &(Token){.kind = TK_IDENT, .pos = v->pos, .text = "cstr"}, "cstr");
        Type *ct = value_type(v);
        if ((is_string(ct) || is_bytes(ct)) && !owner_place(v) &&
            !(v->kind == E_PROPERTY && v->op && !strcmp(v->op, "pretty"))) /* ${$"x"} (#175): nothing would free it */
            error_at(v->pos, "a %s that an expression gives in a template, which nothing would free: bind it to a "
                             "variable first",
                     is_string(ct) ? "String" : "Bytes");
        if (v->kind == E_PROPERTY && v->op && !strcmp(v->op, "pretty")) {
            /* ${v.pretty} (#126): the text indented, by the printer, not a
               String the template would have to free */
            v->op = "tpl_show";
        } else if (is_array_owner(ct) || is_dict_owner(ct) || is_set_owner(ct)) {
            /* ${xs} (#125): an Array's, a Dictionary's or a Set's text, by
               kelvinc's printer of it (#123), cut as a string value is in a
               template's room, and whole in $`...` */
            if (!owner_place(v))
                error_at(v->pos, "%s that an expression gives in a template, which nothing would free: bind it to a "
                                 "variable first",
                         is_dict_owner(ct) ? "a Dictionary" : is_set_owner(ct) ? "a Set" : "an Array");
            Expr *s = new_expr(E_PROPERTY, v->pos);
            s->a = v;
            s->text = "text";
            s->op = "tpl_show";
            s->recv_type = unqualified(ct);
            s->type = base_type("String", v->pos);
            v = s;
        }
        v->shown = shown_type(v);
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
    if (t->regexp && !record_named("RegExp")) /* $/.../ (#157) is RegExp.compile(...), of the module */
        error_at(t->pos, "a $/.../ literal is a RegExp, which needs #import <RegExp>");
    self_word(t); /* Self.f(), Self.x, Self(v) (#140) */
    if (self_member_ahead(cur)) {
        /* .x is self.x where self is (#139): self, and the postfix reads .x */
        int si = binding_index("self");
        int locals = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
        if (anon_start >= 0 && si >= locals && si < anon_start)
            error_at(t->pos, "'.%s' is self.%s, and %s cannot use 'self' of the function around it: C has no "
                             "closures, so pass it as an argument",
                     peek2()->text, peek2()->text,
                     parsing_fn && parsing_fn->nested_in ? "a function defined inside a function" : "an anonymous function");
        Expr *e = new_expr(E_IDENT, t->pos);
        e->text = "self";
        implicit_self_at = cur;
        return e;
    }
    if (is_p(t, ".") && member_name_token(peek2()) && parsing_fn) /* .x with no self (#139) */
        error_at(t->pos, "'.%s' is self.%s in a method, an attribute or a subscript, and %s has no self",
                 peek2()->text, peek2()->text,
                 parsing_fn->type_fn ? "a function of a type, called as T.name(...)," : "a function");
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
            if (v->kind == E_PROPERTY && v->op && !strcmp(v->op, "tpl_show")) {
                w->a = v->a; /* ${xs} (#125): the printer appends to the String */
                w->op = "tplstr_show";
                w->text = v->text; /* "pretty" for ${v.pretty} (#126) */
                w->b = v->b;       /* the width of ${v.pretty(n)} (#127) */
                w->recv_type = v->recv_type;
            } else if (is_string(vt) || is_bytes(vt)) {
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
    if (t->kind == TK_PUNCT && !strcmp(t->text, "$") && is_p(peek2(), "{")) {
        /* ${k: v, ...} is a Dictionary of the entries, ${:} an empty one (#65, #69) */
        advance();
        return dict_of_list(t, NULL, NULL, NULL);
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
    if (t->kind == TK_PUNCT && !strcmp(t->text, "$") && is_p(peek2(), "(")) {
        /* $(...) (#181): a call of the function being written, itself, as
           JS's arguments.callee: a function at the top level, one inside a
           function, an anonymous one, or a function of a type */
        if (!parsing_fn)
            error_at(t->pos, "'$(...)' calls the function around it, and here there is none");
        if (parsing_fn->recv)
            error_at(t->pos, "'$(...)' calls the function around it, and this is %s of %s: write 'self.%s(...)'",
                     parsing_fn->attribute ? "an attribute" : "a method", parsing_fn->recv_name, parsing_fn->name);
        advance();
        Expr *e = new_expr(E_IDENT, t->pos);
        e->text = parsing_fn->name;
        e->target = parsing_fn;
        e->op = "callee";
        return e;
    }
    if (t->kind == TK_PUNCT && t->text[0] == '$')
        return parse_dollar();
    if (t->kind == TK_IDENT && anon_start >= 0) {
        /* a local of the function around an anonymous function (#32), or
           around a function defined inside it (#180); a function so
           defined is itself in scope */
        int i = binding_index(t->text);
        int locals = scope_marks.len ? (int)(intptr_t)scope_marks.data[0] : scope_names.len;
        if (i >= locals && i < anon_start && !function_named(t->text))
            error_at(t->pos, "%s cannot use '%s' of the function around it: C has no closures, so pass it as an "
                             "argument, or make it a global",
                     parsing_fn && parsing_fn->nested_in ? "a function defined inside a function" : "an anonymous function",
                     t->text);
    }
    if (t->kind == TK_IDENT && binding_index(t->text) < 0 && !function_named(t->text) && !is_p(peek2(), ".")) {
        /* red, rgb({1, 2, 3}): a case of a top-level enum with values that
           has no tag makes a value, as a word of the program (#120) */
        Decl *r;
        int k;
        Var *c = anon_word(t->text, &r, &k);
        if (c) {
            advance();
            return case_maker(t, t, r, c);
        }
    }
    if (t->kind == TK_IDENT && is_p(peek2(), ".") && peek_at(2)->kind == TK_IDENT &&
        (binding_index(t->text) < 0 || (function_named(t->text) && record_named(t->text)))) {
        /* T.n(x) and T.none make a value of an enum with values (#61); T.name
           and T.x also where a function is named as the type is, RegExp(...) (#162) */
        Decl *r = record_named(t->text);
        int k;
        Var *c = r && r->tagged ? case_named(r, peek_at(2)->text, &k) : NULL;
        if (c) {
            advance();
            advance();
            Token *cn = advance();
            return case_maker(t, cn, r, c);
        }
        if (r && r->name) { /* T.x, a type attribute (#133): the global T__x */
            char *cn = strfmt("%s__%s", t->text, peek_at(2)->text);
            for (int i = 0; i < type_attrs.len; i++)
                if (!strcmp(type_attrs.data[i], cn) && binding_index(cn) >= 0) {
                    advance();
                    advance();
                    advance();
                    Expr *e = new_expr(E_IDENT, t->pos);
                    e->text = cn;
                    return e;
                }
        }
        if (r && r->name) { /* T.name(...): a function of the type (#111), a name that overloads may share */
            char *full = strfmt("%s.%s", t->text, peek_at(2)->text);
            if (function_named(full)) {
                advance();
                advance();
                advance();
                Expr *e = new_expr(E_IDENT, t->pos);
                e->text = full;
                List cands = overloads_of(full, NULL);
                if (cands.len == 1)
                    e->target = cands.data[0];
                else
                    e->cands = cands;
                return e;
            }
        }
    }
    if (t->kind == TK_IDENT || t->kind == TK_NUMBER || t->kind == TK_CHAR || is_kw(t, "true") ||
        is_kw(t, "false")) {
        advance();
        Expr *e = new_expr(t->kind == TK_IDENT ? E_IDENT : E_LITERAL, t->pos);
        e->text = t->text;
        if (t->kind == TK_IDENT && !strcmp(t->text, "self") && parsing_fn && parsing_fn->type_fn &&
            !parsing_fn->subscript) /* a subscript has self (#136) */
            error_at(t->pos, "a function of a type has no self: '%s' is called as %s(...), with no value before it; "
                             "a method, 'let %s.name()', has one",
                     parsing_fn->name, parsing_fn->name, parsing_fn->recv_name);
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
    if ((is_kw(t, "Optional") || is_kw(t, "Result")) && is_p(peek2(), "<")) {
        /* Optional<T>(v), Optional<T>(), Optional<T>.some(v), Optional<T>.none (#72);
           Result<T, U>(v), Result<T, U>.ok(v), Result<T, U>.err(e) (#75) */
        advance();
        Type *vt = is_kw(t, "Optional") ? parse_optional_type(t) : parse_result_type(t);
        return variant_constructor(t, vt);
    }
    if (is_kw(t, "Set") && is_p(peek2(), "<")) {
        /* Set<T>(), Set<T>({a, b, c}), Set<T>(&other) (#71) */
        advance();
        Type *st = parse_set_type(t);
        if (!is_p(peek(), "("))
            error_at(peek()->pos, "%s is a type: make one with %s(), or write it after ':'", kelvin_type(st),
                     kelvin_type(st));
        advance();
        bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
        brace_ends_condition = brace_in_for = false;
        Expr *e;
        if (is_p(peek(), "{") || (is_p(peek(), "$") && is_p(peek2(), "{"))) {
            if (is_p(peek(), "$"))
                advance();
            e = set_of_list(t, st, NULL, NULL);
        } else {
            e = new_expr(E_CALL, t->pos);
            e->a = new_expr(E_IDENT, t->pos);
            e->a->text = "Set";
            e->op = "set";
            e->text = "";
            e->type = st;
            if (!is_p(peek(), ")")) {
                Expr *x = parse_assign();
                Type *xt = value_type(x);
                if (!(xt && xt->kind == T_PTR && is_set_owner(xt->elem) && !strcmp(xt->elem->name, st->name)))
                    error_at(x->pos, "%s takes nothing, the elements in {a, b, c}, or a borrow of another, '&s'",
                             kelvin_type(st));
                e->text = "copy";
                list_push(&e->items, x);
            }
        }
        brace_ends_condition = saved_brace;
        brace_in_for = saved_for;
        expect_p(")");
        return e;
    }
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
        if (is_p(peek(), "{") || (is_p(peek(), "$") && is_p(peek2(), "{"))) {
            if (is_p(peek(), "$"))
                advance();
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
                    error_at(x->pos, "%s takes nothing, the entries in {k: v, ...}, or a borrow of another, '&d'",
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
    if (is_kw(t, "IO") && is_p(peek2(), "("))
        require_module("IO", t->pos);
    if (is_kw(t, "IO") && is_p(peek2(), "(")) {
        /* IO(path, mode) (#82): the IO, straight (#109), with f.error the
           errno when it did not open; path and mode text, a String or a
           Bytes */
        advance();
        advance();
        Expr *e = new_expr(E_CALL, t->pos);
        e->a = new_expr(E_IDENT, t->pos);
        e->a->text = "IO";
        e->op = "io";
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
        if (e->items.len < 1 || e->items.len > 2)
            error_at(t->pos, "IO takes a path and a mode, as in IO(\"log.txt\", \"w\"): text, a String or a Bytes; "
                             "a path alone opens for reading (#101); or a file descriptor and a mode, IO(fd, \"r\")");
        Expr *first = e->items.data[0];
        Type *ft = value_type(first);
        Decl *fr;
        if (is_io(ft))
            error_at(first->pos, "IO takes a descriptor number here: an IO's is 'f.fd'");
        if (number_expr(first) || (ft && type_class(ft, &fr) == 'i'))
            e->text = "fd"; /* IO(fd, mode) (#86): a descriptor's, as fdopen gives it */
        if (e->text && e->items.len < 2)
            error_at(t->pos, "IO of a descriptor takes a mode too, as in IO(fd, \"r\")");
        for (int i = e->text ? 1 : 0; i < e->items.len; i++) {
            Expr *a = e->items.data[i];
            Type *at = value_type(a);
            if (is_string(at) || is_bytes(at)) {
                if (!owner_place(a))
                    error_at(a->pos, "the %s of IO is a %s that an expression gives: bind it to a variable first",
                             i ? "mode" : "path", is_string(at) ? "String" : "Bytes");
                e->items.data[i] = property(a, &(Token){.kind = TK_IDENT, .pos = a->pos, .text = "cstr"}, "cstr");
            } else if (at && !is_text_expr(a)) {
                error_at(a->pos, "the %s of IO is text, a String or a Bytes, and this is %s", i ? "mode" : "path",
                         kelvin_type(at));
            }
        }
        e->type = base_type("IO", t->pos);
        return e;
    }
    if ((is_kw(t, "OS") || is_kw(t, "SYS")) && is_p(peek2(), "."))
        require_module(is_kw(t, "OS") ? "OS" : "SYS", t->pos);
    if (is_kw(t, "OS") && is_p(peek2(), ".") && peek_at(2)->kind == TK_IDENT && !strcmp(peek_at(2)->text, "mkstemp") &&
        !module_imported("IO"))
        error_at(t->pos, "OS.mkstemp gives an IO, a module: write '#import <IO>' at the top of the file");
    if ((is_kw(t, "OS") || is_kw(t, "SYS")) && is_p(peek2(), ".")) {
        /* OS.name(args) and SYS.name (#94): the system around the program,
           and the program itself, as the prelude's namespaces */
        /* args: NULL a property; else one letter per argument, t text (a
           String or a Bytes too), i an integer, f a number */
        static const struct { const char *ns, *name, *args, *gives; } members[] = {
            {"SYS", "argv", NULL, "argv"},      {"SYS", "exit", "i", "void"},      {"SYS", "platform", NULL, "cstr"},
            {"OS", "cwd", NULL, "res_string"},  {"OS", "chdir", "t", "i32"},       {"OS", "env", "t", "opt_cstr"},
            {"OS", "setenv", "tt", "i32"},      {"OS", "unsetenv", "t", "i32"},    {"OS", "exists", "t", "bool"},
            {"OS", "isdir", "t", "bool"},       {"OS", "isfile", "t", "bool"},     {"OS", "islink", "t", "bool"},
            {"OS", "remove", "t", "i32"},       {"OS", "unlink", "t", "i32"},      {"OS", "rename", "tt", "i32"},
            {"OS", "mkdir", "t", "i32"},        {"OS", "makedirs", "t", "i32"},    {"OS", "rmdir", "t", "i32"},
            {"OS", "listdir", "t", "listdir"},  {"OS", "stat", "t", "stat"},       {"OS", "lstat", "t", "stat"},
            {"OS", "symlink", "tt", "i32"},     {"OS", "readlink", "t", "res_string"}, {"OS", "link", "tt", "i32"},
            {"OS", "chmod", "ti", "i32"},       {"OS", "truncate", "ti", "i32"},   {"OS", "realpath", "t", "res_string"},
            {"OS", "basename", "t", "string"},  {"OS", "dirname", "t", "string"},  {"OS", "join", "tt", "string"},
            {"OS", "system", "t", "i32"},       {"OS", "kill", "ii", "i32"},       {"OS", "umask", "i", "i32"},
            {"OS", "pid", NULL, "i32"},         {"OS", "ppid", NULL, "i32"},       {"OS", "uid", NULL, "i32"},
            {"OS", "gid", NULL, "i32"},         {"OS", "user", NULL, "opt_string"}, {"OS", "host", NULL, "res_string"},
            {"OS", "time", NULL, "f64"},        {"OS", "sleep", "f", "void"},      {"OS", "tmpdir", NULL, "cstr"},
            {"OS", "walk", "t", "listdir"},     {"OS", "glob", "t", "listdir"},    {"OS", "mkstemp", "t", "temp"},
            {"OS", "mkdtemp", "t", "res_string"}, {"OS", "utime", "tff", "i32"}, {"OS", "touch", "t", "i32"},
            {"OS", "chown", "tii", "i32"},      {"OS", "lchown", "tii", "i32"},    {"OS", "username", "i", "opt_string"},
            {"OS", "groupname", "i", "opt_string"},
            {"OS", "strerror", "i", "string"},   {"OS", "environ", NULL, "listdir"},  {"OS", "euid", NULL, "i32"},
            {"OS", "egid", NULL, "i32"},         {"OS", "groups", NULL, "ints"},      {"OS", "uname", NULL, "uname"},
            {"OS", "readable", "t", "bool"},     {"OS", "writable", "t", "bool"},     {"OS", "executable", "t", "bool"},
            {"OS", "isabs", "t", "bool"},        {"OS", "splitext", "t", "splitext"}, {"OS", "normpath", "t", "string"},
            {"OS", "relpath", "tt", "string"},   {"OS", "expanduser", "t", "string"}, {"OS", "samefile", "tt", "bool"},
            {"OS", "mkfifo", "t", "i32"},        {"OS", "sync", "", "void"},          {"OS", "cpus", NULL, "i32"},
            {"OS", "loadavg", NULL, "loadavg"},  {"OS", "urandom", "i", "res_bytes"}, {"OS", "isatty", "i", "bool"},
            {"OS", "sep", NULL, "cstr"},         {"OS", "linesep", NULL, "cstr"},     {"OS", "devnull", NULL, "cstr"},
            {"OS", "name", NULL, "cstr"},        {"OS", "terminalsize", NULL, "terminalsize"},
            {"OS", "diskusage", "t", "diskusage"},
        };
        bool sys = is_kw(t, "SYS");
        advance();
        advance();
        Token *n = peek();
        char *name = expect_ident(sys ? "argv, exit or platform" : "a name, as in OS.cwd");
        int which = -1;
        for (size_t k = 0; k < sizeof members / sizeof members[0]; k++)
            if (!strcmp(members[k].ns, sys ? "SYS" : "OS") && !strcmp(members[k].name, name))
                which = (int)k;
        if (which < 0)
            error_at(n->pos,
                     sys ? "SYS has argv, exit(code) and platform, not '%s'"
                         : "OS has no '%s': see documents/os.md for cwd, chdir, env, setenv, unsetenv, exists, isdir, "
                           "isfile, islink, remove, unlink, rename, mkdir, makedirs, rmdir, listdir, stat, lstat, "
                           "symlink, readlink, link, chmod, truncate, realpath, basename, dirname, join, system, kill, "
                           "umask, pid, ppid, uid, gid, user, host, time, sleep, tmpdir, walk, glob, mkstemp, mkdtemp, utime, "
                           "touch, chown, lchown, username, groupname, strerror, environ, euid, egid, groups, uname, "
                           "readable, writable, executable, isabs, splitext, normpath, relpath, expanduser, samefile, "
                           "mkfifo, sync, cpus, loadavg, urandom, isatty, sep, linesep, devnull, name, terminalsize and "
                           "diskusage",
                     name);
        Expr *e = new_expr(E_CALL, t->pos);
        e->op = sys ? "sys" : "os";
        e->text = name;
        const char *args = members[which].args;
        int arity = args ? (int)strlen(args) : -1;
        if (!args) { /* a property, also written with () */
            if (accept_p("("))
                expect_p(")");
        } else {
            if (!accept_p("("))
                error_at(peek()->pos, "%s.%s takes %d argument%s: write %s.%s(...)", sys ? "SYS" : "OS", name, arity,
                         arity == 1 ? "" : "s", sys ? "SYS" : "OS", name);
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
            if (e->items.len != arity)
                error_at(t->pos, "%s.%s takes %d argument%s", sys ? "SYS" : "OS", name, arity, arity == 1 ? "" : "s");
            for (int i = 0; i < e->items.len; i++) {
                Expr *a = e->items.data[i];
                Type *at = value_type(a);
                Decl *ar;
                char ac = at ? type_class(at, &ar) : 0;
                if (args[i] == 'i' || args[i] == 'f') { /* a number, or a name only C sees, as ENOENT is */
                    bool ok = !at || (args[i] == 'f' ? (ac == 'i' || ac == 'f' || number_expr(a)) : ac == 'i' || number_expr(a));
                    if (!ok || is_text_expr(a))
                        error_at(a->pos, "argument %d of %s.%s is %s, and this is %s", i + 1, sys ? "SYS" : "OS", name,
                                 args[i] == 'f' ? "a number" : "an integer", at ? kelvin_type(at) : "not one");
                    continue;
                }
                if (is_string(at) || is_bytes(at)) {
                    if (!owner_place(a))
                        error_at(a->pos, "an argument of %s.%s is a %s that an expression gives: bind it to a variable first",
                                 sys ? "SYS" : "OS", name, is_string(at) ? "String" : "Bytes");
                    e->items.data[i] = property(a, &(Token){.kind = TK_IDENT, .pos = a->pos, .text = "cstr"}, "cstr");
                } else if ((at && !is_text_expr(a)) || number_expr(a)) {
                    error_at(a->pos, "an argument of %s.%s is text, a String or a Bytes, and this is %s", sys ? "SYS" : "OS",
                             name, at ? kelvin_type(at) : "a number");
                }
            }
        }
        const char *gives = members[which].gives;
        e->a = new_expr(E_IDENT, t->pos); /* what it gives, for the codegen */
        e->a->text = (char *)gives;
        if (!strcmp(gives, "i32"))
            e->type = base_type("i32", t->pos);
        else if (!strcmp(gives, "f64"))
            e->type = base_type("f64", t->pos);
        else if (!strcmp(gives, "bool"))
            e->type = base_type("bool", t->pos), e->is_bool = true;
        else if (!strcmp(gives, "cstr"))
            e->type = cstr_type(t->pos);
        else if (!strcmp(gives, "string"))
            e->type = base_type("String", t->pos);
        else if (!strcmp(gives, "argv"))
            e->type = array_type(t, cstr_type(t->pos));
        else if (!strcmp(gives, "res_string"))
            e->type = variant_type(t, "res", base_type("String", t->pos), base_type("i32", t->pos));
        else if (!strcmp(gives, "opt_cstr"))
            e->type = optional_type(t, cstr_type(t->pos));
        else if (!strcmp(gives, "opt_string"))
            e->type = optional_type(t, base_type("String", t->pos));
        else if (!strcmp(gives, "listdir"))
            e->type = variant_type(t, "res", array_type(t, base_type("String", t->pos)), base_type("i32", t->pos));
        else if (struct_spec(gives)) /* stat, uname, splitext, loadavg, terminalsize, diskusage */
            e->type = variant_type(t, "res", anon_struct(t, struct_spec(gives)), base_type("i32", t->pos));
        else if (!strcmp(gives, "temp"))
            e->type = variant_type(t, "res", temp_type(t), base_type("i32", t->pos));
        else if (!strcmp(gives, "ints"))
            e->type = variant_type(t, "res", array_type(t, base_type("i32", t->pos)), base_type("i32", t->pos));
        else if (!strcmp(gives, "res_bytes"))
            e->type = variant_type(t, "res", base_type("Bytes", t->pos), base_type("i32", t->pos));
        return e; /* "void": SYS.exit, OS.sleep and OS.sync have no value */
    }
    if (is_kw(t, "IO") && is_p(peek2(), "."))
        require_module("IO", t->pos);
    if (is_kw(t, "IO") && is_p(peek2(), ".")) {
        /* IO.stdin, IO.stdout, IO.stderr (#82), also written with ();
           IO.popen(command, mode), IO.pipe() (#87) */
        advance();
        advance();
        Token *n = peek();
        char *which = expect_ident("stdin, stdout, stderr, popen, exec, pipe or strerror");
        if (!strcmp(which, "strerror")) {
            /* IO.strerror(code) (#103): the message for an err, as OS.strerror is */
            expect_p("(");
            Expr *e = new_expr(E_CALL, t->pos);
            e->op = "os";
            e->text = "strerror";
            e->a = new_expr(E_IDENT, t->pos);
            e->a->text = "string";
            Expr *code = parse_assign();
            Type *ct = value_type(code);
            Decl *cr;
            if ((ct && type_class(ct, &cr) != 'i') || is_text_expr(code))
                error_at(code->pos, "IO.strerror takes an err, an integer, as in IO.strerror(r.err)");
            list_push(&e->items, code);
            expect_p(")");
            e->type = base_type("String", t->pos);
            return e;
        }
        if (!strcmp(which, "exec")) {
            /* IO.exec(args, mode) (#90): a program, no shell; args a list of
               text, ["ls", "-l"], or an Array of cstr or of String in a
               variable */
            expect_p("(");
            Expr *e = new_expr(E_CALL, t->pos);
            e->op = "io_exec"; /* e->a is the directory, when one is given (#92) */
            bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
            brace_ends_condition = brace_in_for = false;
            if (accept_p("[")) {
                e->text = "list";
                while (!is_p(peek(), "]")) {
                    Expr *a = parse_assign();
                    Type *at = value_type(a);
                    if (is_string(at) || is_bytes(at)) {
                        if (!owner_place(a))
                            error_at(a->pos, "an argument of IO.exec is a %s that an expression gives: bind it to a "
                                             "variable first",
                                     is_string(at) ? "String" : "Bytes");
                        a = property(a, &(Token){.kind = TK_IDENT, .pos = a->pos, .text = "cstr"}, "cstr");
                    } else if ((at && !is_text_expr(a)) || number_expr(a)) {
                        error_at(a->pos, "an argument of IO.exec is text, a String or a Bytes, and this is %s",
                                 at ? kelvin_type(at) : "a number");
                    }
                    list_push(&e->items, a);
                    if (!accept_p(","))
                        break;
                }
                expect_p("]");
                if (!e->items.len)
                    error_at(t->pos, "IO.exec takes the program and its arguments, as in IO.exec([\"ls\", \"-l\"], \"r\")");
            } else {
                Expr *a = parse_assign();
                Type *at = value_type(a);
                if (!is_array_owner(at) || !(is_cstr(at->elem) || is_string(at->elem)))
                    error_at(a->pos, "IO.exec takes a list of arguments, [\"ls\", \"-l\"], or an Array of cstr or of String "
                                     "in a variable, and this is %s",
                             at                ? kelvin_type(at)
                             : is_text_expr(a) ? "one text: write the program and each argument apart, with no shell "
                                                 "to split them"
                                               : "not one");
                if (!owner_place(a))
                    error_at(a->pos, "the arguments of IO.exec are an Array that an expression gives: bind it to a variable "
                                     "first");
                e->text = is_string(at->elem) ? "strings" : "cstrs";
                e->b = a;
            }
            if (!accept_p(","))
                error_at(peek()->pos, "IO.exec takes the arguments and then a mode, \"r\" or \"w\", then a directory and an "
                                      "environment if wanted");
            Expr *m = parse_assign();
            Type *mt = value_type(m);
            if (is_string(mt) || is_bytes(mt)) {
                if (!owner_place(m))
                    error_at(m->pos, "the mode of IO.exec is a %s that an expression gives: bind it to a variable first",
                             is_string(mt) ? "String" : "Bytes");
                m = property(m, &(Token){.kind = TK_IDENT, .pos = m->pos, .text = "cstr"}, "cstr");
            } else if (mt && !is_text_expr(m)) {
                error_at(m->pos, "the mode of IO.exec is text, \"r\" or \"w\", and this is %s", kelvin_type(mt));
            }
            e->c = m;
            if (accept_p(",")) {
                /* IO.exec(args, mode, dir) and IO.exec(args, mode, dir, env) (#92):
                   the directory, text or a String, "" for the current; the
                   environment's "NAME=value" entries, a list or an Array */
                Expr *d = parse_assign();
                Type *dt = value_type(d);
                if (is_string(dt) || is_bytes(dt)) {
                    if (!owner_place(d))
                        error_at(d->pos, "the directory of IO.exec is a %s that an expression gives: bind it to a variable "
                                         "first",
                                 is_string(dt) ? "String" : "Bytes");
                    d = property(d, &(Token){.kind = TK_IDENT, .pos = d->pos, .text = "cstr"}, "cstr");
                } else if ((dt && !is_text_expr(d)) || number_expr(d)) {
                    error_at(d->pos, "the directory of IO.exec is text or a String, \"\" for the current one, and this is %s",
                             dt ? kelvin_type(dt) : "a number");
                }
                e->a = d;
                if (accept_p(",")) {
                    if (accept_p("[")) {
                        Expr *env = new_expr(E_INIT, t->pos);
                        env->bracket = true;
                        while (!is_p(peek(), "]")) {
                            Expr *a = parse_assign();
                            Type *at = value_type(a);
                            if (is_string(at) || is_bytes(at)) {
                                if (!owner_place(a))
                                    error_at(a->pos, "an entry of IO.exec's environment is a %s that an expression gives: "
                                                     "bind it to a variable first",
                                             is_string(at) ? "String" : "Bytes");
                                a = property(a, &(Token){.kind = TK_IDENT, .pos = a->pos, .text = "cstr"}, "cstr");
                            } else if ((at && !is_text_expr(a)) || number_expr(a)) {
                                error_at(a->pos, "an entry of IO.exec's environment is text, \"NAME=value\", a String or a "
                                                 "Bytes, and this is %s",
                                         at ? kelvin_type(at) : "a number");
                            }
                            list_push(&env->items, a);
                            if (!accept_p(","))
                                break;
                        }
                        expect_p("]");
                        e->d = env;
                    } else {
                        Expr *a = parse_assign();
                        Type *at = value_type(a);
                        if (!is_array_owner(at) || !(is_cstr(at->elem) || is_string(at->elem)))
                            error_at(a->pos, "the environment of IO.exec is a list of \"NAME=value\" entries, or an Array of "
                                             "cstr or of String in a variable, and this is %s",
                                     at ? kelvin_type(at) : "not one");
                        if (!owner_place(a))
                            error_at(a->pos, "the environment of IO.exec is an Array that an expression gives: bind it to a "
                                             "variable first");
                        e->d = a;
                        e->recv_type = at; /* cstr or String entries, for the codegen */
                    }
                    if (accept_p(",")) {
                        /* IO.exec(args, mode, dir, env, fresh) (#93): true for an
                           environment of the entries alone */
                        Expr *f = parse_assign();
                        if (!seen_bool(f))
                            error_at(f->pos, "the fifth argument of IO.exec is a bool: true for an environment made from "
                                             "nothing but the entries, false for them added to this program's");
                        e->fresh = f;
                    }
                }
            }
            brace_ends_condition = saved_brace;
            brace_in_for = saved_for;
            expect_p(")");
            e->type = base_type("IO", t->pos); /* straight (#110): f.error when the program could not start */
            return e;
        }
        if (!strcmp(which, "popen") || !strcmp(which, "pipe")) {
            bool process = !strcmp(which, "popen");
            expect_p("(");
            Expr *e = new_expr(E_CALL, t->pos);
            e->a = new_expr(E_IDENT, t->pos);
            e->a->text = "IO";
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
            if (process) {
                if (e->items.len != 2)
                    error_at(t->pos, "IO.popen takes a command and a mode, as in IO.popen(\"ls -l\", \"r\")");
                for (int i = 0; i < 2; i++) {
                    Expr *a = e->items.data[i];
                    Type *at = value_type(a);
                    if (is_string(at) || is_bytes(at)) {
                        if (!owner_place(a))
                            error_at(a->pos, "the %s of IO.popen is a %s that an expression gives: bind it to a "
                                             "variable first",
                                     i ? "mode" : "command", is_string(at) ? "String" : "Bytes");
                        e->items.data[i] = property(a, &(Token){.kind = TK_IDENT, .pos = a->pos, .text = "cstr"}, "cstr");
                    } else if (at && !is_text_expr(a)) {
                        error_at(a->pos, "the %s of IO.popen is text, a String or a Bytes, and this is %s",
                                 i ? "mode" : "command", kelvin_type(at));
                    }
                }
                e->op = "io";
                e->text = "popen";
                e->type = base_type("IO", t->pos); /* straight (#110): f.error when it could not start */
            } else {
                if (e->items.len)
                    error_at(t->pos, "IO.pipe takes nothing, and gives {reader: IO, writer: IO}");
                e->op = "io_pipe";
                e->type = pipe_type(t); /* straight (#110): both ends carry the error of a pipe not made */
            }
            return e;
        }
        if (strcmp(which, "stdin") && strcmp(which, "stdout") && strcmp(which, "stderr"))
            error_at(n->pos, "IO has stdin, stdout, stderr, popen(command, mode), exec(args, mode), pipe() and "
                             "strerror(err), not '%s'; a file is IO(path, mode)",
                     which);
        if (accept_p("("))
            expect_p(")");
        Expr *e = new_expr(E_CALL, t->pos);
        e->a = new_expr(E_IDENT, t->pos);
        e->a->text = "IO";
        e->op = "io_std";
        e->text = which;
        e->type = base_type("IO", t->pos);
        return e;
    }
    if ((is_kw(t, "Bytes") || is_kw(t, "String")) && is_p(peek2(), ".") && peek_at(2)->kind == TK_IDENT &&
        is_p(peek_at(3), "(")) {
        /* Bytes.name(...), String.name(...): a function of the type the
           program declares (#168), unless it is the built-in one-argument
           Bytes.fromBase64 or Bytes.unescape (#155, #167) */
        char *full = strfmt("%s.%s", t->text, peek_at(2)->text);
        bool builtin_one = is_kw(t, "Bytes") &&
                           (!strcmp(peek_at(2)->text, "fromBase64") || !strcmp(peek_at(2)->text, "unescape")) &&
                           call_args_ahead(cur + 3) == 1;
        if (function_named(full) && !builtin_one) {
            advance();
            advance();
            advance();
            Expr *e = new_expr(E_IDENT, t->pos);
            e->text = full;
            List cands = overloads_of(full, NULL);
            if (cands.len == 1)
                e->target = cands.data[0];
            else
                e->cands = cands;
            return e;
        }
    }
    if (is_kw(t, "Bytes") && is_p(peek2(), ".") && peek_at(2)->kind == TK_IDENT &&
        (!strcmp(peek_at(2)->text, "fromBase64") || !strcmp(peek_at(2)->text, "unescape")) && is_p(peek_at(3), "(")) {
        /* Bytes.fromBase64(text) (#155): of a cstr, or of a String borrowed,
           &s; either alphabet, the padding optional. Bytes.unescape(text)
           (#167): the bytes the escapes of text stand for, the same way */
        bool b64 = !strcmp(peek_at(2)->text, "fromBase64");
        const char *what = b64 ? "Bytes.fromBase64" : "Bytes.unescape";
        advance();
        advance();
        advance();
        advance();
        Expr *e = new_expr(E_CALL, t->pos);
        e->a = new_expr(E_IDENT, t->pos);
        e->a->text = (char *)what;
        e->op = b64 ? "bytes_from_base64" : "bytes_unescape";
        bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
        brace_ends_condition = brace_in_for = false;
        if (is_p(peek(), ")"))
            error_at(peek()->pos, "%s takes text, a cstr, or a String borrowed, '&s'", what);
        Expr *arg = parse_assign();
        brace_ends_condition = saved_brace;
        brace_in_for = saved_for;
        expect_p(")");
        Type *at = value_type(arg);
        bool borrow = arg->kind == E_PREFIX && !strcmp(arg->op, "&") && is_string(value_type(arg->a));
        if (borrow)
            e->text = "string";
        else if (is_text_expr(arg) || (at && is_cstr(at)))
            e->text = "text";
        else if (at && is_string(at))
            error_at(arg->pos, "%s of a String takes a borrow: write '&%s'", what, arg->kind == E_IDENT ? arg->text : "s");
        else
            error_at(arg->pos, "%s takes text, a cstr, or a String borrowed, '&s', and this is %s", what,
                     at ? kelvin_type(at) : "no text");
        list_push(&e->items, arg);
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
        if (!string && is_p(peek(), "[")) {
            /* Bytes([0, 1, 255]) (#172): the bytes written out, each a byte's value */
            Token *open = advance();
            Expr *list = new_expr(E_INIT, open->pos);
            list->bracket = true;
            while (!is_p(peek(), "]")) {
                Expr *x = parse_assign();
                Expr *lit = x->kind == E_PREFIX && !strcmp(x->op, "-") ? x->a : x;
                if (lit->kind == E_LITERAL && isdigit((unsigned char)lit->text[0]) &&
                    (lit != x || strtoull(lit->text, NULL, 0) > 255))
                    error_at(x->pos, "a byte of Bytes([...]) is 0 to 255, and this is %s%s", lit != x ? "-" : "", lit->text);
                list_push(&list->items, x);
                list_push(&list->designators, NULL);
                if (!accept_p(","))
                    break;
            }
            expect_p("]");
            list_push(&e->items, list);
            e->text = "list";
        }
        while (!e->text && !is_p(peek(), ")")) {
            list_push(&e->items, parse_assign());
            if (!accept_p(","))
                break;
        }
        brace_ends_condition = saved_brace;
        brace_in_for = saved_for;
        expect_p(")");
        if (e->items.len > (string ? 1 : 2))
            error_at(t->pos, string ? "String takes nothing, text, or a borrow of a Bytes, '&b'"
                                    : "Bytes takes nothing, a count, text, a borrow of a Bytes, bytes in brackets, or bytes "
                                      "and their count");
        if (e->items.len == 1 && owner_place(e->items.data[0]))
            error_at(t->pos, "%s(x) would copy an owner: write x.copy(), %s", t->text,
                     string ? "b.string() of a Bytes, or String(&b)" : "or Bytes(&b)");
        return e;
    }
    if (is_converter(t) && is_p(peek2(), ".") && peek_at(2)->kind == TK_IDENT) {
        /* f64.pi (#148): a type attribute of a number type, the global f64__pi */
        char *cn = strfmt("%s__%s", t->text, peek_at(2)->text);
        for (int i = 0; i < type_attrs.len; i++)
            if (!strcmp(type_attrs.data[i], cn) && binding_index(cn) >= 0) {
                advance();
                advance();
                advance();
                Expr *e = new_expr(E_IDENT, t->pos);
                e->text = cn;
                return e;
            }
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
        if (!strcmp(e->op, "&") && is_owner(value_type(e->a)) && !owner_place(e->a)) /* &$/x/ (#157), held (#187) */
            e->a = make_temp(e->a, strfmt("a borrow of a %s that an expression gives, which nothing would free: bind it "
                                          "to a variable first",
                                          kelvin_type(value_type(e->a))));
        return !strcmp(e->op, "-") ? resolve_operator(e, "-", e->a, NULL) : e; /* -z (#42) */
    }
    if (is_p(t, "*"))
        error_at(t->pos, "dereference is a postfix '^' in Kelvin: write 'p^' instead of '*p'");
    if (accept_kw("try")) {
        /* try x (#76): x's value when it is ok (some); else the function
           returns x's err (none), passed up as it is */
        Expr *x = parse_unary();
        Type *xt = value_type(x);
        Decl *r = xt ? variant_record(xt) : NULL;
        if (!r)
            error_at(x->pos, "'try' takes a Result or an Optional, and this is %s", xt ? kelvin_type(xt) : "not one");
        Var *some = r->members.data[value_case(r)];
        Var *other = r->members.data[1 - value_case(r)];
        if (!parsing_fn || !parsing_fn->ret)
            error_at(t->pos, "'try' passes the '%s' up, and this function has no result: give it %s", other->name,
                     kelvin_type(xt));
        Decl *fr = variant_record(parsing_fn->ret);
        Var *fother = fr ? fr->members.data[1 - value_case(fr)] : NULL;
        if (!fother || strcmp(fother->name, other->name))
            error_at(t->pos, "'try' passes the '%s' up, and this function returns %s, not %s: switch on it, or 'if let'",
                     other->name, kelvin_type(parsing_fn->ret),
                     !strcmp(other->name, "err") ? "a Result" : "an Optional");
        if (other->type && strcmp(kelvin_type(other->type), kelvin_type(fother->type)))
            error_at(t->pos, "'try' passes the 'err' up as it is, and it is %s where this function's is %s",
                     kelvin_type(other->type), kelvin_type(fother->type));
        if (is_owner(some->type) && owner_place(x))
            error_at(x->pos, "'try' would move the %s out of %s, which keeps it: try the call itself, 'try %s.copy()', "
                             "or 'if let'",
                     kelvin_type(some->type), x->kind == E_IDENT ? strfmt("'%s'", x->text) : "it",
                     x->kind == E_IDENT ? x->text : "...");
        Expr *e = new_expr(E_CAST, t->pos);
        e->op = "try";
        e->a = x;
        e->type = unqualified(some->type);
        e->target = r;
        e->from = unqualified(xt);
        e->recv_type = parsing_fn->ret;
        return e;
    }
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
    return parse_postfix_chain();
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
    if (!ident_annotation_ok && (is_base_word(n) || is_kw(n, "String")) && (is_p(peek_at(2), "<") || is_p(peek_at(2), "(")))
        return false; /* c ? x : Optional<i64>(y), c ? x : Bytes(s): the else arm makes a value (#116) */
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
            !(!strcmp(e->op, "+") && (is_string(value_type(e->a)) || is_string(value_type(e->b)) ||
                                      is_bytes(value_type(e->a)) || is_bytes(value_type(e->b)))) && /* s + "x" (#183, #188) */
            ((is_cstr(value_type(e->a)) && !is_cstr(value_type(e->b))) ||
             (!strcmp(e->op, "+") && is_cstr(value_type(e->b)))))
            error_at(t->pos, "a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step a "
                             "'var p:u8^ := s'");
        if ((is_uchr(value_type(e->a)) || is_uchr(value_type(e->b))) &&
            !(!strcmp(e->op, "+") && (is_string(value_type(e->a)) || is_string(value_type(e->b))))) { /* s + c (#183) */
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
        Type *ta = value_type(e->a), *tb = value_type(e->b);
        Decl *ra = ta ? tagged_record(ta) : NULL, *rb = tb ? tagged_record(tb) : NULL;
        if ((ra || rb) && overloadable_op(t) && user_operator_on(e->op, ra ? ta : tb)) {
            /* an operator of an enum with values that the program defines
               (#121): +, -, <, ..., and == or != when one is written for it */
            lhs = resolve_operator(e, e->op, e->a, e->b);
            continue;
        }
        if (ra || rb) {
            /* a Result, an Optional or an enum with values compares with ==
               and != (#79): the same case, and equal values. On the other
               side, a value, none, ok(v) or err(e) is wrapped, as where
               one is expected; an owner that an expression gives, which
               nothing would free, is not taken */
            Decl *r = ra ? ra : rb;
            Type *rt = ra ? ta : tb;
            if (strcmp(e->op, "==") && strcmp(e->op, "!="))
                error_at(t->pos, "%s has no operator '%s': compare with == and !=%s", kelvin_type(rt), e->op,
                         variant_record(rt) ? ""
                                            : strfmt(", or define one, as in 'let %s(a:T, b:T):T { ... }' (#121)", e->op));
            if (!ra)
                e->a = optional_of(e->a, rt, e->a->pos);
            if (!rb)
                e->b = optional_of(e->b, rt, e->b->pos);
            if (r->no_eq) {
                Var *c = case_named(r, r->no_eq, NULL);
                bare_tags = true;
                char *held = kelvin_type(c->type);
                bare_tags = false;
                error_at(t->pos, "'%s' of %s compares the values, and case '%s' holds %s, which has no '=='", e->op,
                         kelvin_type(rt), c->name, held);
            }
            Type *ta2 = value_type(e->a), *tb2 = value_type(e->b);
            if (!ta2 || !tb2 || ta2->kind != T_BASE || tb2->kind != T_BASE || strcmp(ta2->name, tb2->name))
                error_at(t->pos, "'%s' compares two %s, and this is %s", e->op, kelvin_type(rt),
                         ra && tb2 ? kelvin_type(tb2) : ta2 && !ra ? kelvin_type(ta2) : "not one");
            List held = {0}; /* an operand an expression gives, held (#187) */
            if (is_owner(rt) && !eq_operand_ok(e->a))
                e->a = hold_operand(e->a, &held);
            if (is_owner(rt) && !eq_operand_ok(e->b))
                e->b = hold_operand(e->b, &held);
            Expr *eq = new_expr(E_CALL, t->pos);
            eq->a = new_expr(E_IDENT, t->pos);
            eq->a->text = strfmt("_kv_%s_eq", r->name);
            eq->op = "c";
            list_push(&eq->items, e->a);
            list_push(&eq->items, e->b);
            eq->is_bool = true;
            if (!strcmp(e->op, "!=")) {
                Expr *not = new_expr(E_PREFIX, t->pos);
                not->op = "!";
                not->a = eq;
                not->is_bool = true;
                eq = not;
            }
            lhs = wrap_temps(eq, &held);
            continue;
        }
        const char *ka = builtin_owner(value_type(e->a)), *kb = builtin_owner(value_type(e->b));
        if (ka || kb) {
            /* a Bytes or a String compares with == and != by its bytes
               (#54, #55), with another of its type, both places */
            char kl = owner_letter(ka ? ka : kb);
            const char *tn = kl == 'b' ? "Bytes" : kl == 's' ? "String" : kl == 'd' ? "Dictionary" : kl == 't' ? "Set" : "Array";
            if (kl == 't' && (!strcmp(e->op, "|") || !strcmp(e->op, "&") || !strcmp(e->op, "~"))) {
                /* s | t, s & t, s ~ t (#73): a new Set, of two in variables */
                if (!ka || !kb || strcmp(value_type(e->a)->name, value_type(e->b)->name) || !owner_place(e->a) ||
                    !owner_place(e->b))
                    error_at(t->pos, "'%s' takes two Sets of the same elements, both in variables", e->op);
                Expr *m = new_expr(E_METHOD, t->pos);
                m->a = e->a;
                m->text = e->op[0] == '|' ? "union" : e->op[0] == '&' ? "intersection" : "symdiff";
                m->op = "set";
                m->type = value_type(e->a);
                Expr *pb = new_expr(E_PREFIX, t->pos);
                pb->op = "&";
                pb->a = e->b;
                list_push(&m->items, pb);
                lhs = m;
                continue;
            }
            if (kl == 'b' && !strcmp(e->op, "+")) {
                /* b + c (#188): a new Bytes of the two, b's bytes and then c's;
                   b a Bytes or text, c a Bytes, text or a byte, one a Bytes; a
                   Bytes in a variable is copied, one an expression gives taken */
                Type *la = value_type(e->a), *lb = value_type(e->b);
                if (is_string(la) || is_string(lb))
                    error_at(t->pos, "'+' joins two Bytes or two Strings: a String's bytes are 's.bytes^', and a Bytes "
                                     "of text is 'Bytes(&s)'");
                if (!is_bytes(la) && !is_text_expr(e->a) && !(la && is_cstr(la)))
                    error_at(e->a->pos, "'+' of a Bytes starts with a Bytes or text, and this is %s; a byte first is "
                                        "'Bytes([n]) + b'",
                             la ? kelvin_type(la) : number_expr(e->a) ? "a number" : "not one");
                Expr *lit = e->b->kind == E_PREFIX && !strcmp(e->b->op, "-") ? e->b->a : e->b;
                bool byte = !is_bytes(lb) && (number_expr(e->b) || (lb && lb->kind == T_BASE && number_kind(lb) &&
                                                                   strcmp(number_kind(lb), "f64")));
                if (byte && lit->kind == E_LITERAL && isdigit((unsigned char)lit->text[0]) &&
                    (lit != e->b || strtoull(lit->text, NULL, 0) > 255))
                    error_at(e->b->pos, "a byte of '+' is 0 to 255, and this is %s%s", lit != e->b ? "-" : "", lit->text);
                if (!is_bytes(lb) && !byte && !is_text_expr(e->b) && !(lb && is_cstr(lb)))
                    error_at(e->b->pos, "'+' of a Bytes joins a Bytes, text or a byte, and this is %s",
                             lb ? kelvin_type(lb) : "not one");
                Expr *c = new_expr(E_CALL, t->pos);
                c->a = new_expr(E_IDENT, t->pos);
                c->a->text = "Bytes";
                c->op = "bytes_concat";
                c->text = is_bytes(la) ? (owner_place(e->a) ? "copy" : "take") : "text";
                Expr *b = e->b;
                if (is_bytes(lb) && owner_place(b)) { /* a borrow: its bytes appended, it stays */
                    Expr *pb = new_expr(E_PREFIX, t->pos);
                    pb->op = "&";
                    pb->a = b;
                    b = pb;
                }
                list_push(&c->items, e->a);
                list_push(&c->items, b);
                lhs = c;
                continue;
            }
            if (kl == 's' && !strcmp(e->op, "+")) {
                /* s + t (#183): a new String of the two, s's text and then t's;
                   either may be a String, text, or a uchr, one a String; a
                   String in a variable is copied, one an expression gives is
                   taken, so that s + t + u frees what it made */
                Expr *sides[2] = {e->a, e->b};
                for (int k = 0; k < 2; k++) {
                    Type *st = value_type(sides[k]);
                    if (!is_string(st) && !is_uchr(st) && !is_text_expr(sides[k]) && !(st && is_cstr(st)))
                        error_at(sides[k]->pos, "'+' of a String joins text: a String, a cstr or a uchr, and this is %s; "
                                                "show a number with a template, $`${n}`, or String(n)",
                                 st ? kelvin_type(st) : number_expr(sides[k]) ? "a number" : "not text");
                }
                if (!is_string(value_type(e->a)) && is_uchr(value_type(e->a)))
                    error_at(e->a->pos, "'+' of a String starts with a String or text: write $\"\" + c, or String(c)");
                Expr *c = new_expr(E_CALL, t->pos);
                c->a = new_expr(E_IDENT, t->pos);
                c->a->text = "String";
                c->op = "string_concat";
                c->text = is_string(value_type(e->a)) ? (owner_place(e->a) ? "copy" : "take") : "text";
                Expr *b = e->b;
                if (is_string(value_type(b)) && owner_place(b)) { /* a borrow: its text appended, it stays */
                    Expr *pb = new_expr(E_PREFIX, t->pos);
                    pb->op = "&";
                    pb->a = b;
                    b = pb;
                }
                list_push(&c->items, e->a);
                list_push(&c->items, b);
                lhs = c;
                continue;
            }
            if (tn[0] == 'A' || tn[0] == 'D' || (tn[0] == 'S' && tn[1] == 'e'))
                error_at(t->pos, "%s has no operator '%s': compare its %s",
                         tn[0] == 'A' ? "an Array" : tn[0] == 'D' ? "a Dictionary" : "a Set", e->op,
                         tn[0] == 'D' ? "entries" : "elements");
            if ((kl == 's' || kl == 'b') && is_comparison(e->op) && strcmp(e->op, "==") && strcmp(e->op, "!=")) {
                /* s < t, <=, >, >= (#185): by the bytes, which for a String is
                   codepoint order, two of a type in variables */
                if (!ka || !kb || strcmp(ka, kb))
                    error_at(t->pos, "a %s compares with another %s", tn, tn);
                List held = {0}; /* an operand an expression gives, held (#187) */
                if (!owner_place(e->a))
                    e->a = hold_operand(e->a, &held);
                if (!owner_place(e->b))
                    e->b = hold_operand(e->b, &held);
                Expr *cmp = new_expr(E_CALL, t->pos);
                cmp->a = new_expr(E_IDENT, t->pos);
                cmp->a->text = kl == 'b' ? "kv_bytes_cmp" : "kv_string_cmp";
                cmp->op = "c";
                Expr *pa = new_expr(E_PREFIX, t->pos), *pb = new_expr(E_PREFIX, t->pos);
                pa->op = pb->op = "&";
                pa->a = e->a;
                pb->a = e->b;
                list_push(&cmp->items, pa);
                list_push(&cmp->items, pb);
                Expr *zero = new_expr(E_LITERAL, t->pos);
                zero->text = "0";
                Expr *rel = new_expr(E_BINARY, t->pos);
                rel->op = e->op;
                rel->a = cmp;
                rel->b = zero;
                rel->is_bool = true;
                lhs = wrap_temps(rel, &held);
                continue;
            }
            if (strcmp(e->op, "==") && strcmp(e->op, "!="))
                error_at(t->pos, "a %s has no operator '%s': compare with == and !=, append with .append or +=%s", tn,
                         e->op, kl == 's' ? ", join with +" : "");
            if (!ka || !kb || strcmp(ka, kb))
                error_at(t->pos, "a %s compares with another %s", tn, tn);
            List held = {0}; /* an operand an expression gives, held (#187) */
            if (!owner_place(e->a))
                e->a = hold_operand(e->a, &held);
            if (!owner_place(e->b))
                e->b = hold_operand(e->b, &held);
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
            lhs = wrap_temps(eq, &held);
            continue;
        }
        lhs = overloadable_op(t) ? resolve_operator(e, e->op, e->a, e->b) : e; /* (#42) */
    }
}

static Expr *parse_conditional(void) {
    Expr *c = parse_binary(1);
    Token *t = peek();
    while (is_p(peek(), "??")) { /* x ?? y (#72): x's value if some, else y */
        Token *q = advance();
        Expr *y = parse_binary(1);
        Type *ct = value_type(c);
        Decl *r = ct ? variant_record(ct) : NULL;
        if (!r)
            error_at(q->pos, "'?\?' takes an Optional or a Result on its left, and this is %s",
                     ct ? kelvin_type(ct) : "not one");
        Var *some = r->members.data[value_case(r)];
        if (is_owner(some->type))
            error_at(q->pos, "'?\?' would copy the value, and %s owns: switch on it, or test '.is(some)' and read '.some'",
                     kelvin_type(some->type));
        List held = {0}; /* the left side read twice, held once (#187) */
        if (c->kind != E_IDENT && c->kind != E_FIELD && c->kind != E_INDEX && c->kind != E_DEREF)
            c = hold_operand(c, &held);
        pick_overload(y, some->type);
        y = string_of_literal(drop_cstr(y, some->type), some->type);
        /* C's ?: of a const uint8_t * and a char * is no text (gcc refuses,
           clang makes it an address): a string literal, or text of another
           spelling, on the right of a cstr?, u8^? or i8^? is cast to the
           value's type, as a declaration would cast it */
        Type *yt = value_type(y);
        if (some->type->kind == T_PTR && is_text_type(some->type) && y->kind != E_CAST && is_text_expr(y) &&
            (!yt || yt->kind != T_PTR || strcmp(yt->elem->name, some->type->elem->name))) {
            Expr *cast = new_expr(E_CAST, y->pos);
            cast->op = "as";
            cast->a = y;
            cast->type = some->type;
            y = cast;
        }
        Expr *is = new_expr(E_METHOD, q->pos);
        is->a = c;
        is->text = some->name;
        is->op = "case_is";
        is->target = r;
        is->is_bool = true;
        Expr *val = new_expr(E_FIELD, q->pos);
        val->a = c;
        val->text = some->name;
        val->op = "case";
        val->type = some->type;
        val->target = r;
        Expr *e = new_expr(E_TERNARY, q->pos);
        e->a = is;
        e->b = val;
        e->c = y;
        e->paren = true;
        e->op = "coalesce"; /* its type is the value's, for inference */
        e->type = some->type;
        c = wrap_temps(e, &held);
    }
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
    {
        /* c ? Optional<i64>(v) : none (#116): an arm beside a T? or a Result
           is wrapped as where one is expected, as == wraps it (#79) */
        Type *tb = value_type(e->b), *tc = value_type(e->c);
        Decl *vb = tb ? variant_record(tb) : NULL, *vc = tc ? variant_record(tc) : NULL;
        if (vb && !vc)
            e->c = optional_of(e->c, tb, e->c->pos);
        else if (vc && !vb)
            e->b = optional_of(e->b, tc, e->b->pos);
    }
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
        if (e->op && !strcmp(e->op, "slice")) /* xs[lo..<hi] (#68): a copy of the same type */
            return e->type;
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
    Expr *v = parse_postfix_chain();
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
    case E_TEMP: /* (#187) what its body gives */
        return e->b ? value_type(e->b) : NULL;
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
        if (e->op && (!strcmp(e->op, "bytes") || !strcmp(e->op, "bytes_from_base64") || !strcmp(e->op, "bytes_unescape") ||
                      !strcmp(e->op, "bytes_concat"))) /* Bytes(...) (#54, #155, #167), b + c (#188) */
            return base_type("Bytes", e->pos);
        if (e->op && (!strcmp(e->op, "string") || !strcmp(e->op, "string_concat"))) /* String(...) (#55), s + t (#183) */
            return base_type("String", e->pos);
        if (e->op && !strcmp(e->op, "case_make")) /* T.n(x) (#61) */
            return e->type;
        if (e->op && (!strcmp(e->op, "io") || !strcmp(e->op, "io_std") || !strcmp(e->op, "io_pipe") ||
                      !strcmp(e->op, "io_exec") || !strcmp(e->op, "os") || !strcmp(e->op, "sys")))
            return e->type; /* IO(path, mode), IO.stdout (#82), IO.pipe() (#87), IO.exec (#90), OS, SYS (#94) */
        if (e->op && !strcmp(e->op, "dict")) /* Dictionary<K, V>(...) (#65) */
            return e->type;
        if (e->op && !strcmp(e->op, "set")) /* Set<T>(...) (#71) */
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
        if (e->op && !strcmp(e->op, "coalesce")) /* x ?? y is a T (#72) */
            return e->type;
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
            return !strcmp(e->text, "copy")                                         ? base_type("Bytes", e->pos)
                   : !strcmp(e->text, "string") || !strcmp(e->text, "toBase64") || !strcmp(e->text, "escape")
                       ? base_type("String", e->pos)
                                                                                : NULL;
        if (e->op && !strcmp(e->op, "string")) { /* a String method (#55): copy, escape, unescape and trim give a String */
            if (!strcmp(e->text, "copy") || !strcmp(e->text, "escape") || !strcmp(e->text, "unescape") || !strcmp(e->text, "trim"))
                return base_type("String", e->pos);
            if (!strcmp(e->text, "find")) /* (#177) */
                return base_type("i64", e->pos);
            if (!strcmp(e->text, "has") || !strcmp(e->text, "starts") || !strcmp(e->text, "ends"))
                return base_type("bool", e->pos);
            return NULL;
        }
        if (e->op && !strcmp(e->op, "case_is")) /* v.is(n) (#61) */
            return base_type("bool", e->pos);
        if (e->op && !strcmp(e->op, "case_set"))
            return NULL;
        if (e->op && !strcmp(e->op, "record_copy")) /* s.copy() of a struct that owns (#61) */
            return e->type;
        if (e->op && (!strcmp(e->op, "map") || !strcmp(e->op, "map_err") || !strcmp(e->op, "flat_map") ||
                      !strncmp(e->op, "array_map", 9) || !strncmp(e->op, "array_filter", 12) ||
                      !strncmp(e->op, "array_reduce", 12) || !strncmp(e->op, "array_sort", 10) ||
                      !strncmp(e->op, "array_revers", 12)))
            return e->type; /* x.map(f) (#80), x.flatMap(f) (#81), xs.map(f) (#182) */
        if (e->op && !strcmp(e->op, "io")) { /* an IO method (#82): seek and kill give a bool (#84, #91); the path's as typed (#101) */
            static const char *typed[] = {"glob", "chmod", "chown", "truncate", "remove", "rename", "utime", "touch", "join", NULL};
            for (int i = 0; typed[i]; i++)
                if (!strcmp(e->text, typed[i]))
                    return e->type;
            return !strcmp(e->text, "seek") || !strcmp(e->text, "kill") ? base_type("bool", e->pos) : NULL;
        }
        if (e->op && !strcmp(e->op, "set")) { /* a Set method (#71) */
            if (!strcmp(e->text, "has") || !strcmp(e->text, "insert") || !strcmp(e->text, "remove"))
                return base_type("bool", e->pos);
            if (!strcmp(e->text, "copy") || !strcmp(e->text, "union") || !strcmp(e->text, "intersection") ||
                !strcmp(e->text, "difference") || !strcmp(e->text, "symdiff"))
                return value_type(e->a);
            return NULL;
        }
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
        if (!rt)
            rt = arg_type(e->a); /* 1.0.i, (-1.0).i (#148): a literal's own type */
        Decl *m = e->method ? e->method : rt && rt->kind == T_BASE ? method_named(e->a, e->text) : NULL;
        if (m) /* the method of the receiver's type, or the overload chosen (#158) */
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
        if (e->op && (!strcmp(e->op, "pretty") || !strcmp(e->op, "show") || !strcmp(e->op, "tpl_show")))
            return e->type; /* v.pretty, a String (#124); ${xs}'s text (#125) */
        if (e->op && !strcmp(e->op, "bytes") && !strcmp(e->text, "at")) { /* b.at (#54) */
            Type *p = xcalloc(1, sizeof *p);
            p->kind = T_PTR;
            p->pos = e->pos;
            p->elem = base_type("u8", e->pos);
            p->elem->is_const = let_target(e->a) != NULL;
            return p;
        }
        if (e->op && !strcmp(e->op, "io")) /* f.bytes, f.string: Results (#82); f.lines: for only */
            return e->type;
        if (e->op && !strcmp(e->op, "uchr")) /* c.utf32 (#56) */
            return base_type("u32", e->pos);
        if (e->op && !strcmp(e->op, "tagged")) /* v.case, the tag (#61) */
            return base_type("u8", e->pos);
        if (e->op && (!strcmp(e->op, "dict") || !strcmp(e->op, "set")) && e->type) /* d.keys, d.values, s.elements: Arrays (#66, #71) */
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
    if (e && e->kind == E_TEMP) /* (#187) what its body is */
        return e->b && seen_bool(e->b);
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
        if ((e->op && !strcmp(e->op, "tagged")) || !strcmp(e->text, "size") || !strcmp(e->text, "addr") ||
            !strcmp(e->text, "count") || !strcmp(e->text, "capacity") || !strcmp(e->text, "utf32") ||
            !strcmp(e->text, "codepoint"))
            return 'i';
        /* a property that gives a struct kelvinc sees, f.stat (#104): its
           fields win over .size and the rest, as a variable's do */
        if (e->type && type_class(e->type, record) == 's')
            return 's';
        *record = NULL;
        return 'n';
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
    if (e && e->kind == E_TEMP) /* (#187) what its body is */
        return e->b && is_text_expr(e->b);
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
    if (e && e->kind == E_TEMP) /* (#187) what its body is */
        return e->b && number_expr(e->b);
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
    if (is_string(value_type(v)) || is_bytes(value_type(v))) {
        /* i64(line) of a String or a Bytes reads its text (#88), of one
           in a variable, as the text of one an expression gives would
           be freed under the reader */
        if (!owner_place(v)) /* held while it is read (#187) */
            v = make_temp(v, strfmt("%s(...) of a %s that an expression gives: bind it to a variable first", name,
                                    is_string(value_type(v)) ? "String" : "Bytes"));
        e->a = v = property(v, &(Token){.kind = TK_IDENT, .pos = v->pos, .text = "cstr"}, "cstr");
    }
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
   parameter's own qualifiers: "c64,f64" */
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
    if (!op && bound_in_block(name)) { /* a function defined in a block (#180): the one bound, hiding the top level's */
        Decl *d = function_named(name);
        if (d)
            list_push(&out, d);
        return out;
    }
    for (int i = 0; i < functions.len; i++) {
        Decl *d = functions.data[i];
        if (d->recv || d->nested_in || (op ? !d->op || strcmp(d->op, op) : d->op || strcmp(d->name, name)))
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
    if (e && e->kind == E_TEMP) /* (#187) what its body is */
        return e->b ? arg_type(e->b) : NULL;
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
        bool lent = p->kind == T_PTR && p->elem && is_owner(p->elem) && !owner_place(arg) &&
                    !strcmp(fn_key(a), fn_key(unqualified(p->elem))); /* f($"x") to a const String^ (#187) */
        bare_tags = false;
        if (same)
            return 2;
        if (lent)
            return 1;
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
   function of the name is meant, as sin(z.real) is in sin(z:c64)?
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
    if (callee->kind != E_IDENT)
        return;
    if (callee->op && !strcmp(callee->op, "callee")) { /* $(...) (#181): the function being written */
        Decl *d = callee->target;
        if ((call->items.len != d->params.len && !d->variadic) || call->items.len < d->params.len)
            error_at(call->pos, "'$(...)' calls %s, which takes %d argument%s, and this gives %d",
                     d->anon ? "this anonymous function" : d->name, d->params.len, d->params.len == 1 ? "" : "s",
                     call->items.len);
        call->target = d;
        drop_cstr_args(call, d);
        move_args(call, d);
        return;
    }
    if (lookup_type(callee->text)) {
        /* a call through a function value (#158), a variable or a parameter:
           an owner given by value moves into it (O5) */
        Type *ft = value_type(callee);
        if (ft && unqualified(ft)->kind == T_FUNC) {
            ft = unqualified(ft);
            call->fn_type = ft;
            for (int k = 0; k < call->items.len && k < ft->params.len; k++)
                move_argument(call->items.data[k], param_type(ft->params.data[k]), strfmt("'%s'", callee->text));
        }
        return;
    }
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
            borrow_temps(call, only);
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
            borrow_temps(call, call->target);
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

/* an owner an expression gives, given where a borrow of its type is taken,
   held and lent (#187): f($/\s+/) to a const RegExp^ */
static void borrow_temps(Expr *call, Decl *d) {
    for (int k = 0; k < call->items.len && k < d->params.len; k++) {
        Type *p = unqualified(((Var *)d->params.data[k])->type);
        Expr *a = call->items.data[k];
        Type *at = value_type(a);
        if (!p || p->kind != T_PTR || !p->elem || !is_owner(p->elem) || !at || at->kind != T_BASE || owner_place(a) ||
            strcmp(kelvin_type(unqualified(at)), kelvin_type(unqualified(p->elem))))
            continue;
        Expr *lent = new_expr(E_PREFIX, a->pos);
        lent->op = "&";
        lent->a = make_temp(a, "an owner that an expression gives, lent to a function: bind it to a variable first");
        call->items.data[k] = lent;
    }
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
            if (is_owner(value_type(x)) && !owner_place(x)) /* held while it prints (#187) */
                call->items.data[k] = make_temp(x, strfmt("%s of an owner that an expression gives, which nothing would "
                                                          "free: bind it to a variable first",
                                                          call->a->text));
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
/* Does the program define operator op with a parameter of type t (#121)? */
static bool user_operator_on(const char *op, Type *t) {
    List cands = overloads_of(NULL, op);
    char *want = kelvin_type(unqualified(t));
    for (int i = 0; i < cands.len; i++) {
        Decl *d = cands.data[i];
        for (int k = 0; k < d->params.len; k++)
            if (!strcmp(kelvin_type(unqualified(((Var *)d->params.data[k])->type)), want))
                return true;
    }
    return false;
}

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

/* A C name made from a type, as c64, u8p for u8^, a3 for [3], and
   F...E around a function type's parameters, its result after the E */
static char *mangled_type(Type *t) {
    if (is_set_owner(t)) /* Set<T> is Set_<T> (#71) */
        return strfmt("Set_%s", mangled_type(t->elem));
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
        Buf types = {0};
        buf_puts(&types, "");
        for (int k = d->subscript ? 1 : 0; k < d->params.len; k++) /* a subscript's self is in its name (#136) */
            buf_printf(&types, "__%s", mangled_type(((Var *)d->params.data[k])->type));
        if (d->variadic)
            buf_puts(&types, "__va");
        if (d->nested_in) {
            /* a function defined inside a function (#180): _kv_outer_name, and
               _kv_outer_name1, 2, ... for another of the name in the same outer
               function, a block's own or an overload */
            int k = 0;
            for (int j = 0; j < i; j++) {
                Decl *e = functions.data[j];
                if (e->nested_in == d->nested_in && !strcmp(e->name, d->name))
                    k++;
            }
            const char *outer = d->nested_in->cname ? d->nested_in->cname : d->nested_in->name;
            d->cname = k ? strfmt("_kv_%s_%s%d", outer, d->name, k) : strfmt("_kv_%s_%s", outer, d->name);
            continue;
        }
        if (d->recv) {
            /* a method is T__name, or T__name by its types where methods of
               its name on its receiver differ in their parameters (#158) */
            if (d->setter || d->attribute)
                continue;
            bool over = false;
            for (int k = 0; k < functions.len && !over; k++) {
                Decl *e = functions.data[k];
                over = e != d && e->recv && !e->setter && !e->attribute && !strcmp(e->recv_name, d->recv_name) &&
                       !strcmp(e->name, d->name) && strcmp(signature(e), signature(d)) != 0;
            }
            if (over)
                d->cname = strfmt("%s__%s%s", d->recv_name, d->name, types.buf);
            continue;
        }
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
            defined = defined || ((e->kelvin_proto || e->body) && !strcmp(signature(e), signature(d)));
        }
        bool by_types = overloads_of(d->name, NULL).len > 1 || imported || called_as_c(d->name);
        if (!defined || !strcmp(d->name, "main"))
            by_types = false;
        const char *base = d->name;
        if (d->type_fn) /* T.name is T__name in C (#111) */
            base = strfmt("%s__%s", d->recv_name,
                          !strcmp(d->name + strlen(d->recv_name) + 1, "[]")    ? "subscript"
                          : !strcmp(d->name + strlen(d->recv_name) + 1, "[]=") ? "subscript_set" /* (#136) */
                                                                                : d->name + strlen(d->recv_name) + 1);
        d->cname = by_types ? strfmt("%s%s", base, types.buf) : (char *)base;
    }
    for (int i = 0; i + 1 < proto_copies.len; i += 2) /* the hoisted prototypes take their originals' names (#180) */
        ((Decl *)proto_copies.data[i])->cname = ((Decl *)proto_copies.data[i + 1])->cname;
    for (int i = 0; i < functions.len; i++) {
        Decl *d = functions.data[i];
        char *name = d->recv ? strfmt(d->setter ? "%s__set_%s" : "%s__%s", d->recv_name, d->name) : d->cname;
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
    char kk = owner_letter(kind);
    if (kind && ((!strcmp(kind, "bytes") && (!strcmp(member, "count") || !strcmp(member, "capacity") ||
                                             !strcmp(member, "at") || !strcmp(member, "cstr") ||
                                             !strcmp(member, "isUTF8"))) ||
                 (!strcmp(kind, "string") && (!strcmp(member, "count") || !strcmp(member, "bytes") ||
                                              !strcmp(member, "cstr"))) ||
                 (!strcmp(kind, "array") && (!strcmp(member, "count") || !strcmp(member, "capacity") ||
                                             !strcmp(member, "at"))) ||
                 (!strcmp(kind, "dict") && (!strcmp(member, "count") || !strcmp(member, "keys") ||
                                            !strcmp(member, "values"))) ||
                 (!strcmp(kind, "set") && (!strcmp(member, "count") || !strcmp(member, "elements"))) ||
                 (!strcmp(kind, "io") && (!strcmp(member, "bytes") || !strcmp(member, "string") ||
                                          !strcmp(member, "lines") || !strcmp(member, "eof") ||
                                          !strcmp(member, "position") || !strcmp(member, "count") ||
                                          !strcmp(member, "byte") || !strcmp(member, "fd") ||
                                          !strcmp(member, "status") || !strcmp(member, "signal") ||
                                          !strcmp(member, "error") ||
                                          !strcmp(member, "pid") || !strcmp(member, "path") ||
                                          !strcmp(member, "abspath") || !strcmp(member, "listdir") ||
                                          !strcmp(member, "walk") || !strcmp(member, "stat") ||
                                          !strcmp(member, "lstat") || !strcmp(member, "isdir") ||
                                          !strcmp(member, "isfile") || !strcmp(member, "islink") ||
                                          !strcmp(member, "exists") || !strcmp(member, "basename") ||
                                          !strcmp(member, "dirname") || !strcmp(member, "isatty"))))) {
        /* a Bytes (#54): its count and capacity, its bytes, its text as a
           cstr, a borrow, and whether it is UTF-8; a String (#55): its
           codepoints, its bytes, a read-only borrow, and its text; of a
           place, since a value an expression gives would be lost */
        if (!owner_place(e) && !is_io_std(e)) /* held (#187) */
            e = make_temp(e, strfmt("'.%s' of a%s %s that an expression gives: bind it to a variable first, which frees "
                                    "it when its block ends",
                                    member, kk == 'i' || kk == 'a' ? "n" : "",
                                    kk == 'b' ? "Bytes" : kk == 's' ? "String" : kk == 'd' ? "Dictionary" : kk == 't' ? "Set" : kk == 'i' ? "IO" : "Array"));
        Expr *x = new_expr(E_PROPERTY, name->pos);
        x->a = e;
        x->text = member;
        x->op = (char *)kind;
        x->is_bool = !strcmp(member, "isUTF8") || (kk == 'i' && !strcmp(member, "eof"));
        if (kk == 'i' && (!strcmp(member, "bytes") || !strcmp(member, "string"))) /* the whole file, straight (#82, #107) */
            x->type = base_type(!strcmp(member, "bytes") ? "Bytes" : "String", name->pos);
        else if (kk == 'i' && !strcmp(member, "eof")) /* (#84) */
            x->type = base_type("bool", name->pos);
        else if (kk == 'i' && (!strcmp(member, "position") || !strcmp(member, "count")))
            x->type = base_type("i64", name->pos);
        else if (kk == 'i' && (!strcmp(member, "fd") || !strcmp(member, "status") || !strcmp(member, "signal") ||
                               !strcmp(member, "pid") || !strcmp(member, "error")))
            x->type = base_type("i32", name->pos); /* (#86, #87, #89, #91, #109) */
        else if (kk == 'i' && !strcmp(member, "byte")) /* the next byte, or none at the end (#85) */
            x->type = optional_type(name, base_type("u8", name->pos));
        else if (kk == 'i' && !strcmp(member, "path")) /* its path, and the OS's work on it (#101) */
            x->type = cstr_type(name->pos);
        else if (kk == 'i' && !strcmp(member, "abspath")) /* a String, "" with no path (#104) */
            x->type = base_type("String", name->pos);
        else if (kk == 'i' && (!strcmp(member, "listdir") || !strcmp(member, "walk"))) /* an Array straight (#106) */
            x->type = array_type(name, base_type("String", name->pos));
        else if (kk == 'i' && (!strcmp(member, "stat") || !strcmp(member, "lstat")))
            x->type = stat_type(name); /* of the open file, which always answers: no Result (#104) */
        else if (kk == 'i' && (!strcmp(member, "isdir") || !strcmp(member, "isfile") || !strcmp(member, "islink") ||
                               !strcmp(member, "exists") || !strcmp(member, "isatty")))
            x->type = base_type("bool", name->pos), x->is_bool = true; /* isatty (#103) */
        else if (kk == 'i' && (!strcmp(member, "basename") || !strcmp(member, "dirname")))
            x->type = base_type("String", name->pos);
        if ((kk == 'd' && (!strcmp(member, "keys") || !strcmp(member, "values"))) ||
            (kk == 't' && !strcmp(member, "elements"))) {
            /* d.keys and d.values (#66): Arrays of copies, made by a function
               the codegen writes after the Dictionary's and the Array's C */
            Type *dt = value_type(e);
            bool keys = strcmp(member, "values") != 0;
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
    if (is_converter(&(Token){.kind = TK_KEYWORD, .text = member}) && is_io(value_type(e)))
        error_at(name->pos, "an IO reads a byte with '.byte', and text with '.lines', '.read(n)' or '.string': read a "
                            "number from the text, as %s(line) does (#88)",
                 member);
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
    if (let && !strcmp(let, "self") && parsing_fn && parsing_fn->subscript)
        error_at(t->pos, "a let subscript and a var subscript's getter read self and never change it: a var "
                         "subscript's setter, 'set(v) { ... }', does");
    if (let && !strcmp(let, "self") && parsing_fn && parsing_fn->attribute && !parsing_fn->setter)
        error_at(t->pos, "a let attribute and a var attribute's getter read self and never change it: a var "
                         "attribute's setter, 'set(v) { ... }', does");
    if (let && !strcmp(let, "self") && parsing_fn && parsing_fn->recv && !parsing_fn->setter)
        error_at(t->pos, "a method reads self and never changes it: a var attribute's setter, 'set(v) { ... }', "
                         "changes the caller's var, and so does a function that takes '%s^'",
                 parsing_fn->recv_name);
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
            if (lhs->kind == E_CALL && lhs->op && !strcmp(lhs->op, "subscript_get")) {
                /* v[i] = y and v[i] += y (#136): the setter of the subscript
                   the read chose, on the var that holds v */
                Decl *g = lhs->target;
                char *sname = strfmt("%s=", g->name);
                Decl *setter = NULL;
                List cands = function_named(sname) ? overloads_of(sname, NULL) : (List){0};
                for (int k = 0; k < cands.len && !setter; k++) {
                    Decl *d = cands.data[k];
                    bool same = d->params.len == g->params.len + 1;
                    for (int q = 1; same && q < g->params.len; q++)
                        same = !strcmp(kelvin_type(unqualified(((Var *)d->params.data[q])->type)),
                                       kelvin_type(unqualified(((Var *)g->params.data[q])->type)));
                    if (same)
                        setter = d;
                }
                if (!setter)
                    error_at(t->pos, "this subscript of %s is a let, read and never set: a var subscript has a setter, "
                                     "'var [](i:I):R { get { ... } set(v) { ... } }'",
                             g->recv_name);
                if (!strcmp(t->text, ":="))
                    error_at(t->pos, "':=' sets a reference: a subscript is set with '='");
                if (let_target(lhs->a))
                    error_at(t->pos, "'%s' is a let and cannot change; declare it with var", let_target(lhs->a));
                if (lhs->a->kind != E_IDENT && lhs->a->kind != E_FIELD && lhs->a->kind != E_INDEX &&
                    lhs->a->kind != E_DEREF)
                    error_at(t->pos, "a subscript's setter changes the value it is called on, so that value is a variable");
                Expr *v = parse_assign();
                assign_ok = ok;
                if (strcmp(t->text, "=")) {
                    bool twice = repeatable(lhs->a);
                    for (int k = 0; twice && k < lhs->items.len; k++)
                        twice = repeatable(lhs->items.data[k]);
                    if (!twice)
                        error_at(t->pos, "'v[i] %s y' is 'v[i] = v[i] %.*s y', which reads v and i twice, so neither may "
                                         "hold a call",
                                 t->text, (int)strlen(t->text) - 1, t->text);
                    Expr *bin = new_expr(E_BINARY, t->pos);
                    bin->op = strfmt("%.*s", (int)strlen(t->text) - 1, t->text);
                    bin->a = lhs;
                    bin->b = v;
                    v = overloadable_op(&(Token){.kind = TK_PUNCT, .text = (char *)bin->op})
                            ? resolve_operator(bin, bin->op, lhs, v)
                            : bin;
                }
                Type *pt = ((Var *)setter->params.data[setter->params.len - 1])->type;
                pick_overload(v, pt);
                v = optional_of(string_of_literal(v, pt), pt, v->pos);
                move_argument(v, pt, strfmt("the subscript of %s", g->recv_name));
                Expr *c = new_expr(E_CALL, t->pos);
                c->a = lhs->a;
                c->op = "subscript_set";
                c->target = setter;
                for (int k = 0; k < lhs->items.len; k++)
                    list_push(&c->items, lhs->items.data[k]);
                list_push(&c->items, v);
                return c;
            }
            if (lhs->kind == E_METHOD && lhs->attr) {
                /* v.x = y and v.x += y of a computed attribute (#132): its
                   setter, on the var that holds v */
                Type *vt = value_type(lhs->a);
                Decl *setter = NULL;
                for (int k = 0; k < functions.len && !setter; k++) {
                    Decl *d = functions.data[k];
                    if (d->setter && !strcmp(d->name, lhs->text) && vt && !strcmp(d->recv->name, unqualified(vt)->name))
                        setter = d;
                }
                if (!setter)
                    error_at(t->pos, "'%s' is a let attribute, computed and never set: a var attribute has a setter, "
                                     "'var T.%s:R { get { ... } set(v) { ... } }'",
                             lhs->text, lhs->text);
                if (!strcmp(t->text, ":="))
                    error_at(t->pos, "':=' sets a reference: an attribute is set with '='");
                if (let_target(lhs->a))
                    error_at(t->pos, "'%s' is a let and cannot change; declare it with var", let_target(lhs->a));
                if (lhs->a->kind != E_IDENT && lhs->a->kind != E_FIELD && lhs->a->kind != E_INDEX &&
                    lhs->a->kind != E_DEREF)
                    error_at(t->pos, "the setter of '%s' changes the value it is called on, so that value is a variable",
                             lhs->text);
                Expr *v = parse_assign();
                assign_ok = ok;
                if (strcmp(t->text, "=")) {
                    if (!repeatable(lhs->a))
                        error_at(t->pos, "'x.%s %s y' is 'x.%s = x.%s %.*s y', which reads x twice, so x may not hold "
                                         "a call",
                                 lhs->text, t->text, lhs->text, lhs->text, (int)strlen(t->text) - 1, t->text);
                    Expr *bin = new_expr(E_BINARY, t->pos);
                    bin->op = strfmt("%.*s", (int)strlen(t->text) - 1, t->text);
                    bin->a = lhs;
                    bin->b = v;
                    v = overloadable_op(&(Token){.kind = TK_PUNCT, .text = (char *)bin->op})
                            ? resolve_operator(bin, bin->op, lhs, v)
                            : bin;
                }
                Type *pt = ((Var *)setter->params.data[0])->type;
                pick_overload(v, pt);
                v = optional_of(string_of_literal(v, pt), pt, v->pos);
                move_argument(v, pt, strfmt("the setter of '%s'", lhs->text));
                Expr *c = new_expr(E_CALL, t->pos);
                c->a = lhs->a;
                c->op = "attr_set";
                c->text = lhs->text;
                c->target = setter;
                list_push(&c->items, v);
                return c;
            }
            reject_let_change(lhs, t);
            /* a cstr's bytes never change, and it does not step (#52) */
            if ((lhs->kind == E_INDEX || lhs->kind == E_DEREF) && is_cstr(value_type(lhs->a)))
                error_at(t->pos, "a cstr is immutable (#52): to change text, copy it into a byte array, "
                                 "'var t:[u8](n)' and strcpy, or write through a 'var p:u8^ := s'");
            if ((!strcmp(t->text, "+=") || !strcmp(t->text, "-=")) && is_cstr(value_type(lhs)))
                error_at(t->pos, "a cstr is text, not a cursor (#52): walk it with 'for c in s', index it, or step "
                                 "a 'var p:u8^ := s'");
            if ((!strcmp(t->text, "|=") || !strcmp(t->text, "&=") || !strcmp(t->text, "~=")) &&
                is_set_owner(value_type(lhs))) {
                /* s |= t, s &= t, s ~= t (#73): in place, of another Set in a variable */
                if (!owner_place(lhs))
                    error_at(t->pos, "'%s' on a Set that an expression gives: bind it to a variable first", t->text);
                if (let_target(lhs))
                    error_at(t->pos, "'%s' is a let and cannot change; declare it with var", let_target(lhs));
                Expr *x = new_expr(E_METHOD, t->pos);
                x->a = lhs;
                x->op = "set";
                x->type = value_type(lhs);
                x->text = t->text[0] == '|' ? "insert_all" : t->text[0] == '&' ? "intersect_with" : "symdiff_with";
                Expr *given = parse_assign();
                assign_ok = ok;
                Type *gt = value_type(given);
                if (!gt || strcmp(gt->name, x->type->name) || !owner_place(given))
                    error_at(t->pos, "'%s' takes another %s, in a variable", t->text, kelvin_type(x->type));
                Expr *pb = new_expr(E_PREFIX, t->pos);
                pb->op = "&";
                pb->a = given;
                list_push(&x->items, pb);
                return x;
            }
            if (!strcmp(t->text, "+=") && builtin_owner(value_type(lhs))) {
                /* b += x is b.append(x) (#54, #55) */
                if (is_dict_owner(value_type(lhs)))
                    error_at(t->pos, "a Dictionary has no '+=': add an entry with d[k] = v");
                if (is_set_owner(value_type(lhs))) { /* s += x inserts, s += &other its elements (#71) */
                    if (!owner_place(lhs))
                        error_at(t->pos, "'+=' on a Set that an expression gives: bind it to a variable first");
                    if (let_target(lhs))
                        error_at(t->pos, "'%s' is a let and cannot change; declare it with var", let_target(lhs));
                    Expr *x = new_expr(E_METHOD, t->pos);
                    x->a = lhs;
                    x->op = "set";
                    x->type = value_type(lhs);
                    Expr *given = parse_assign();
                    assign_ok = ok;
                    Type *gt = value_type(given);
                    if (gt && gt->kind == T_PTR && is_set_owner(gt->elem) && !strcmp(gt->elem->name, x->type->name)) {
                        x->text = "insert_all";
                    } else {
                        x->text = "insert";
                        given = dict_key(given, x->type);
                    }
                    list_push(&x->items, given);
                    return x;
                }
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
            if (!strcmp(t->text, "="))
                e->b = optional_of(string_of_literal(e->b, target_type(lhs)), target_type(lhs), t->pos); /* (#70, #72) */
            if (!strcmp(t->text, "=")) { /* an owner takes a value and frees what it held (#54) */
                reject_owner_copy(e->b, target_type(lhs), t->pos);
                reject_record_mismatch(e->b, target_type(lhs), t->pos);
                if (lhs->kind == E_IDENT && is_owner(value_type(lhs)))
                    set_moved(lhs->text, false);
                if (lhs->kind != E_IDENT && is_owner(value_type(lhs)) && !is_io(value_type(lhs)))
                    e->recv_type = unqualified(value_type(lhs)); /* p.name = v frees the old one (#134) */
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
    if (is_p(open, "$") && is_p(peek2(), "[") && t && is_array_owner(t)) {
        /* $[...] of the declared Array type (#62) */
        Token *d = advance();
        return array_of_list(d, t);
    }
    if (t && (is_dict_owner(t) || is_set_owner(t)) && (is_p(open, "{") || (is_p(open, "$") && is_p(peek2(), "{")))) {
        /* {k: v, ...} or ${k: v, ...} of the declared Dictionary type (#65, #69); {a, b} of a Set (#71) */
        Token *d = is_p(open, "$") ? advance() : open;
        return is_set_owner(t) ? set_of_list(d, t, NULL, NULL) : dict_of_list(d, t, NULL, NULL);
    }
    if (!bracket && !is_p(open, "{"))
        return parse_assign();
    if (!bracket && variant_record(t) && !is_p(peek2(), ".")) {
        /* {...} of a T? or a Result is the value's initializer, wrapped (#72, #75) */
        Type *inner = ((Var *)variant_record(t)->members.data[value_case(variant_record(t))])->type;
        Expr *c = new_expr(E_COMPOUND, open->pos);
        c->type = inner;
        c->a = parse_initializer_for(inner);
        count_items(inner, c->a);
        return optional_of(c, t, open->pos);
    }
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
        while ((is_p(peek(), ".") && (!parsing_fn || designator_ahead(cur))) ||
               (is_p(peek(), "[") && is_p(&toks[skip_group(cur)], "="))) {
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
        Expr *value = string_of_literal(drop_cstr(parse_initializer_for(item), item), item); /* a cstr into a u8^ member (#52) */
        value = optional_of(value, item, value->pos); /* a T into a T? member (#72) */
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
    if ((at && is_dict_owner(at)) || list_is_dict(cur)) /* [k: v] was a Dictionary's until #69 */
        error_at(peek()->pos, "a Dictionary's entries are written in braces: ${k: v, ...}, and ${:} for none");
    Token *open = expect_p("[");
    Type *elem = at ? at->elem : NULL;
    Expr *list = new_expr(E_INIT, open->pos);
    list->bracket = true;
    init_depth++;
    while (!is_p(peek(), "]")) {
        if ((is_p(peek(), ".") && (!parsing_fn || designator_ahead(cur))) ||
            (is_p(peek(), "[") && is_p(&toks[skip_group(cur)], "=")))
            error_at(peek()->pos, "the elements of an Array are written in order, without designators");
        Expr *x;
        if (is_p(peek(), "[")) {
            if (at && !is_array_owner(elem))
                error_at(peek()->pos, "'[...]' here makes an Array, and an element of %s is %s", kelvin_type(at),
                         kelvin_type(elem));
            x = array_of_list(t, at ? elem : NULL);
        } else {
            x = string_of_literal(drop_cstr(parse_initializer_for(elem), elem), elem); /* a cstr into a u8^ element (#52) */
            x = optional_of(x, elem, x->pos); /* a T into a T? element (#72) */
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
    if (is_set_owner(t))
        return strfmt("{%s}", kelvin_type(t->elem));
    if (is_dict_owner(t))
        return strfmt("{%s: %s}", kelvin_type(t->key), dollar_spelling(t->elem));
    return is_array_owner(t) ? strfmt("[%s]", dollar_spelling(t->elem)) : kelvin_type(t);
}

/* ${K: V} (#70): Dictionary<K, V>; a [...] value is an Array, a ${...} a
   Dictionary, a {...} a struct with no tag, as everywhere a type goes */
static Type *parse_dollar_dict(Token *at) {
    expect_p("{");
    Type *key = parse_type_in(TYPE_DECL);
    if (accept_p("}")) /* ${T} is Set<T> (#71) */
        return set_type(at, key);
    if (!accept_p(":"))
        error_at(peek()->pos, "expected ':' between the key and value types of ${K: V}, or '}' after the element "
                              "type of a Set, ${T}");
    Type *val = parse_type_in(TYPE_DECL);
    if (is_p(peek(), "("))
        error_at(peek()->pos, "an Array grows, and has no count in its type: write ${%s: %s}, and give the elements "
                              "or a count where it is made",
                 kelvin_type(key), dollar_spelling(val));
    expect_p("}");
    return dict_type(at, key, val);
}

/* $[T] (#64): Array<T>; a [...] inside is an Array in turn, as it is in
   $[[1, 0], [0, 1]], so $[[i64]] is Array<Array<i64>> */
static Type *parse_dollar_array(Token *at) {
    expect_p("[");
    Type *elem = is_p(peek(), "[") ? parse_dollar_array(peek()) : parse_type_in(TYPE_DECL);
    if (is_p(peek(), ":")) /* $[K: V] was a Dictionary's type until #70 */
        error_at(peek()->pos, "a Dictionary's type is written in braces: ${%s: V}, as its entries are", kelvin_type(elem));
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

/* Set<T> (#71): as a Dictionary with no values; T as a key */
static bool is_set_owner(Type *t) {
    if (t && t->kind == T_TYPEOF)
        t = t->elem;
    return t && t->kind == T_BASE && t->cname && !strncmp(t->name, "Set<", 4);
}

static Type *set_type(Token *at, Type *elem) {
    check_dict_key(elem);
    Type *t = xcalloc(1, sizeof *t);
    t->kind = T_BASE;
    t->pos = at->pos;
    t->key = elem;
    t->elem = elem;
    t->name = strfmt("Set<%s>", kelvin_type(elem));
    t->cname = strfmt("_kv_set_%s", mangled_type(elem));
    for (int i = 0; i < program->arrays.len; i++)
        if (!strcmp(((Type *)program->arrays.data[i])->name, t->name))
            return t;
    list_push(&program->arrays, t);
    list_push(&program->array_decls, (void *)(intptr_t)program->decls.len);
    return t;
}

static Type *parse_set_type(Token *kw) {
    if (!accept_p("<"))
        error_at(peek()->pos, "a Set names its element type: Set<T>");
    Type *elem = parse_type_in(TYPE_DECL);
    if (is_p(peek(), ">>"))
        toks[cur].text = ">";
    else if (!accept_p(">"))
        error_at(peek()->pos, "expected '>' after the element type of Set<T>");
    return set_type(kw, elem);
}

/* ${a, b, c} and Set<T>({a, b, c}) (#71): the elements written, T inferred
   from the first as a key's is, or given; ${} is the empty Set where the
   type is known */
static Expr *set_of_list(Token *t, Type *st, Token *open, Expr *first) {
    bool saved_brace = brace_ends_condition, saved_for = brace_in_for, saved_annotation = ident_annotation_ok;
    brace_ends_condition = brace_in_for = false;
    init_depth++;
    if (!open)
        open = expect_p("{");
    Expr *e = new_expr(E_CALL, t->pos);
    e->a = new_expr(E_IDENT, t->pos);
    e->a->text = "Set";
    e->op = "set";
    e->text = "list";
    e->type = st;
    Type *kt = st ? st->key : NULL;
    if (!first && is_p(peek(), ":"))
        error_at(peek()->pos, "an empty Set is written ${}; ${:} is an empty Dictionary");
    for (Expr *k = first;; k = NULL) {
        if (!k) {
            if (is_p(peek(), "}"))
                break;
            ident_annotation_ok = false;
            k = parse_assign();
            ident_annotation_ok = saved_annotation;
        }
        if (is_p(peek(), ":"))
            error_at(peek()->pos, "a Set holds elements, not entries: ${a, b, c}; a Dictionary's are ${k: v}");
        if (!st) {
            Type *k0 = inferred_type(k, k->pos);
            if (k0 && is_cstr(k0))
                k0 = base_type("String", k->pos);
            if (!kt) {
                if (!k0)
                    error_at(k->pos, "this element has no type kelvinc sees: write Set<T>({...})");
                kt = k0;
            } else if (!k0 || strcmp(kelvin_type(k0), kelvin_type(kt))) {
                error_at(k->pos, "every element of a Set has one type: this one is %s, the first %s",
                         k0 ? kelvin_type(k0) : "unseen", kelvin_type(kt));
            }
        }
        list_push(&e->items, k);
        if (!accept_p(","))
            break;
    }
    expect_p("}");
    if (!st) {
        if (!kt)
            error_at(open->pos, "${} has no element type here: write Set<T>(), or give the variable a type, as in "
                                "'var s:${String} = ${}'");
        st = e->type = set_type(t, kt);
    }
    if (!e->items.len)
        e->text = "";
    for (int i = 0; i < e->items.len; i++)
        e->items.data[i] = dict_key(e->items.data[i], st);
    init_depth--;
    brace_ends_condition = saved_brace;
    brace_in_for = saved_for;
    return e;
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

/* a string literal where a String is expected (#70): String("...") of it,
   as an Array's, a Dictionary's or a struct's String takes it */
static Expr *string_of_literal(Expr *x, Type *target) {
    if (!target || !is_string(target) || x->kind != E_STRING)
        return x;
    Expr *e = new_expr(E_CALL, x->pos);
    e->a = new_expr(E_IDENT, x->pos);
    e->a->text = "String";
    e->op = "string";
    list_push(&e->items, x);
    return e;
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

/* ${k: v, ...} and Dictionary<K, V>({k: v, ...}) (#65, braces since #69):
   the entries written; K and V inferred from the first entry as a
   variable's type is, every other entry alike, or given. The C sets each entry into an
   empty Dictionary; a value that owns is moved in */
static Expr *dict_of_list(Token *t, Type *dt, Token *open, Expr *first) {
    bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
    brace_ends_condition = brace_in_for = false;
    init_depth++;
    if (!open)
        open = expect_p("{");
    Expr *e = new_expr(E_CALL, t->pos);
    e->a = new_expr(E_IDENT, t->pos);
    e->a->text = "Dictionary";
    e->op = "dict";
    e->text = "list";
    e->type = dt;
    if (!first && is_set_owner(dt)) { /* ${a, b} of a declared Set (#71) */
        init_depth--;
        brace_ends_condition = saved_brace;
        brace_in_for = saved_for;
        return set_of_list(t, dt, open, NULL);
    }
    if (!first && !dt && is_p(peek(), "}")) /* ${}: an empty Set, typed */
        error_at(open->pos, "${} has no element type here: write Set<T>(), or give the variable a type, as in "
                            "'var s:${String} = ${}'");
    if (!first && dt && is_p(peek(), "}"))
        error_at(peek()->pos, "an empty Dictionary is written ${:}");
    if (!first && accept_p(":")) { /* ${:}: empty */
        if (!dt)
            error_at(open->pos, "${:} has no key and value types here: write Dictionary<K, V>(), or give the "
                                "variable a type, as in 'var d:${String: i64} = ${:}'");
        expect_p("}");
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
            if (is_p(peek(), "}"))
                break;
            ident_annotation_ok = false; /* the `:` after a key is the entry's */
            k = parse_assign();
            ident_annotation_ok = saved_annotation;
        }
        if (!dt && !e->items.len && !is_p(peek(), ":")) { /* ${a, b, c}: a Set (#71) */
            init_depth--;
            brace_ends_condition = saved_brace;
            brace_in_for = saved_for;
            return set_of_list(t, NULL, open, k);
        }
        if (!accept_p(":"))
            error_at(peek()->pos, "an entry of a Dictionary is written key: value");
        Expr *v = is_p(peek(), "[") ? array_of_list(t, vt) : string_of_literal(drop_cstr(parse_initializer_for(vt), vt), vt);
        v = optional_of(v, vt, v->pos); /* a T into a T? value (#72) */
        if (v->kind == E_INIT && vt) { /* {...} of a struct or array value, as its compound literal */
            Expr *c = new_expr(E_COMPOUND, v->pos);
            c->type = vt;
            c->a = v;
            count_items(vt, v);
            v = c;
        }
        if (!dt) {
            Type *k0 = inferred_type(k, k->pos), *v0 = inferred_type(v, v->pos);
            if (k0 && is_cstr(k0))
                k0 = base_type("String", k->pos);
            if (!kt) {
                if (!k0 || !v0)
                    error_at(k->pos, "the %s of this entry has no type kelvinc sees: write Dictionary<K, V>({...})",
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
    expect_p("}");
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

/* IO (#82): stdio as an owner, a FILE closed when its block ends */
static bool is_io(Type *t) {
    if (t && t->kind == T_TYPEOF)
        t = t->elem;
    return t && t->kind == T_BASE && !strcmp(t->name, "IO");
}

/* IO.stdin, IO.stdout or IO.stderr (#82): a place in C, never closed */
static bool is_io_std(Expr *e) { return e->kind == E_CALL && e->op && !strcmp(e->op, "io_std"); }

/* "bytes" or "string" for the built-in owners, NULL otherwise */
/* the one letter of a built-in owner's kind: b, s, a, d, or t for a Set,
   whose name starts as a String's does (#71) */
static char owner_letter(const char *kind) {
    return kind && kind[0] == 's' && kind[1] == 'e' ? 't' : kind ? kind[0] : 0;
}

static const char *builtin_owner(Type *t) {
    return is_bytes(t)         ? "bytes"
           : is_string(t)      ? "string"
           : is_array_owner(t) ? "array"
           : is_dict_owner(t)  ? "dict"
           : is_set_owner(t)   ? "set"
           : is_io(t)          ? "io"
                               : NULL;
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
    if (is_bytes(t) || is_string(t) || is_array_owner(t) || is_dict_owner(t) || is_set_owner(t) || is_io(t))
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
    if (e->kind == E_INDEX && e->op && !strcmp(e->op, "slice"))
        return false; /* a slice is a copy an expression gives (#68) */
    return is_owner(value_type(e)) &&
           (e->kind == E_IDENT || e->kind == E_FIELD || e->kind == E_INDEX || e->kind == E_DEREF);
}

/* May x, of an owner variant type, be passed by value to its _eq (#79)?
   A place, which keeps it; or a case made on the spot whose value does
   not own (none, ok(5)), so that nothing is lost unfreed */
static bool eq_operand_ok(Expr *x) {
    if (owner_place(x))
        return true;
    if (x->kind == E_CALL && x->op && !strcmp(x->op, "case_make") && x->target) {
        if (!x->items.len)
            return true;
        Var *c = case_named(x->target, x->text, NULL);
        return c && !is_owner(c->type);
    }
    return false;
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
            error_at(arg->pos, "'%s' is a value its Array, Dictionary, Optional or Result still owns: pass a borrow, '&%s', or a copy",
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
        int bound_at = scope_types.len - 1; /* the initializer may bind temporaries after it (#187) */
        v->init = parse_initializer();
        v->type = inferred_type(v->init, v->pos);
        reject_let_vla(v, let);
        reject_owner_copy(v->init, v->type, v->init->pos);
        reject_owner_array(v);
        scope_types.data[bound_at] = v->type;
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
        v->init = string_of_literal(drop_cstr(v->init, v->type), v->type); /* a literal into a String (#70) */
        v->init = optional_of(v->init, v->type, v->init->pos); /* a T into a T? (#72) */
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
    return line_break(t - 1, t) &&
           (!continues_expression(t) || (is_p(t, "(") && at_statement_level()) || self_statement_at(i));
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

/* #import, of a C header or a Kelvin file (#40), is for the top level;
   #inline C (#197) for the top level and a function's blocks (#198) */
static void reject_inner_import(void) {
    if (peek()->kind == TK_IMPORT || peek()->kind == TK_IMPORT_K)
        error_at(peek()->pos, "#import is for the top level of a file, outside functions, structs and blocks");
    if (peek()->kind == TK_INLINE_C)
        error_at(peek()->pos, "#inline C is for the top level of a file and a function's blocks, outside structs, "
                              "unions and enums");
}

/* the statements of a block whose `{` (t) has been read, and its `}` */
static Stmt *parse_block_rest(Token *t) {
    Stmt *s = new_stmt(S_BLOCK, t->pos);
    open_scope();
    block_depth++;
    while (!is_p(peek(), "}")) {
        if (peek()->kind == TK_EOF || peek()->kind == TK_FILE_END)
            error_at(t->pos, "unterminated block");
        if (peek()->kind != TK_INLINE_C) /* a statement of a function's (#198) */
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
    if (!rt)
        rt = arg_type(recv); /* 1.0.i, (-1.0).i (#148): a literal's own type, f64 */
    if (rt && rt->kind != T_BASE) /* a pointer, an array, a function: no method of the program is on it (#179) */
        return NULL;
    bool seen = rt && rt->kind == T_BASE;
    Decl *found = NULL;
    int n = 0;
    for (int i = 0; i < functions.len; i++) {
        Decl *d = functions.data[i];
        if (!d->recv || d->setter || strcmp(d->name, name) || (seen && strcmp(d->recv->name, rt->name)))
            continue;
        if (!found || strcmp(found->recv->name, d->recv->name))
            n++; /* a prototype and its definition are one method */
        found = d;
    }
    return n == 1 ? found : NULL;
}

/* The methods of the name on the receiver's type kelvinc sees, one per
   signature, a definition before its prototype (#158); none where the
   receiver's type is unseen */
static List method_candidates(Expr *recv, const char *name) {
    List out = {0};
    Type *rt = value_type(recv);
    if (!rt)
        rt = arg_type(recv);
    if (!rt || rt->kind != T_BASE)
        return out;
    for (int i = 0; i < functions.len; i++) {
        Decl *d = functions.data[i];
        if (!d->recv || d->setter || d->attribute || d->type_fn || strcmp(d->name, name) || strcmp(d->recv->name, rt->name))
            continue;
        bool seen = false;
        for (int j = 0; j < out.len && !seen; j++) {
            Decl *o = out.data[j];
            if (!strcmp(signature(o), signature(d))) {
                if (d->body)
                    out.data[j] = d;
                seen = true;
            }
        }
        if (!seen)
            list_push(&out, d);
    }
    return out;
}

/* the arguments between the '(' at token i and its ')', counted by the
   commas at their depth: 0 for '()', -1 where no ')' closes it (#168) */
static int call_args_ahead(int i) {
    int depth = 0, args = 0;
    bool any = false;
    for (int k = i + 1; toks[k].kind != TK_EOF && toks[k].kind != TK_FILE_END; k++) {
        Token *t = &toks[k];
        if (is_p(t, "(") || is_p(t, "[") || is_p(t, "{")) {
            depth++;
        } else if (is_p(t, ")") || is_p(t, "]") || is_p(t, "}")) {
            if (depth == 0)
                return any ? args + 1 : 0;
            depth--;
        } else if (depth == 0 && is_p(t, ",")) {
            args++;
        }
        any = true;
    }
    return -1;
}

/* Does a method of the name on the receiver take no argument? (#164) */
static bool method_takes_none(Expr *recv, const char *name) {
    List cands = method_candidates(recv, name);
    for (int i = 0; i < cands.len; i++)
        if (!((Decl *)cands.data[i])->params.len)
            return true;
    return false;
}

/* the type of parameter k for an anonymous argument of a method call
   (#158): among overloads, the one that has a function there, if one does */
static Type *method_param_type(List *cands, Decl *m, int k) {
    if (cands->len > 1) {
        Type *only = NULL;
        int n = 0;
        for (int i = 0; i < cands->len; i++) {
            Decl *d = cands->data[i];
            Type *t = k < d->params.len ? ((Var *)d->params.data[k])->type : NULL;
            if (t && unqualified(t)->kind == T_FUNC) {
                only = t;
                n++;
            }
        }
        if (n == 1)
            return only;
    }
    return m && k < m->params.len ? ((Var *)m->params.data[k])->type : NULL;
}

/* Is t a value kelvinc writes a printer for (#123): a struct, a union or
   an enum with values it sees, an Optional, a Result, an Array, a
   Dictionary or a Set? */
static bool showable(Type *t) {
    Decl *record;
    return t && (is_array_owner(t) || is_dict_owner(t) || is_set_owner(t) ||
                 (type_class(t, &record) == 's' && record));
}

/* print and println show a struct, an enum with values, an Optional, a
   Result, an Array, a Dictionary and a Set by kelvinc's printer of it,
   on one line (#122, #123), and v.pretty indented (#124): each such
   argument becomes a "show" property the codegen writes */
static void print_records_as_text(Expr *call) {
    for (int i = 0; i < call->items.len; i++) {
        Expr *x = call->items.data[i];
        if (x->kind == E_PROPERTY && x->op && !strcmp(x->op, "pretty")) {
            x->op = "show"; /* printed where it stands, indented, not made a String */
            x->type = cstr_type(x->pos);
            continue;
        }
        Type *t = value_type(x);
        if (!showable(t))
            continue;
        if (is_owner(t) && !owner_place(x)) /* held while it prints (#187) */
            x = make_temp(x, "a value that an expression gives is printed once bound: bind it to a variable first");
        Expr *s = new_expr(E_PROPERTY, x->pos);
        s->a = x;
        s->text = "show";
        s->op = "show";
        s->recv_type = unqualified(t);
        s->type = cstr_type(x->pos);
        call->items.data[i] = s;
    }
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
    print_records_as_text(call);
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
            error_at(e->pos, "'%s' is a value its Array, Dictionary, Optional or Result still owns: return a copy, '%s.copy()'", e->text,
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
        Decl *m = e->method ? e->method : method_named(e->a, e->text);
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
        Decl *m = e->method ? e->method : method_named(e->a, e->text);
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
static void finish_drops(int from) {
    for (int i = from; i < pending_drops.len; i++) {
        Stmt *s = pending_drops.data[i];
        if (!s->closed)
            continue; /* returned by implicit_return */
        if (!s->name)
            error_at(s->pos, "a struct that owns is given and dropped here: bind it to a variable, which frees it");
        Expr *drop = new_expr(E_CALL, s->pos);
        drop->a = new_expr(E_IDENT, s->pos);
        drop->a->text = s->name;
        drop->op = "c";
        list_push(&drop->items, s->expr);
        s->expr = drop;
        s->closed = false;
    }
    pending_drops.len = from;
}

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
        last->closed = false; /* its owner is returned, not dropped (#81) */
        pick_overload(last->expr, d->ret);
        last->expr = optional_of(last->expr, d->ret, last->expr->pos); /* a T, or none, of a T? result, as return wraps it (#114) */
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
    case E_TEMP: /* (#187) */
        return e->b && has_effect(e->b);
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
            !strcmp(e->text, "keys") || !strcmp(e->text, "values") || !strcmp(e->text, "utf32") ||
            !strcmp(e->text, "codepoint") || !strcmp(e->text, "capacity") || (e->op && !strcmp(e->op, "tagged")))
            return NULL; /* .count and .isNull are numbers too (#49, #50), and a uchr's codepoint (#156) */
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

/* The type of arithmetic for the result of a .map function (#182), where
   kelvinc sees it without C's promotions: the one number type of both
   operands, or of one where the other is a literal it fits (an integer
   literal with any number type, a floating one with f32 or f64); a
   unary - or ~ keeps its operand's; NULL otherwise, which asks for the
   result to be written. Elsewhere arithmetic infers nothing (#47). */
static Type *arithmetic_type(Expr *e) {
    if (!e)
        return NULL;
    if (e->kind == E_PREFIX && (!strcmp(e->op, "-") || !strcmp(e->op, "~")))
        return arithmetic_type(e->a);
    Type *t = value_type(e);
    if (t && t->kind == T_BASE && number_kind(t))
        return t;
    if (e->kind != E_BINARY)
        return NULL;
    static const char *ops[] = {"+", "-", "*", "/", "%", "&", "|", "^", "<<", ">>", NULL};
    bool arith = false;
    for (int i = 0; ops[i]; i++)
        arith = arith || !strcmp(e->op, ops[i]);
    if (!arith)
        return NULL;
    bool la = e->a->kind == E_LITERAL, lb = e->b->kind == E_LITERAL;
    Type *ta = la ? NULL : arithmetic_type(e->a), *tb = lb ? NULL : arithmetic_type(e->b);
    if (!strcmp(e->op, "<<") || !strcmp(e->op, ">>"))
        return ta; /* the left operand's type */
    if (ta && tb)
        return !strcmp(kelvin_type(ta), kelvin_type(tb)) ? ta : NULL;
    Type *seen = ta ? ta : tb;
    Expr *lit = ta ? e->b : e->a;
    if (!seen || lit->kind != E_LITERAL)
        return NULL;
    bool floating = strchr(lit->text, '.') || ((strchr(lit->text, 'e') || strchr(lit->text, 'E')) && strncmp(lit->text, "0x", 2));
    bool seen_float = !strcmp(number_kind(seen), "f64");
    if (lit->text[0] == '\'' || !strcmp(lit->text, "true") || !strcmp(lit->text, "false") || !isdigit((unsigned char)lit->text[0]))
        return NULL;
    return floating && !seen_float ? NULL : seen;
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
    bool infer = infer_anon_result;
    infer_anon_result = false;
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
        if (result && void_result_ahead()) { /* :() (#141) */
            advance();
            advance();
            d->ret = NULL;
        } else
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
    int drops_from = pending_drops.len;
    d->body = parse_fn_body(written ? open : expect_p("{"));
    /* one expression is the result, as in { $0 < $1 } (#32, #35); without
       a result, it must do something, as { total += $0 } does: `{x: 1}`
       is a label in a body, and a list where C's argument is meant */
    Stmt *only = d->body->stmts.len == 1 ? d->body->stmts.data[0] : NULL;
    while (only && only->kind == S_LABEL)
        only = only->body;
    if (infer && !written && !d->ret && anon_kind == ANON_CONTEXT) {
        /* .map { ... } (#80): the result is the one expression's type */
        if (!only || only->kind != S_EXPR)
            error_at(open->pos, "the function of '.map' gives a value: one expression, as in '{ $0 + 1 }', or written "
                                "parameters and a result, as in '{ (v:i64):i64 in ... }'");
        d->ret = inferred_type(only->expr, only->expr->pos);
        if (!d->ret)
            d->ret = arithmetic_type(only->expr); /* $0 * 2 of an i64 (#182): the operands' one number type */
        if (!d->ret)
            error_at(only->expr->pos, "the result of this function is not a type kelvinc sees: write its parameters "
                                      "and result, as in '{ (v:i64):i64 in v * 2 }', or convert the value, as in "
                                      "'i64(...)'");
    }
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
    finish_drops(drops_from);
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
            error_at(t->pos, "'$' alone is not a value: $\"text\" is a String, $[a, b] an Array, ${k: v} a "
                             "Dictionary, and an anonymous function's parameters are $[0], $[1], ..., or $0, $1, ...");
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
    if (switch_record && peek()->kind == TK_IDENT &&
        (is_p(peek2(), ":") || is_p(peek2(), ",") || is_p(peek2(), "("))) { /* case n:, case a, b:, case n(x): (#119) */
        int k;
        Var *c = case_named(switch_record, peek()->text, &k);
        if (!c)
            error_at(peek()->pos, "%s has no case '%s': the cases are %s", record_spelling(switch_record),
                     peek()->text, case_list(switch_record));
        Token *cn = advance();
        s->expr = new_expr(E_LITERAL, cn->pos);
        s->expr->text = strfmt("%d", k);
        s->name = c->name;
        if (accept_p("(")) {
            /* case n(x): (#119) binds x, a let, to the case's value for the
               case's body, as if let n(x) = e does; a let the enum still owns */
            if (!c->type)
                error_at(cn->pos, "case '%s' of %s carries no value: nothing to bind, write 'case %s:'", c->name,
                         record_spelling(switch_record), c->name);
            Token *b = peek();
            reject_kv_name(b);
            s->name2 = expect_ident(strfmt("a name, as in 'case %s(x):'", c->name));
            expect_p(")");
            s->type = c->type;
            declare_binding(s->name2, c->type, LET_EACH);
        }
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
    bool io_read = seq->kind == E_METHOD && seq->op && !strcmp(seq->op, "io") && !strcmp(seq->text, "read");
    bool io_lines = seq->kind == E_PROPERTY && seq->op && !strcmp(seq->op, "io") && !strcmp(seq->text, "lines");
    if (io_read || io_lines) {
        /* f.read(n): the next n bytes at most, a Bytes; f.lines: each line,
           a String (#82); the loop owns the one it holds, x borrows it */
        if (s->name2)
            error_at(s->pos, "two loop variables walk a Dictionary's entries; an IO's chunks or lines take one");
        s->each = io_read ? EACH_IO_READ : EACH_IO_LINES;
        if (io_read)
            s->step = seq->items.data[0];
        elem = base_type(io_read ? "Bytes" : "String", seq->pos);
        if (written && strcmp(kelvin_type(written), kelvin_type(elem)))
            error_at(written->pos, "the loop variable of %s is a %s, not %s", io_read ? ".read(n)" : ".lines",
                     elem->name, kelvin_type(written));
    } else if (is_set_owner(t)) { /* its elements, in order (#71) */
        if (!owner_place(seq))
            error_at(seq->pos, "for over a Set that an expression gives: bind it to a variable first");
        if (s->name2)
            error_at(s->pos, "two loop variables walk a Dictionary's entries; a Set's elements take one");
        s->each = EACH_DICT;
        elem = t->elem;
    } else if (is_dict_owner(t)) { /* its entries, in order (#65): the key, or key and value */
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

/* for x in make() (#187): what the loop walks, held in a hidden let of a
   block around the loop, which frees it when the loop is done; an IO's
   .read(n) and .lines walk as they read, and are left as they are */
static Stmt *parse_for_each_held(Stmt *s, Type *written) {
    Expr *seq = s->expr;
    Type *t = value_type(seq);
    bool io_walk = (seq->kind == E_METHOD && seq->op && !strcmp(seq->op, "io") && !strcmp(seq->text, "read")) ||
                   (seq->kind == E_PROPERTY && seq->op && !strcmp(seq->op, "io") && !strcmp(seq->text, "lines"));
    if (io_walk || !is_owner(t) || owner_place(seq))
        return parse_for_each(s, written);
    Var *v = xcalloc(1, sizeof *v);
    v->name = strfmt("_kv_tmp%d", ++temp_serial);
    v->pos = seq->pos;
    v->type = unqualified(t);
    v->init = seq;
    v->is_let = true;
    declare_binding(v->name, v->type, LET_VALUE);
    Expr *id = new_expr(E_IDENT, seq->pos);
    id->text = v->name;
    s->expr = id;
    Stmt *decl = new_stmt(S_VAR, s->pos);
    list_push(&decl->vars, v);
    Stmt *loop = parse_for_each(s, written);
    Stmt *block = new_stmt(S_BLOCK, s->pos);
    list_push(&block->stmts, decl);
    list_push(&block->stmts, loop);
    return block;
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
        return parse_for_each_held(s, written);
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

    if (t->kind == TK_INLINE_C) { /* C statements where they stand (#198) */
        if (as_body)
            error_at(pos, "#inline C cannot be the body of a statement or follow a label; put it in a block");
        Stmt *s = new_stmt(S_INLINE_C, pos);
        s->name = advance()->text;
        return s;
    }
    if (is_p(t, "{"))
        return parse_block();
    if (accept_p(";"))
        return new_stmt(S_EMPTY, pos);
    if (binding_ahead(cur)) {
        int at = cur + 1 + (is_kw(t, "static") || is_kw(t, "extern"));
        reject_c_fn_pointer(at, "var ");
        if (function_shape(at) == 2 && params_ahead(at + 1)) {
            /* let f(...):R { ... } inside a function (#180): a function of the
               program as one at the top level is, written where it is used,
               named in this block alone, and seeing globals and its own
               parameters, not the locals around it, as C has no closures */
            if (!is_kw(t, "let") || !parsing_fn)
                error_at(toks[at].pos, "a function defined inside a function is written 'let %s(...)', in a function's body",
                         toks[at].text);
            advance();
            parse_nested_fn(pos);
            return new_stmt(S_EMPTY, pos);
        }
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
        if (is_kw(peek(), "let")) {
            /* if let x = e { ... } (#74): e an Optional or a Result; its value
               binds x, a let it still owns, when present */
            advance();
            Token *name = peek();
            reject_kv_name(name);
            char *first = expect_ident("a name, as in 'if let x = e'");
            char *casename = NULL;
            if (accept_p("(")) {
                /* if let err(e) = r (#78): the case by its name, and the
                   name its value binds; of any enum with values */
                casename = first;
                reject_kv_name(peek());
                s->name = expect_ident(strfmt("a name, as in 'if let %s(x) = e'", casename));
                expect_p(")");
            } else {
                s->name = first;
            }
            if (!accept_p("="))
                error_at(peek()->pos, "expected '=' after the name of 'if let %s'", s->name);
            bool saved_brace = brace_ends_condition;
            brace_ends_condition = true;
            s->expr = parse_expr();
            brace_ends_condition = saved_brace;
            Type *et = value_type(s->expr);
            Decl *r = et ? (casename ? tagged_record(et) : variant_record(et)) : NULL;
            if (!r)
                error_at(s->expr->pos, casename ? "'if let %s(%s)' takes an enum with values, a Result or an Optional, and this is %s"
                                                : "'if let' takes an Optional or a Result, and this is %s",
                         casename ? casename : et ? kelvin_type(et) : "not one", casename ? s->name : "",
                         et ? kelvin_type(et) : "not one");
            if (casename) {
                int k;
                Var *c = case_named(r, casename, &k);
                if (!c)
                    error_at(name->pos, "%s has no case '%s': its cases are %s", kelvin_type(et), casename, case_list(r));
                if (!c->type)
                    error_at(name->pos, "case '%s' of %s carries no value to bind: test it with '.is(%s)'", casename,
                             kelvin_type(et), casename);
                s->each = k;
            } else {
                s->each = value_case(r);
            }
            s->elem = unqualified(et);
            Type *vt = xcalloc(1, sizeof *vt);
            *vt = *((Var *)r->members.data[s->each])->type;
            vt->is_const = vt->is_volatile = false;
            s->type = vt;
            s->closed = s->expr->kind == E_IDENT || s->expr->kind == E_FIELD || s->expr->kind == E_INDEX ||
                        s->expr->kind == E_DEREF; /* a place: read where it is */
            open_scope();
            declare_binding(s->name, vt, LET_EACH);
            s->body = parse_block_body("if let");
            close_scope();
            if (accept_kw("else")) {
                if (!is_kw(peek(), "if") && !is_p(peek(), "{"))
                    error_at(peek()->pos, "expected '{' or 'if' after 'else': the body of 'else' is a block");
                s->els = is_p(peek(), "{") ? parse_block() : parse_stmt();
            }
            return s;
        }
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
        for (int k = 0; k < s->body->stmts.len; k++) /* a case that binds (#119): the subject is read in its body */
            if (((Stmt *)s->body->stmts.data[k])->kind == S_CASE && ((Stmt *)s->body->stmts.data[k])->name2)
                s->name2 = "binds";
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
            if (last->name2 && (last != s || is_p(peek(), ",")))
                error_at(last->pos, "a case that binds a value, 'case %s(%s):', stands alone: it cannot share a body "
                                    "with another case",
                         last->name, last->name2);
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
        Decl *rd = NULL;
        char rc = result && parsing_fn->ret->kind == T_BASE && !parsing_fn->ret->cname ? type_class(parsing_fn->ret, &rd) : 0;
        if (is_p(peek(), "{") && result && !ret && !signature_ahead(cur) &&
            (variant_record(parsing_fn->ret) || rc == 's' || rc == 'c')) {
            /* return {...} (#77): the list takes the result type, as a
               declaration's does: a struct's or union's, an enum with
               values' {.n = v}, or the value of a Result or a T?, wrapped */
            Token *open = peek();
            if (variant_record(parsing_fn->ret)) {
                s->expr = parse_initializer_for(parsing_fn->ret);
            } else {
                Expr *c = new_expr(E_COMPOUND, open->pos);
                c->type = parsing_fn->ret;
                c->a = parse_initializer_for(parsing_fn->ret);
                s->expr = c;
            }
        } else if (!is_p(peek(), ";") && !is_p(peek(), "}") && peek()->kind != TK_EOF && peek()->kind != TK_FILE_END &&
                   (result || !newline_before())) {
            s->expr = parse_expr();
            pick_overload(s->expr, result ? parsing_fn->ret : NULL);
            if (result)
                s->expr = optional_of(s->expr, parsing_fn->ret, s->expr->pos); /* return v of a T? (#72) */
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
    bool call_like = (is_converter(t) && is_p(peek2(), "(")) ||
                     ((!strcmp(t->text, "String") || !strcmp(t->text, "Bytes")) && is_p(peek2(), "(")) || /* String(x) (#158) */
                     ((!strcmp(t->text, "Array") || !strcmp(t->text, "Dictionary") || !strcmp(t->text, "Set")) &&
                      (is_p(peek2(), "(") || is_p(peek2(), "<"))) || /* Array<T>(n) (#182) */
                     ((is_kw(t, "IO") || is_kw(t, "OS") || is_kw(t, "SYS")) && is_p(peek2(), ".")); /* IO.stdout... (#82, #94) */
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
    /* an owner an expression gives, unbound (O4): freed at once, or an
       error for a struct, unless it is the function's one expression,
       returned, which finish_drops decides when the body ends (#81) */
    Type *dt = value_type(s->expr);
    if (is_owner(dt) && !owner_place(s->expr)) {
        s->closed = true;
        s->name = !builtin_owner(dt) ? NULL
                  : is_bytes(dt)     ? "kv_bytes_discard"
                  : is_string(dt)    ? "kv_string_discard"
                  : is_io(dt)        ? "kv_io_discard"
                                     : strfmt("%s_discard", dt->cname);
        list_push(&pending_drops, s);
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
    int sr = spelled_receiver(i);
    if (sr >= 0)
        return is_p(&toks[sr + 2], "(") ? 5 : 6; /* enum{...}.name(), a method of a type with no tag (#121); an attribute */
    if ((t->kind == TK_IDENT || is_base_word(t)) && is_p(t + 1, ".") && (t[2].kind == TK_IDENT || is_kw(&t[2], "cstr")) &&
        is_p(t + 3, "("))
        return 1; /* T.cstr() defines a struct's text (#53) */
    if ((t->kind == TK_IDENT || is_base_word(t)) && is_p(t + 1, ".") && t[2].kind == TK_IDENT &&
        (is_p(t + 3, ":") || is_p(t + 3, "=")))
        return 6; /* T.x:R { }, an attribute (#131-#133) */
    if ((t->kind == TK_IDENT || t->kind == TK_KEYWORD) && is_p(t + 1, "[") && is_p(t + 2, "]") && is_p(t + 3, "("))
        return 7; /* T[](i:I):R { }, a subscript (#136) */
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

static Decl *parse_fn_tail(Decl *d, Token *name, Pos pos);
static Decl *parse_fn(Pos pos, const char *storage);

/* let f(...):R { ... } inside a function (#180): parsed as a function of
   the program, fenced from the locals around it as an anonymous function
   is, and emitted before and after the top-level declaration around it
   as one; bound by its name in the block, which function_named finds */
static Decl *parse_nested_fn(Pos pos) {
    Decl *outer = parsing_fn;
    int saved_start = params_start, saved_end = params_end, saved_anon = anon_start, saved_kind = anon_kind,
        saved_init = init_depth;
    bool saved_signature = in_signature, saved_assign = assign_ok, saved_brace = brace_ends_condition,
         saved_for = brace_in_for, saved_annotation = ident_annotation_ok, saved_body = stmt_is_body;
    assign_ok = brace_ends_condition = brace_in_for = stmt_is_body = in_signature = false;
    ident_annotation_ok = true;
    init_depth = 0;
    anon_kind = ANON_WRITTEN;
    anon_start = scope_names.len + 1; /* past its own name, which parse_fn binds here; its parameters follow */
    nested_outer = outer;
    Decl *d = parse_fn(pos, "static");
    nested_outer = NULL;
    if (!d->body)
        error_at(pos, "a function defined inside a function has a body: a prototype is written at the top level");
    params_start = saved_start;
    params_end = saved_end;
    anon_start = saved_anon;
    anon_kind = saved_kind;
    init_depth = saved_init;
    in_signature = saved_signature;
    assign_ok = saved_assign;
    brace_ends_condition = saved_brace;
    brace_in_for = saved_for;
    ident_annotation_ok = saved_annotation;
    stmt_is_body = saved_body;
    list_push(&anon_fns, d); /* declared before, and defined after, the top-level declaration around it */
    return d;
}

static Decl *parse_fn(Pos pos, const char *storage) {
    Decl *d = new_decl(D_FN, pos, storage);
    Token *name = peek();
    d->imported = name->imported;
    d->nested_in = nested_outer; /* (#180) */
    if (name->kind == TK_PUNCT) { /* +(a:T, b:U):R, an operator (#42) */
        d->op = advance()->text;
        d->name = strfmt("operator%s", d->op);
    } else {
        reject_kv_name(name);
        d->name = expect_ident("a function name");
    }
    if (!strcmp(d->name, "print") || !strcmp(d->name, "println"))
        error_at(name->pos, "'%s' is part of the Kelvin prelude and cannot be redefined", d->name);
    if (lib_mode && !strcmp(d->name, "main"))
        error_at(name->pos, "a library has no main: kelvinc --lib builds the file into libkM, for programs to import");
    Decl *wr;
    int wk;
    if (!d->op && anon_word(d->name, &wr, &wk)) /* (#120) */
        error_at(name->pos, "'%s' is a case of %s, a word of the program: name the function otherwise, or give the "
                            "enum a tag",
                 d->name, record_spelling(wr));
    return parse_fn_tail(d, name, pos);
}

/* the parameters, the result and the body of a function, after its name:
   a plain function's, an operator's, or a function of a type's (#111) */
static Decl *parse_fn_tail(Decl *d, Token *name, Pos pos) {
    if (!d->op)
        declare_name(d->name);
    d->bind_index = scope_names.len - 1; /* a nested function is found by its binding (#180) */
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
        if (void_result_ahead()) { /* :() is no result, written out (#141) */
            advance();
            advance();
        } else {
            d->ret = parse_type();
            if (typeof_names_local(d->ret))
                error_at(d->ret->pos, "the result type, %s, names a parameter, which C has not seen where it writes "
                                      "the result: write the type itself",
                         kelvin_type(d->ret));
        }
    }
    check_overload(d, name);
    list_push(&functions, d);
    /* a prototype ends with `;` or a new line (#35); a body is a block */
    if (!accept_p(";") && (is_p(peek(), "{") || !(newline_before() || peek()->kind == TK_EOF))) {
        Decl *outer = parsing_fn; /* NULL at the top level; the function around a nested one (#180) */
        parsing_fn = d;
        int drops_from = pending_drops.len;
        d->body = parse_fn_body(expect_p("{"));
        parsing_fn = outer;
        implicit_return(d);
        finish_drops(drops_from);
    }
    if (!d->body && in_kh(name->pos) && !(d->storage && !strcmp(d->storage, "extern")))
        d->kelvin_proto = true; /* the library's (#146); a C function's is extern let there */
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

static Decl *parse_method_of(Pos pos, const char *storage);

/* a method, with Self in scope as its receiver's type (#140) */
static Decl *parse_method(Pos pos, const char *storage) {
    bool saved_scope = self_scope;
    Token *saved_self = self_tok;
    Type *saved_self_sp = self_spelled;
    Decl *d = parse_method_of(pos, storage);
    self_scope = saved_scope;
    self_tok = saved_self;
    self_spelled = saved_self_sp;
    return d;
}

static Decl *parse_method_of(Pos pos, const char *storage) {
    Type *spelled = NULL;
    Token *recv = peek();
    if (in_extend) {
        /* extend T { let f() {} } (#130): T is the block's, not written */
        recv = ext_tok;
        spelled = ext_spelled;
        if (spelled && storage && !strcmp(storage, "static"))
            error_at(peek()->pos, "a function of a type is called by the type's name, and a type with no tag has "
                                  "none: write a method, or a function that takes it");
    } else if (spelled_receiver(cur) >= 0) {
        /* a method of a type with no tag, by its spelling (#121):
           let enum{none, some: i64}.orZero():i64 { ... } */
        if (storage && !strcmp(storage, "static"))
            error_at(recv->pos, "a function of a type is called by the type's name, and a type with no tag has none: "
                                "write a method, or a function that takes it");
        spelled = parse_type();
    } else {
        advance();
    }
    if (!in_extend)
        advance(); /* . */
    self_scope = true; /* Self is the receiver's type (#140) */
    self_tok = recv;
    self_spelled = spelled;
    if (!spelled)
        rewrite_self(cur, recv);
    Token *name = peek();
    if (storage && !strcmp(storage, "static")) {
        /* static let T.name(params):R { ... } (#111): a function of the
           type, Swift's static func, with no self, called as T.name(...);
           T a struct, union or enum with values of the program */
        bool builtin_owner_type = is_kw(recv, "Bytes") || is_kw(recv, "String"); /* Bytes.f(...) too (#168) */
        if (recv->kind == TK_KEYWORD && !builtin_owner_type)
            error_at(recv->pos, "a function of a type is declared on a struct, union or enum of the program, or on "
                                "Bytes or String: '%s' is built in",
                     recv->text);
        if (!builtin_owner_type && !record_named(recv->text))
            error_at(recv->pos, "'%s' is not a struct, union or enum declared before this function", recv->text);
        if (is_kw(name, "cstr"))
            error_at(name->pos, "'.cstr' is a method, the text of a value: write 'let %s.cstr():cstr'", recv->text);
        reject_kv_name(name);
        Decl *d = new_decl(D_FN, pos, NULL);
        d->imported = name->imported;
        d->type_fn = true;
        d->recv_name = recv->text;
        d->name = strfmt("%s.%s", recv->text, expect_ident("a function name"));
        return parse_fn_tail(d, name, pos);
    }
    Decl *d = new_decl(D_FN, pos, storage);
    reject_kv_name(name);
    /* T.cstr() defines a struct's or union's text (#53) */
    d->text_method = is_kw(name, "cstr");
    d->name = d->text_method ? advance()->text : expect_ident("a method name");
    d->recv_name = recv->text;
    if (spelled) {
        Decl *r = anon_record_of(spelled);
        d->recv_name = r->name; /* _kv_anonN, so the C name is _kv_anonN__name */
        d->recv = spelled;
    }
    if (!strcmp(d->name, "toString") || !strcmp(d->name, "fmt"))
        error_at(name->pos, "%s() " SHELVED_HINT, d->name);
    if (d->text_method && recv->kind == TK_KEYWORD && !spelled)
        error_at(name->pos, "a built-in type's text is fixed: '.cstr' may be defined for a struct or a union (#53)");
    if (spelled) {
        /* the receiver is the type of its spelling */
    } else if (recv->kind == TK_KEYWORD) {
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
    /* let T.x:R { ... } (#131): a computed attribute, read as v.x, no
       parentheses; its body has self, as a method's, which both read and
       never change (#137, #138) */
    d->attribute = !d->text_method && is_p(peek(), ":");
    declare_binding("self", d->recv, LET_PARAM);
    if (d->attribute)
        reject_attribute_member(d->recv, name);
    if (!d->attribute)
        expect_p("(");
    while (!d->attribute && !is_p(peek(), ")")) {
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
    if (!d->attribute)
        expect_p(")");
    params_end = scope_names.len;
    if (accept_p(":")) {
        if (void_result_ahead()) { /* :() (#141) */
            advance();
            advance();
            d->ret = NULL;
        } else
            d->ret = parse_type();
        if (typeof_names_local(d->ret))
            error_at(d->ret->pos, "the result type, %s, names a parameter, which C has not seen where it writes the "
                                  "result: write the type itself",
                     kelvin_type(d->ret));
    }
    if (d->attribute && !is_p(peek(), "{") && !in_kh(name->pos)) /* a prototype in M.kh (#146) */
        error_at(peek()->pos, "an attribute is computed by its body: write 'let %s.%s:%s { ... }'", d->recv_name,
                 d->name, kelvin_type(d->ret));
    list_push(&functions, d);
    /* a prototype ends with `;` or a new line (#35); a body is a block */
    if (!accept_p(";") && (is_p(peek(), "{") || !(newline_before() || peek()->kind == TK_EOF))) {
        parsing_fn = d;
        int drops_from = pending_drops.len;
        d->body = parse_fn_body(expect_p("{"));
        parsing_fn = NULL;
        if (d->text_method)
            check_text_method(d, name); /* before the body's last value is its result */
        implicit_return(d);
        finish_drops(drops_from);
    }
    if (d->text_method && !d->body && !in_kh(name->pos))
        error_at(name->pos, "'.cstr' of %s needs its body here: a prototype is not needed", d->recv_name);
    if (!d->body && in_kh(name->pos))
        d->kelvin_proto = true; /* the library's (#146) */
    close_scope();
    return d;
}

/* the receiver of an attribute (#131-#133): a struct, union or enum with
   values of the program, a built-in type, or one with no tag by its
   spelling; its name for the C names */
static Type *attribute_receiver(Token *recv, Type *spelled, char **recv_name) {
    if (spelled) {
        *recv_name = anon_record_of(spelled)->name;
        return spelled;
    }
    *recv_name = recv->text;
    if (recv->kind == TK_KEYWORD) {
        if (is_kw(recv, "any") || is_kw(recv, "_Complex") || is_kw(recv, "cstr"))
            error_at(recv->pos, "'%s' cannot have attributes", recv->text);
        if (is_kw(recv, "IO"))
            require_module("IO", recv->pos);
        return base_type(recv->text, recv->pos);
    }
    Decl *r = NULL;
    for (int i = records.len - 1; i >= 0 && !r; i--) {
        Decl *c = records.data[i];
        if (c->name && !strcmp(c->name, recv->text))
            r = c;
    }
    if (!r)
        error_at(recv->pos, "'%s' is not a struct, union or enum declared before this attribute", recv->text);
    if (r->kind == D_ENUM)
        error_at(recv->pos, "enums cannot have attributes: C cannot tell an enum from its integer type");
    return base_type(strfmt("%s %s", r->kind == D_STRUCT ? "struct" : "union", r->name), recv->pos);
}

/* an attribute named as a member of its struct is an error (#131): the
   member is stored, the attribute computed, and v.x would mean both */
static void reject_attribute_member(Type *recv, Token *name) {
    Decl *r;
    if (recv && type_class(recv, &r) == 's' && record_has_field(r, name->text))
        error_at(name->pos, "'%s' is a member of %s already: an attribute is computed, a member stored, so name the "
                            "attribute otherwise",
                 name->text, record_spelling(r));
}

/* the body of an attribute's getter or setter, self declared as a
   method's, and param, the setter's new value, if any */
static void attribute_body(Decl *d, Var *param) {
    open_scope();
    params_start = scope_names.len;
    declare_binding("self", d->recv, d->setter ? LET_NONE : LET_PARAM); /* a getter never changes self (#137) */
    if (param) {
        param->number = numeric_type(param_type(param->type));
        declare_binding(param->name, param_type(param->type), LET_PARAM);
        list_push(&d->params, param);
    }
    params_end = scope_names.len;
    list_push(&functions, d);
    parsing_fn = d;
    int drops_from = pending_drops.len;
    d->body = parse_fn_body(expect_p("{"));
    parsing_fn = NULL;
    implicit_return(d);
    finish_drops(drops_from);
    close_scope();
}

/* var T.x:R { get { ... } set(v) { ... } } (#132): a computed attribute
   with a setter, read as t.x, written as t.x = v on the var that holds t,
   whose self is that var; at the name, the receiver read */
static void parse_var_attribute(Program *prog, Pos pos, Token *recv, Type *spelled) {
    char *rname;
    Type *rt = attribute_receiver(recv, spelled, &rname);
    bool saved_scope = self_scope;
    Token *saved_self = self_tok;
    Type *saved_self_sp = self_spelled;
    self_scope = true; /* Self (#140) */
    self_tok = recv;
    self_spelled = spelled;
    if (!spelled)
        rewrite_self(cur, recv);
    Token *name = peek();
    reject_kv_name(name);
    reject_attribute_member(rt, name);
    char *nm = expect_ident("an attribute name");
    if (!is_p(peek(), ":"))
        error_at(peek()->pos, "a var attribute has a type, a getter and a setter: 'var %s.%s:R { get { ... } set(v) "
                              "{ ... } }'",
                 recv->text, nm);
    advance();
    Type *vt = parse_type();
    if (!is_p(peek(), "{") && in_kh(name->pos)) {
        /* var T.x:R in a module's header (#146): the getter's and the
           setter's prototypes */
        Decl *g = new_decl(D_FN, pos, NULL);
        g->imported = name->imported;
        g->recv = rt;
        g->recv_name = rname;
        g->name = nm;
        g->attribute = true;
        g->ret = vt;
        g->kelvin_proto = true;
        list_push(&functions, g);
        Decl *s = new_decl(D_FN, pos, NULL);
        s->imported = name->imported;
        s->recv = rt;
        s->recv_name = rname;
        s->name = nm;
        s->setter = true;
        s->kelvin_proto = true;
        Var *p = xcalloc(1, sizeof *p);
        p->pos = name->pos;
        p->name = "v";
        p->type = vt;
        p->is_let = true;
        p->number = numeric_type(param_type(p->type));
        list_push(&s->params, p);
        list_push(&functions, s);
        add_top_decl(prog, g);
        add_top_decl(prog, s);
        self_scope = saved_scope;
        self_tok = saved_self;
        self_spelled = saved_self_sp;
        return;
    }
    expect_p("{");
    if (!(peek()->kind == TK_IDENT && !strcmp(peek()->text, "get")))
        error_at(peek()->pos, "a var attribute starts with its getter, 'get { ... }', then its setter, 'set(v) { ... }'");
    advance();
    Decl *g = new_decl(D_FN, pos, NULL);
    g->imported = name->imported;
    g->recv = rt;
    g->recv_name = rname;
    g->name = nm;
    g->attribute = true;
    g->ret = vt;
    attribute_body(g, NULL);
    if (!(peek()->kind == TK_IDENT && !strcmp(peek()->text, "set")))
        error_at(peek()->pos, "after the getter comes the setter, 'set(v) { ... }', with v the new value; a let "
                              "attribute, 'let %s.%s:R { ... }', has none",
                 recv->text, nm);
    advance();
    expect_p("(");
    Token *vn = peek();
    reject_kv_name(vn);
    Var *p = xcalloc(1, sizeof *p);
    p->pos = vn->pos;
    p->name = expect_ident("the new value's name, as in 'set(v)'");
    p->type = vt;
    p->is_let = true;
    expect_p(")");
    Decl *s = new_decl(D_FN, pos, NULL);
    s->imported = name->imported;
    s->recv = rt;
    s->recv_name = rname;
    s->name = nm;
    s->setter = true;
    attribute_body(s, p);
    expect_p("}");
    add_top_decl(prog, g);
    add_top_decl(prog, s);    self_scope = saved_scope;
    self_tok = saved_self;
    self_spelled = saved_self_sp;

}

/* static let T.x:R = v and static var T.x = v (#133): a type attribute, a
   global read as T.x, named T__x in C; at the name, the receiver read */
static void parse_type_attribute(Program *prog, Pos pos, bool is_let, Token *recv, Type *spelled) {
    if (spelled)
        error_at(peek()->pos, "a type attribute is read by the type's name, as T.x, and a type with no tag has none");
    if (recv->kind == TK_KEYWORD && !is_converter(recv)) /* f64.pi (#148) */
        error_at(recv->pos, "a type attribute is of a struct, union or enum of the program, or of a number type: '%s' "
                            "has none",
                 recv->text);
    if (recv->kind != TK_KEYWORD && !record_named(recv->text))
        error_at(recv->pos, "'%s' is not a struct, union or enum declared before this attribute", recv->text);
    bool saved_scope = self_scope;
    Token *saved_self = self_tok;
    Type *saved_self_sp = self_spelled;
    self_scope = true; /* Self (#140) */
    self_tok = recv;
    self_spelled = NULL;
    rewrite_self(cur, recv);
    int before = scope_names.len;
    Var *v = parse_var(true, is_let ? LET_VALUE : LET_NONE); /* declares it, by its own name */
    v->is_let = is_let;
    bool declared = !v->init && in_kh(recv->pos); /* a library's, in its header (#146): extern in C */
    if (is_let && !v->init && !declared)
        error_at(v->pos, "a static let needs a value: write 'static let %s.%s = ...', or 'static var' if it changes",
                 recv->text, v->name);
    char *cn = strfmt("%s__%s", recv->text, v->name);
    for (int i = scope_names.len - 1; i >= before; i--)
        if (!strcmp(scope_names.data[i], v->name)) {
            scope_names.data[i] = cn;
            break;
        }
    v->name = cn;
    list_push(&type_attrs, cn);
    Decl *d = new_decl(D_VAR, pos, declared ? "extern" : NULL);
    list_push(&d->members, v);
    add_top_decl(prog, d);
    end_statement();    self_scope = saved_scope;
    self_tok = saved_self;
    self_spelled = saved_self_sp;

}

/* the items of a comma expression, v[r, c]'s indices (#136) */
static void flatten_commas(Expr *e, List *out) {
    if (e && e->kind == E_BINARY && !strcmp(e->op, ",")) {
        flatten_commas(e->a, out);
        flatten_commas(e->b, out);
        return;
    }
    if (e)
        list_push(out, e);
}

/* the subscript among name's overloads that the indices fit (#136): the
   one of their count, else the one their types match */
static Decl *choose_subscript(const char *name, List *args, Pos pos, const char *type) {
    List all = overloads_of(name, NULL), fit = {0};
    for (int i = 0; i < all.len; i++)
        if (((Decl *)all.data[i])->params.len == args->len + 1)
            list_push(&fit, all.data[i]);
    if (!fit.len)
        error_at(pos, "no subscript of %s takes %d ind%s", type, args->len, args->len == 1 ? "ex" : "ices");
    if (fit.len == 1)
        return fit.data[0];
    /* first a literal as the type it infers to, i64, f64 or cstr; then as
       any type of its kind */
    Decl *exact = NULL;
    int n = 0;
    for (int strict = 1; strict >= 0 && !n; strict--)
        for (int i = 0; i < fit.len; i++) {
            Decl *d = fit.data[i];
            bool same = true;
            for (int k = 0; same && k < args->len; k++) {
                Expr *a = args->data[k];
                Type *pt = unqualified(((Var *)d->params.data[k + 1])->type);
                Type *at = value_type(a);
                Decl *r;
                bool fl = a->text && strpbrk(a->text, ".eEpP") && strncmp(a->text, "0x", 2);
                if (at)
                    same = !strcmp(kelvin_type(unqualified(at)), kelvin_type(pt));
                else if (a->kind == E_STRING)
                    same = strict ? is_cstr(pt) : is_cstr(pt) || is_string(pt);
                else if (a->kind != E_LITERAL || !a->text || a->text[0] == '\'')
                    same = false;
                else if (strict)
                    same = !strcmp(kelvin_type(pt), fl ? "f64" : "i64");
                else
                    same = type_class(pt, &r) == (fl ? 'f' : 'i');
            }
            if (same)
                exact = d, n++;
        }
    if (n != 1)
        error_at(pos, "the indices fit %s subscript of %s: write their types, as in 'v[i as i64]'",
                 n ? "more than one" : "no", type);
    return exact;
}

/* let T[](i:I, ...):R { } and var T[](i:I, ...):R { get { } set(v) { } }
   (#136): a subscript, read as v[i], written as v[i] = y on the var that
   holds v. Each is a function of the type, T.[] and T.[]=, whose first
   parameter is _kv_selfp, a pointer to the receiver that self names, so
   overloads differ by the indices' types and nothing is moved; at the
   [, the receiver read */
static void parse_subscript(Program *prog, Pos pos, bool is_let, Token *recv, Type *spelled) {
    char *rname;
    Type *rt = attribute_receiver(recv, spelled, &rname);
    Decl *rec;
    if (rt->kind != T_BASE || type_class(rt, &rec) != 's')
        error_at(recv->pos, "a subscript is of a struct, a union or an enum with values of the program: '%s' has its "
                            "own indexing",
                 recv->text);
    Token *at = peek();
    expect_p("[");
    expect_p("]");
    bool saved_scope = self_scope;
    Token *saved_self = self_tok;
    Type *saved_self_sp = self_spelled;
    self_scope = true; /* Self (#140) */
    self_tok = recv;
    self_spelled = spelled;
    if (!spelled)
        rewrite_self(cur, recv);
    char *get = strfmt("%s.[]", rname), *set = strfmt("%s.[]=", rname);
    declare_name(get);
    declare_name(set);
    Decl *g = new_decl(D_FN, pos, NULL);
    g->imported = at->imported;
    g->type_fn = true;
    g->subscript = true;
    g->recv_name = rname;
    g->name = get;
    Type *cself = xcalloc(1, sizeof *cself); /* const T^, the getter's view of the receiver */
    cself->kind = T_PTR;
    cself->pos = at->pos;
    cself->elem = xcalloc(1, sizeof *cself->elem);
    *cself->elem = *rt;
    cself->elem->is_const = true;
    Var *sp = xcalloc(1, sizeof *sp);
    sp->pos = at->pos;
    sp->name = "_kv_selfp";
    sp->type = cself;
    sp->is_let = true;
    list_push(&g->params, sp);
    open_scope();
    params_start = scope_names.len;
    declare_binding("self", rt, LET_PARAM); /* a getter reads its receiver: self does not change */
    List indices = {0};
    expect_p("(");
    while (!is_p(peek(), ")")) {
        reject_c_fn_pointer(cur, "");
        Var *p = parse_var(false, LET_NONE);
        p->is_let = true;
        p->number = numeric_type(param_type(p->type));
        declare_binding(p->name, param_type(p->type), LET_PARAM);
        list_push(&g->params, p);
        list_push(&indices, p);
        if (!accept_p(","))
            break;
    }
    expect_p(")");
    if (!indices.len)
        error_at(at->pos, "a subscript takes at least one index, as in 'let [](i:i64):R { ... }'");
    params_end = scope_names.len;
    if (!accept_p(":"))
        error_at(peek()->pos, "a subscript gives a value: write its type, as in 'let [](i:i64):R { ... }'");
    g->ret = parse_type();
    check_overload(g, at);
    list_push(&functions, g);
    if (!is_p(peek(), "{") && in_kh(at->pos)) {
        /* let T[](i:I):R and var T[](i:I):R in a module's header (#146):
           the getter's prototype, and the setter's */
        g->kelvin_proto = true;
        close_scope();
        add_top_decl(prog, g);
        if (!is_let) {
            Decl *s = new_decl(D_FN, pos, NULL);
            s->imported = at->imported;
            s->type_fn = true;
            s->subscript = true;
            s->setter = true;
            s->recv_name = rname;
            s->name = set;
            s->kelvin_proto = true;
            Type *mself = xcalloc(1, sizeof *mself);
            mself->kind = T_PTR;
            mself->pos = at->pos;
            mself->elem = rt;
            Var *msp = xcalloc(1, sizeof *msp);
            *msp = *sp;
            msp->type = mself;
            list_push(&s->params, msp);
            for (int i = 0; i < indices.len; i++) {
                Var *p = xcalloc(1, sizeof *p);
                *p = *(Var *)indices.data[i];
                list_push(&s->params, p);
            }
            Var *v = xcalloc(1, sizeof *v);
            v->pos = at->pos;
            v->name = "v";
            v->type = g->ret;
            v->is_let = true;
            v->number = numeric_type(param_type(v->type));
            list_push(&s->params, v);
            check_overload(s, at);
            list_push(&functions, s);
            add_top_decl(prog, s);
        }
        self_scope = saved_scope;
        self_tok = saved_self;
        self_spelled = saved_self_sp;
        return;
    }
    if (!is_let) {
        expect_p("{");
        if (!(peek()->kind == TK_IDENT && !strcmp(peek()->text, "get")))
            error_at(peek()->pos, "a var subscript starts with its getter, 'get { ... }', then its setter, 'set(v) { ... }'");
        advance();
    }
    parsing_fn = g;
    int drops_from = pending_drops.len;
    g->body = parse_fn_body(expect_p("{"));
    parsing_fn = NULL;
    implicit_return(g);
    finish_drops(drops_from);
    close_scope();
    add_top_decl(prog, g);
    if (is_let)
    {
        self_scope = saved_scope;
        self_tok = saved_self;
        self_spelled = saved_self_sp;
        return;
    }
    if (!(peek()->kind == TK_IDENT && !strcmp(peek()->text, "set")))
        error_at(peek()->pos, "after the getter comes the setter, 'set(v) { ... }', with v the new value");
    advance();
    expect_p("(");
    Token *vn = peek();
    reject_kv_name(vn);
    char *vname = expect_ident("the new value's name, as in 'set(v)'");
    expect_p(")");
    Decl *s = new_decl(D_FN, pos, NULL);
    s->imported = at->imported;
    s->type_fn = true;
    s->subscript = true;
    s->setter = true;
    s->recv_name = rname;
    s->name = set;
    Type *mself = xcalloc(1, sizeof *mself); /* T^, the setter's: the caller's var */
    mself->kind = T_PTR;
    mself->pos = at->pos;
    mself->elem = rt;
    Var *msp = xcalloc(1, sizeof *msp);
    *msp = *sp;
    msp->type = mself;
    list_push(&s->params, msp);
    open_scope();
    params_start = scope_names.len;
    declare_binding("self", rt, LET_NONE); /* a setter changes the caller's var */
    for (int i = 0; i < indices.len; i++) {
        Var *p = xcalloc(1, sizeof *p);
        *p = *(Var *)indices.data[i];
        declare_binding(p->name, param_type(p->type), LET_PARAM);
        list_push(&s->params, p);
    }
    Var *v = xcalloc(1, sizeof *v);
    v->pos = vn->pos;
    v->name = vname;
    v->type = g->ret;
    v->is_let = true;
    v->number = numeric_type(param_type(v->type));
    declare_binding(vname, param_type(v->type), LET_PARAM);
    list_push(&s->params, v);
    params_end = scope_names.len;
    check_overload(s, vn);
    list_push(&functions, s);
    parsing_fn = s;
    drops_from = pending_drops.len;
    s->body = parse_fn_body(expect_p("{"));
    parsing_fn = NULL;
    finish_drops(drops_from);
    close_scope();
    expect_p("}");
    add_top_decl(prog, s);    self_scope = saved_scope;
    self_tok = saved_self;
    self_spelled = saved_self_sp;

}

/* Self is T from token i to the end of the declaration or the block
   there (#140): each token Self becomes T's, so that the lookaheads that
   tell a type from an expression, sizeof(Self), (Self){...}, see T. The
   span ends at the `}` that closes the group opened at or after i, at a
   `;` at the top, or at a new line there that starts a statement */
static void rewrite_self(int i, Token *recv) {
    int depth = 0, start = i;
    for (; toks[i].kind != TK_EOF && toks[i].kind != TK_FILE_END; i++) {
        Token *t = &toks[i];
        if (is_p(t, "(") || is_p(t, "[") || is_p(t, "{")) {
            depth++;
        } else if (is_p(t, ")") || is_p(t, "]") || is_p(t, "}")) {
            if (--depth < 0 || (depth == 0 && is_p(t, "}")))
                return;
        } else if (depth == 0 && is_p(t, ";")) {
            return;
        } else if (depth == 0 && i > start && line_break(t - 1, t) && !continues_expression(t)) {
            return;
        }
        if (t->kind == TK_IDENT && !strcmp(t->text, "Self")) {
            t->text = recv->text;
            t->kind = recv->kind;
        }
    }
}

/* typealias A = T (#149), Swift's: from here on, A is T wherever a name
   is read, as a type, before a dot, as a converter or an extend's: each
   later token A becomes T's, as Self becomes the receiver's (#140). T is
   a struct, a union or an enum with values of the program, or a built-in
   type; A is a new name */
static void parse_typealias(void) {
    Token *kw = advance();
    Token *name = peek();
    if (name->kind == TK_KEYWORD)
        error_at(name->pos, "'%s' is a type already: an alias is a new name, as in 'typealias real = f64'", name->text);
    if (name->kind != TK_IDENT)
        error_at(name->pos, "typealias names the alias, then its type: 'typealias A = T'");
    if (record_named(name->text) || binding_index(name->text) >= 0 || function_named(name->text))
        error_at(name->pos, "'%s' is declared already: an alias is a new name", name->text);
    advance();
    if (!accept_p("="))
        error_at(peek()->pos, "expected '=' after the alias's name: 'typealias %s = T'", name->text);
    Token *target = peek();
    bool base = is_base_word(target) && !is_kw(target, "any") && !is_kw(target, "_Complex");
    if (!base && !(target->kind == TK_IDENT && record_named(target->text)))
        error_at(target->pos, "'%s' is not a type kelvinc sees: an alias is of a struct, union or enum with values "
                              "declared before it, or of a built-in type",
                 target->text);
    advance();
    end_statement();
    for (int i = cur; toks[i].kind != TK_EOF; i++)
        if (toks[i].kind == TK_IDENT && !strcmp(toks[i].text, name->text)) {
            toks[i].text = target->text;
            toks[i].kind = target->kind;
        }
    (void)kw;
}

/* extend T { ... } (#130), Swift's extension: the members of T without
   writing T: let f() {} a method, static let f() {} a function of the
   type, let x:R {} a computed attribute, var x:R { get set } one with a
   setter, static let x = v and static var x = v type attributes */
static void parse_extend(Program *prog) {
    advance(); /* extend */
    Token *recv = peek();
    Type *spelled = NULL;
    if (is_p(recv, "{") || ((is_kw(recv, "enum") || is_kw(recv, "union") || is_kw(recv, "struct")) && is_p(peek2(), "{")))
        spelled = parse_type();
    else if (recv->kind == TK_IDENT || is_base_word(recv))
        advance();
    else
        error_at(recv->pos, "extend names the type it extends, as in 'extend point { ... }'");
    if (!spelled && recv->kind == TK_IDENT && !record_named(recv->text))
        error_at(recv->pos, "'%s' is not a struct, union or enum declared before this extend", recv->text);
    expect_p("{");
    bool saved = in_extend;
    Token *saved_tok = ext_tok;
    Type *saved_spelled = ext_spelled;
    in_extend = true;
    ext_tok = recv;
    ext_spelled = spelled;
    bool saved_scope = self_scope;
    Token *saved_self = self_tok;
    Type *saved_self_sp = self_spelled;
    self_scope = true; /* Self is T in the block (#140) */
    self_tok = recv;
    self_spelled = spelled;
    if (!spelled)
        rewrite_self(cur - 1, recv); /* from the { */
    char *rname = spelled ? anon_record_of(spelled)->name : recv->text;
    while (!is_p(peek(), "}")) {
        Token *m = peek();
        if (m->kind == TK_EOF || m->kind == TK_FILE_END)
            error_at(recv->pos, "extend has no closing '}'");
        stmt_start = cur;
        const char *storage = parse_storage();
        if (storage && !strcmp(storage, "extern"))
            error_at(m->pos, "extern is not for a member of extend: declare it at the top level");
        if (!is_kw(peek(), "let") && !is_kw(peek(), "var"))
            error_at(peek()->pos, "extend holds let f() { }, static let f() { }, let x:R { }, var x:R { get { } set(v) "
                                  "{ } }, static let x = v, static var x = v and static let +(a:T, b:T):T { }; found %s",
                     desc(peek()));
        bool is_let = is_kw(peek(), "let");
        Token *nm = peek_at(1), *after = peek_at(2);
        if (is_p(nm, "[") && is_p(after, "]")) {
            /* let [](i:I):R { } and var [](i:I):R { get set } (#136) */
            if (storage)
                error_at(m->pos, "a subscript has self, so it is not static: write '%s [](i:I):R { ... }'",
                         is_let ? "let" : "var");
            advance(); /* let or var */
            parse_subscript(prog, m->pos, is_let, recv, spelled);
            continue;
        }
        if (nm->kind == TK_PUNCT) {
            /* static let +(a:T, b:T):T { } (#135): an operator, as Swift's
               static func +, which is the top level's let + */
            if (!overloadable_op(nm) || !is_p(after, "("))
                error_at(nm->pos, "'%s' cannot be defined: an operator is one of + - * / %% == != < <= > >=, or unary -",
                         nm->text);
            if (!storage || !is_let)
                error_at(m->pos, "an operator in extend is a function of the type, as Swift's static func: write 'static "
                                 "let %s(a:%s, b:%s):%s { ... }'",
                         nm->text, recv->text, recv->text, recv->text);
            advance(); /* let */
            char *tn;
            Type *rt = attribute_receiver(recv, spelled, &tn);
            top_name = strfmt("%s_op", rname);
            Decl *d = parse_fn(m->pos, NULL);
            bool takes = false;
            for (int k = 0; k < d->params.len && !takes; k++) {
                Type *pt = unqualified(((Var *)d->params.data[k])->type);
                takes = pt && pt->kind == T_BASE && rt->kind == T_BASE && !strcmp(pt->name, rt->name);
            }
            if (!takes)
                error_at(nm->pos, "an operator in extend %s takes a %s, as one of its values", recv->text, recv->text);
            add_top_decl(prog, d);
            continue;
        }
        if (is_p(after, "(")) {
            if (!is_let)
                error_at(m->pos, "a method is a let: write 'let %s(...)'", nm->text);
            advance();
            top_name = strfmt("%s_%s", rname, nm->text);
            add_top_decl(prog, parse_method(m->pos, storage));
        } else if (storage) {
            advance();
            parse_type_attribute(prog, m->pos, is_let, recv, spelled);
        } else if (is_p(after, ":") && is_let) {
            advance();
            top_name = strfmt("%s_%s", rname, nm->text);
            add_top_decl(prog, parse_method(m->pos, NULL));
        } else if (is_p(after, ":")) {
            advance();
            top_name = strfmt("%s_%s", rname, nm->text);
            parse_var_attribute(prog, m->pos, recv, spelled);
        } else if (is_p(after, "=")) {
            error_at(after->pos, "an instance attribute is computed, 'let %s:R { ... }': a stored one is a member of the "
                                 "struct; a value of the type is 'static let %s = ...'",
                     nm->text, nm->text);
        } else {
            error_at(after->pos, "expected '(' for a method, or ':' for an attribute, after '%s'", nm->text);
        }
    }
    expect_p("}");
    in_extend = saved;
    ext_tok = saved_tok;
    ext_spelled = saved_spelled;
    self_scope = saved_scope;
    self_tok = saved_self;
    self_spelled = saved_self_sp;
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

/* T.n(x), T.none (#61), and a word of a top-level anonymous enum with
   values, n(x), none (#120): the value made, the case's value parsed */
static Expr *case_maker(Token *t, Token *cn, Decl *r, Var *c) {
    const char *how = r->spelling ? c->name : strfmt("%s.%s", r->name, c->name);
    Expr *e = new_expr(E_CALL, t->pos);
    e->a = new_expr(E_IDENT, t->pos);
    e->a->text = t->text;
    e->op = "case_make";
    e->text = c->name;
    e->target = r;
    e->type = base_type(tag_type_name(r), t->pos);
    if (c->type) {
        if (!is_p(peek(), "("))
            error_at(cn->pos, "case '%s' of %s carries a value: write %s(value)", c->name, record_spelling(r), how);
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
        error_at(peek()->pos, "case '%s' of %s carries no value: write %s", c->name, record_spelling(r), how);
    }
    return e;
}

static Decl *parse_record(Pos pos, DeclKind kind) {
    /* enum T { none; some: i32 }: a case with a value makes an enum with
       values, a tagged union, a struct in C (#61) */
    if (kind == D_ENUM && is_p(peek(), "{") && brace_has_colon(cur)) {
        /* enum { red; rgb: {r: u8, g: u8, b: u8} } with no tag at the top
           level (#120): the type of its spelling, as where a type goes, and
           its cases words of the program, red and rgb({1, 2, 3}), as C's
           anonymous enum declares its enumerators */
        Token *open = peek();
        Type *ty = parse_anon_record(D_STRUCT, true);
        Decl *r = anon_record_of(ty);
        for (int i = 0; i < r->members.len; i++) {
            Var *c = r->members.data[i];
            if (!strcmp(c->name, "ok") || !strcmp(c->name, "err") || !strcmp(c->name, "none") || !strcmp(c->name, "some"))
                error_at(c->pos, "'%s' is a word of Result and Optional (#72, #75): a case of an enum with no tag is a "
                                 "word of the program, so name it otherwise, or give the enum a tag",
                         c->name);
            if (function_named(c->name))
                error_at(c->pos, "'%s' is a function: a case of an enum with no tag is a word of the program, so name it "
                                 "otherwise, or give the enum a tag",
                         c->name);
            Decl *other;
            int k;
            if (anon_word(c->name, &other, &k) && other != r)
                error_at(c->pos, "'%s' is a case of %s already: a case of an enum with no tag is a word of the program",
                         c->name, record_spelling(other));
        }
        for (int i = 0; i < anon_words.len; i++)
            if (anon_words.data[i] == r)
                return NULL; /* the same spelling declared again: the same words */
        list_push(&anon_words, r);
        (void)open;
        return NULL;
    }
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
                Decl *wr;
                int wk;
                if (anon_word(v->name, &wr, &wk)) /* (#120) */
                    error_at(v->pos, "'%s' is a case of %s, a word of the program: name the enumerator otherwise",
                             v->name, record_spelling(wr));
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

/* {reader: IO, writer: IO}, what IO.pipe() gives (#87): an untagged
   struct, registered as one written in the program is */
/* an untagged struct from its spelling, "reader: IO, writer: IO",
   registered as one written in the program is, so that a Result may
   hold it and its derived functions free what it owns (#87, #95,
   #97, #102) */
static Type *anon_struct(Token *at, const char *spec) {
    char *spelling = strfmt("{%s}", spec);
    Decl *same = NULL;
    for (int i = 0; !same && i < anon_records.len; i++)
        if (!strcmp(((Decl *)anon_records.data[i])->spelling, spelling))
            same = anon_records.data[i];
    if (!same) {
        Decl *d = new_decl(D_STRUCT, at->pos, NULL);
        d->has_body = true;
        char *copy = xstrdup(spec);
        for (char *field = strtok(copy, ","); field; field = strtok(NULL, ",")) {
            while (*field == ' ')
                field++;
            char *colon = strchr(field, ':');
            *colon = '\0';
            char *type = colon + 1;
            while (*type == ' ')
                type++;
            Var *m = xcalloc(1, sizeof *m);
            m->name = xstrdup(field);
            m->pos = at->pos;
            m->type = base_type(type, at->pos);
            list_push(&d->members, m);
        }
        d->name = strfmt("_kv_anon%d", anon_records.len + 1);
        d->spelling = spelling;
        list_push(&anon_records, d);
        list_push(&records, d);
        list_push(&program->decls, d);
        same = d;
    }
    return base_type(tag_type_name(same), at->pos);
}

static Type *pipe_type(Token *at) { return anon_struct(at, "reader: IO, writer: IO"); }
static Type *temp_type(Token *at) { return anon_struct(at, "io: IO, path: String"); }

/* the structs OS's members give (#95, #102), by the member's gives */
static const char *struct_spec(const char *gives) {
    static const struct { const char *gives, *spec; } specs[] = {
        {"stat", "dev: i64, ino: i64, mode: i32, nlink: i64, uid: i32, gid: i32, size: i64, atime: f64, mtime: f64, "
                 "ctime: f64, isdir: bool, isfile: bool, islink: bool"},
        {"uname", "sysname: String, nodename: String, release: String, version: String, machine: String"},
        {"splitext", "root: String, ext: String"},
        {"loadavg", "one: f64, five: f64, fifteen: f64"},
        {"terminalsize", "columns: i64, lines: i64"},
        {"diskusage", "total: i64, used: i64, free: i64"},
    };
    for (size_t i = 0; i < sizeof specs / sizeof specs[0]; i++)
        if (!strcmp(gives, specs[i].gives))
            return specs[i].spec;
    return NULL;
}

static Type *stat_type(Token *at) { return anon_struct(at, struct_spec("stat")); }

static Decl *anon_record_of(Type *t) {
    if (!t || t->kind != T_BASE || !t->name)
        return NULL;
    const char *n = !strncmp(t->name, "struct _kv_anon", 15) || !strncmp(t->name, "struct _kv_opt_", 15) ||
                            !strncmp(t->name, "struct _kv_res_", 15)
                        ? t->name + 7
                    : !strncmp(t->name, "union _kv_anon", 14)                                              ? t->name + 6
                                                                                                                : NULL;
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
    set_no_eq(d);
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
        v = optional_of(string_of_literal(drop_cstr(v, t), t), t, v->pos); /* (#70, #72) */
    }
    return v;
}

/* ---------- Optional<T>, T? (#72): an enum with values, none and some ---------- */

/* A variant (#75): Result<T, U> is an enum with values with the cases
   ok: T and err: U, and Optional<T>, T?, is its special case, with the
   cases none and some: T. One record per spelling, made as a struct
   with no tag is (#59); kind is "res" or "opt". */
static void check_variant_part(Token *at, const char *what, Type *t) {
    if (t->kind == T_ARRAY)
        error_at(at->pos, "%s holds a value, and an array is none: hold an Array, $[%s]", what,
                 kelvin_type(t->elem));
    if (t->kind == T_FUNC)
        error_at(at->pos, "%s of a function type has no spelling yet", what);
}

/* Does a case's value of this type compare with == (#79)? Numbers,
   bools, pointers (a cstr by its address, as Kelvin compares it), a
   uchr, a String or a Bytes by its bytes, and an enum with values whose
   cases all do; not an array, a struct or union, an Array, a Dictionary
   or a Set. The first case that does not is the record's no_eq. */
static bool eq_type(Type *t) {
    if (!t || t->kind == T_PTR || t->kind == T_FUNC)
        return true;
    if (t->kind == T_ARRAY || t->cname || is_io(t))
        return false;
    if (is_string(t) || is_bytes(t) || is_uchr(t))
        return true;
    Decl *r = NULL;
    char c = type_class(t, &r);
    if (c == 's')
        return r && r->tagged && !r->no_eq;
    return c != 'c';
}

static void set_no_eq(Decl *d) {
    d->no_eq = NULL;
    for (int i = 0; i < d->members.len && !d->no_eq; i++)
        if (!eq_type(((Var *)d->members.data[i])->type))
            d->no_eq = ((Var *)d->members.data[i])->name;
}

static Type *variant_type(Token *at, const char *kind, Type *a, Type *b) {
    bool opt = !strcmp(kind, "opt");
    check_variant_part(at, opt ? "an Optional" : "a Result", a);
    if (b)
        check_variant_part(at, "a Result", b);
    bare_tags = true;
    char *spelling = opt ? strfmt("%s?", kelvin_type(unqualified(a)))
                         : strfmt("Result<%s, %s>", kelvin_type(unqualified(a)), kelvin_type(unqualified(b)));
    bare_tags = false;
    Decl *same = NULL;
    for (int i = 0; !same && i < anon_records.len; i++)
        if (!strcmp(((Decl *)anon_records.data[i])->spelling, spelling))
            same = anon_records.data[i];
    if (!same) {
        Decl *d = new_decl(D_STRUCT, at->pos, NULL);
        d->has_body = true;
        d->tagged = true;
        d->name = opt ? strfmt("_kv_opt_%s", mangled_type(a))
                      : strfmt("_kv_res_%s_%s", mangled_type(a), mangled_type(b));
        d->spelling = spelling;
        Var *first = xcalloc(1, sizeof *first), *second = xcalloc(1, sizeof *second);
        first->pos = second->pos = at->pos;
        if (opt) { /* none, some: T */
            first->name = "none";
            second->name = "some";
            second->type = unqualified(a);
        } else { /* ok: T, err: U */
            first->name = "ok";
            first->type = unqualified(a);
            second->name = "err";
            second->type = unqualified(b);
        }
        list_push(&d->members, first);
        list_push(&d->members, second);
        set_no_eq(d);
        list_push(&anon_records, d);
        list_push(&records, d);
        list_push(&program->decls, d);
        same = d;
    }
    return base_type(tag_type_name(same), at->pos);
}

static Type *optional_type(Token *at, Type *inner) { return variant_type(at, "opt", inner, NULL); }

/* the record of t, if t is an Optional or a Result */
static Decl *variant_record(Type *t) {
    Decl *r = tagged_record(t);
    return r && r->name && (!strncmp(r->name, "_kv_opt_", 8) || !strncmp(r->name, "_kv_res_", 8)) ? r : NULL;
}

static Decl *optional_record(Type *t) {
    Decl *r = variant_record(t);
    return r && !strncmp(r->name, "_kv_opt_", 8) ? r : NULL;
}

/* the case that holds the value: some of an Optional, ok of a Result */
static int value_case(Decl *r) { return !strncmp(r->name, "_kv_opt_", 8) ? 1 : 0; }

static Type *parse_result_type(Token *kw) {
    if (!accept_p("<"))
        error_at(peek()->pos, "a Result names its types: Result<T, U>, ok: T or err: U");
    Type *t = parse_type_in(TYPE_DECL);
    if (!accept_p(","))
        error_at(peek()->pos, "expected ',' between the types of Result<T, U>");
    Type *u = parse_type_in(TYPE_DECL);
    if (is_p(peek(), ">>"))
        toks[cur].text = ">";
    else if (!accept_p(">"))
        error_at(peek()->pos, "expected '>' after the types of Result<T, U>");
    return variant_type(kw, "res", t, u);
}

/* Optional<T>.some(v), Optional<T>.none, Result<T, U>.ok(v), Result<T, U>.err(e)
   (#75), and Optional<T>(v), Optional<T>(), Result<T, U>(v) for the value */
static Expr *variant_constructor(Token *t, Type *vt) {
    Decl *r = variant_record(vt);
    Var *c = NULL;
    int k = 0;
    bool saved_brace = brace_ends_condition, saved_for = brace_in_for;
    brace_ends_condition = brace_in_for = false;
    if (accept_p(".")) {
        Token *cn = peek();
        char *name = expect_ident("a case name");
        c = case_named(r, name, &k);
        if (!c)
            error_at(cn->pos, "%s has no case '%s': the cases are %s", r->spelling, name, case_list(r));
    } else {
        if (!is_p(peek(), "("))
            error_at(peek()->pos, "%s is a type: make one with %s(v), %s.%s(v), or write it after ':'", r->spelling,
                     r->spelling, r->spelling, ((Var *)r->members.data[value_case(r)])->name);
        k = value_case(r);
        c = r->members.data[k];
    }
    Expr *e = new_expr(E_CALL, t->pos);
    e->a = new_expr(E_IDENT, t->pos);
    e->a->text = r->spelling;
    e->op = "case_make";
    e->text = c->name;
    e->target = r;
    e->type = vt;
    if (is_p(peek(), "(")) {
        advance();
        Expr *v = NULL;
        if (!is_p(peek(), ")"))
            v = case_value(c->type ? c->type : NULL);
        expect_p(")");
        if (!c->type && v)
            error_at(v->pos, "case '%s' of %s carries no value", c->name, r->spelling);
        if (c->type && !v) { /* Optional<T>() is none */
            if (!optional_record(vt))
                error_at(t->pos, "case '%s' of %s carries a value: write %s.%s(v)", c->name, r->spelling, r->spelling,
                         c->name);
            e->text = "none";
        } else if (v) {
            reject_record_mismatch(v, c->type, v->pos);
            move_argument(v, c->type, strfmt("case '%s'", c->name));
            list_push(&e->items, v);
        }
    } else if (c->type) {
        error_at(peek()->pos, "case '%s' of %s carries a value: write %s.%s(v)", c->name, r->spelling, r->spelling,
                 c->name);
    }
    brace_ends_condition = saved_brace;
    brace_in_for = saved_for;
    return e;
}

static Type *parse_optional_type(Token *kw) {
    if (!accept_p("<"))
        error_at(peek()->pos, "an Optional names its type: Optional<T>, or T?");
    Type *inner = parse_type_in(TYPE_DECL);
    if (is_p(peek(), ">>"))
        toks[cur].text = ">";
    else if (!accept_p(">"))
        error_at(peek()->pos, "expected '>' after the type of Optional<T>");
    return optional_type(kw, inner);
}

/* a value where a T? is expected (#72): none, the T? itself, or a T,
   which becomes some(T); an owner moves in, as a case's value does */
static Expr *optional_of(Expr *v, Type *target, Pos pos) {
    Decl *r = target ? variant_record(target) : NULL;
    if (!r)
        return v;
    Type *vt = value_type(v);
    if (vt && vt->kind == T_BASE && !strcmp(vt->name, tag_type_name(r)))
        return v; /* a T? or a Result already */
    if (v->kind == E_TERNARY && !(v->op && !strcmp(v->op, "coalesce"))) {
        /* c ? a : b where a T? or a Result is expected (#116): each arm is
           wrapped on its own, so that c ? v : none and c ? ok(v) : err(e)
           are what return and a declaration take */
        v->b = optional_of(v->b, target, v->b->pos);
        v->c = optional_of(v->c, target, v->c->pos);
        return v;
    }
    Expr *e = new_expr(E_CALL, pos);
    e->a = new_expr(E_IDENT, pos);
    e->a->text = r->spelling;
    e->op = "case_make";
    e->target = r;
    e->type = base_type(tag_type_name(r), pos);
    if (optional_record(target) && v->kind == E_IDENT && !strcmp(v->text, "none") && binding_index("none") < 0) {
        e->text = "none";
        return e;
    }
    if (optional_record(target) && v->kind == E_CALL && v->op && !strcmp(v->op, "word"))
        error_at(pos, "an Optional has no case '%s': its cases are none and some; a Result has ok and err",
                 v->a->text);
    if (!optional_record(target) && v->kind == E_IDENT && !strcmp(v->text, "none") && binding_index("none") < 0)
        error_at(pos, "a Result has no case 'none': write err(e), or ok(v)");
    if (!optional_record(target) && v->kind == E_CALL && v->op && !strcmp(v->op, "word")) {
        /* ok(v) and err(e) where a Result is expected (#75): words, as none is */
        int k;
        Var *c = case_named(r, v->a->text, &k);
        Expr *x = v->items.data[0];
        pick_overload(x, c->type);
        x = optional_of(string_of_literal(drop_cstr(x, c->type), c->type), c->type, pos);
        reject_record_mismatch(x, c->type, pos);
        move_argument(x, c->type, strfmt("case '%s'", c->name));
        e->text = c->name;
        list_push(&e->items, x);
        return e;
    }
    Var *some = r->members.data[value_case(r)];
    pick_overload(v, some->type);
    v = string_of_literal(drop_cstr(v, some->type), some->type);
    v = optional_of(v, some->type, pos); /* a T?? takes a T too */
    reject_record_mismatch(v, some->type, pos);
    move_argument(v, some->type, strfmt("'%s'", some->name));
    e->text = some->name;
    list_push(&e->items, v);
    return e;
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
        list_push(&proto_copies, proto); /* named with its original, later (#180) */
        list_push(&proto_copies, anon_fns.data[i]);
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
    proto_copies = (List){0};
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
        if (depth == 0 && toks[i].kind == TK_IDENT && !strcmp(toks[i].text, "extend")) {
            /* extend T { let f() {} } (#130): f is a method name, as T.f( is */
            int k = i + 1;
            if (is_p(&toks[k], "{"))
                k = skip_nested(k);
            else if ((is_kw(&toks[k], "enum") || is_kw(&toks[k], "union") || is_kw(&toks[k], "struct")) &&
                     is_p(&toks[k + 1], "{"))
                k = skip_nested(k + 1);
            else
                k++;
            if (is_p(&toks[k], "{"))
                for (int j = k + 1, d = 1; d > 0 && toks[j].kind != TK_EOF; j++) {
                    if (is_p(&toks[j], "{"))
                        d++;
                    else if (is_p(&toks[j], "}"))
                        d--;
                    else if (d == 1 && is_kw(&toks[j], "let") && toks[j + 1].kind == TK_IDENT && is_p(&toks[j + 2], "(") &&
                             !(j > 0 && is_kw(&toks[j - 1], "static")))
                        list_push(&method_names, toks[j + 1].text);
                }
        }
        if (is_p(&toks[i], "{"))
            depth++;
        else if (is_p(&toks[i], "}")) {
            depth--;
            if (depth == 0 && is_p(&toks[i + 1], ".") && toks[i + 2].kind == TK_IDENT && is_p(&toks[i + 3], "("))
                list_push(&method_names, toks[i + 2].text); /* enum{...}.name(, a method of a type with no tag (#121) */
        } else if (depth == 0 && (toks[i].kind == TK_IDENT || is_base_word(&toks[i])) && is_p(&toks[i + 1], ".") &&
                 toks[i + 2].kind == TK_IDENT && is_p(&toks[i + 3], "(") &&
                 !(i >= 2 && is_kw(&toks[i - 1], "let") && is_kw(&toks[i - 2], "static")))
            list_push(&method_names, toks[i + 2].text); /* not static let T.name(, a function of the type (#111) */
    }
    Program *prog = xcalloc(1, sizeof *prog);
    program = prog;
    while (peek()->kind != TK_EOF) {
        Token *t = peek();
        if (t->kind == TK_IMPORT_K) { /* where an imported file begins (#40): the module is in from here (#143) */
            char *name = xstrndup(t->text + 1, strlen(t->text) - 2);
            const char *slash = strrchr(name, '/');
            if (slash)
                name = (char *)slash + 1;
            if (strrchr(name, '.'))
                *strrchr(name, '.') = 0;
            list_push(&modules_imported, name);
            advance();
            continue;
        }
        if (t->kind == TK_FILE_END) { /* where an imported file ends (#40) */
            advance();
            continue;
        }
        if (t->kind == TK_IMPORT) {
            Decl *d = new_decl(D_IMPORT, t->pos, NULL);
            d->name = advance()->text;
            list_push(&prog->decls, d);
            continue;
        }
        if (t->kind == TK_INLINE_C) { /* C of the program's own (#197), written where it stands */
            Decl *d = new_decl(D_INLINE_C, t->pos, NULL);
            d->name = advance()->text;
            list_push(&prog->decls, d);
            continue;
        }
        stmt_start = cur;
        top_name = NULL;
        const char *storage = parse_storage();
        /* a function, a method and an operator are lets (#45) */
        bool binding = is_kw(peek(), "let") || is_kw(peek(), "var");
        if (!binding && !storage && peek()->kind == TK_IDENT && !strcmp(peek()->text, "typealias")) {
            parse_typealias(); /* typealias A = T (#149) */
            continue;
        }
        if (!binding && !storage && peek()->kind == TK_IDENT && !strcmp(peek()->text, "extend") &&
            (peek2()->kind == TK_IDENT || is_base_word(peek2()) || is_p(peek2(), "{") || is_kw(peek2(), "enum") ||
             is_kw(peek2(), "union") || is_kw(peek2(), "struct"))) {
            parse_extend(prog); /* extend T { ... } (#130) */
            continue;
        }
        int shape = function_shape(cur + binding);
        if (shape == 7) {
            /* let T[](i:I):R { } and var T[](i:I):R { get set } (#136) */
            if (!binding)
                error_at(peek()->pos, "a subscript is declared with let or var, as 'let %s[](i:I):R { ... }'", peek()->text);
            if (storage)
                error_at(t->pos, "a subscript has self, so it is not %s", storage);
            bool is_let = is_kw(advance(), "let");
            Token *recv = advance();
            parse_subscript(prog, t->pos, is_let, recv, NULL);
            continue;
        }
        if (shape == 6) {
            /* let T.x:R { }, var T.x:R { get set }, static let T.x = v (#131-#133) */
            if (!binding)
                error_at(peek()->pos, "an attribute is declared with let or var, as 'let %s.x:R { ... }'", peek()->text);
            bool is_let = is_kw(advance(), "let");
            Token *recv = peek();
            Type *spelled = NULL;
            if (spelled_receiver(cur) >= 0)
                spelled = parse_type();
            else
                advance();
            expect_p(".");
            Token *nm = peek(), *after = peek2();
            if (storage && !strcmp(storage, "static")) {
                parse_type_attribute(prog, t->pos, is_let, recv, spelled);
            } else if (storage) {
                error_at(t->pos, "extern is not for an attribute");
            } else if (is_p(after, "=")) {
                error_at(after->pos, "an instance attribute is computed, 'let %s.%s:R { ... }': a stored one is a member "
                                     "of the struct; a value of the type is 'static let %s.%s = ...'",
                         recv->text, nm->text, recv->text, nm->text);
            } else if (is_let) {
                bool saved = in_extend;
                Token *saved_tok = ext_tok;
                Type *saved_spelled = ext_spelled;
                in_extend = true; /* parse_method then names no receiver: it is read */
                ext_tok = recv;
                ext_spelled = spelled;
                top_name = strfmt("%s_%s", recv->text, nm->text);
                add_top_decl(prog, parse_method(t->pos, NULL));
                in_extend = saved;
                ext_tok = saved_tok;
                ext_spelled = saved_spelled;
            } else {
                top_name = strfmt("%s_%s", recv->text, nm->text);
                parse_var_attribute(prog, t->pos, recv, spelled);
            }
            continue;
        }
        if (shape && shape != 4) {
            if (shape == 2)
                reject_c_fn_pointer(cur + binding, "var ");
            Token *n = &toks[cur + binding];
            char *how = shape == 5 ? strfmt("%s%slet %s{...}.%s(...)", storage ? storage : "", storage ? " " : "",
                                            is_p(n, "{") ? "" : n->text, toks[spelled_receiver(cur + binding) + 1].text)
                                   : strfmt("%s%slet %s%s%s(...)", storage ? storage : "", storage ? " " : "", n->text,
                                            shape == 1 ? "." : "", shape == 1 ? n[2].text : "");
            if (!binding && shape != 5 && !params_ahead(cur + (shape == 1 ? 3 : 1)))
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
        if (spelled_receiver(cur) >= 0) { /* enum{...}.name(...), a method of a type with no tag (#121) */
            top_name = strfmt("anon_%s", toks[spelled_receiver(cur) + 1].text);
            add_top_decl(prog, parse_method(t->pos, storage));
        } else if ((peek()->kind == TK_IDENT || is_base_word(peek())) && is_p(peek2(), ".") &&
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
                Var *v = d->members.data[d->members.len - 1];
                if (v->init && is_owner(v->type)) /* a global owner (#178): C initializes a global with a constant alone */
                    error_at(v->init->pos,
                             "'%s' is a global %s, which C initializes with a constant alone, and an owner is made by a "
                             "call: declare it with its type, 'var %s:%s', and give it its value in main or another "
                             "function",
                             v->name, kelvin_type(v->type), v->name, kelvin_type(v->type));
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
            Decl *d = parse_record(t->pos, D_ENUM);
            if (d) /* NULL: an enum with values and no tag, registered as a type and its words (#120) */
                add_top_decl(prog, d);
        } else {
            error_at(peek()->pos, "expected a declaration (let name(...):type, let or var name, struct, union, enum), found %s", desc(peek()));
        }
    }
    name_functions();
    prog->modules = modules_imported; /* for the codegen (#143) */
    return prog;
}

/* ---------- kelvinc --lib: the module's header, M.kh (#146) ---------- */

/* the matching close of the group that opens at token i */
static int group_end(int i) {
    int depth = 0;
    for (; toks[i].kind != TK_EOF; i++) {
        if (is_p(&toks[i], "(") || is_p(&toks[i], "[") || is_p(&toks[i], "{"))
            depth++;
        else if ((is_p(&toks[i], ")") || is_p(&toks[i], "]") || is_p(&toks[i], "}")) && --depth == 0)
            return i;
    }
    return i;
}

/* Where the header of the declaration at token i ends, and what follows:
   'b' a body { } at token *end, 't' a type attribute's = at *end, 'p' a
   prototype, ending before *end. A { after a : or a struct, union or enum
   word is a type, skipped as a group */
static char header_end(int i, int *end) {
    int k = i;
    for (;; k++) {
        Token *t = &toks[k];
        if (t->kind == TK_EOF || t->kind == TK_FILE_END || (k > i && is_p(t, ";")) ||
            (k > i && t->pos.line > toks[k - 1].pos.line && !continues_expression(t))) {
            *end = k;
            return 'p';
        }
        if (is_p(t, "(") || is_p(t, "[")) {
            k = group_end(k);
            continue;
        }
        if (is_p(t, "{")) {
            Token *b = &toks[k - 1];
            if (is_p(b, ":") || is_kw(b, "struct") || is_kw(b, "union") || is_kw(b, "enum") || is_p(b, "$")) {
                k = group_end(k);
                continue;
            }
            *end = k;
            return 'b';
        }
        if (is_p(t, "=") || is_p(t, ":=")) {
            *end = k;
            return 't';
        }
    }
}

/* the end of the statement at token i: past its body, its initializer or
   its prototype */
static int decl_end(int i) {
    int end;
    char how = header_end(i, &end);
    if (how == 'b')
        return group_end(end) + 1;
    if (how == 'p')
        return end;
    for (int k = end;; k++) { /* an initializer, to the end of its line */
        Token *t = &toks[k];
        if (t->kind == TK_EOF || t->kind == TK_FILE_END || is_p(t, ";"))
            return k;
        if (is_p(t, "(") || is_p(t, "[") || is_p(t, "{")) {
            k = group_end(k);
            continue;
        }
        if (k > end && t->pos.line > toks[k - 1].pos.line && !continues_expression(t))
            return k;
    }
}

/* the source text of tokens i to end as written, templates, comments and
   lines included, for a header that reads as the source does */
static long offset_of(const char *src, Pos p) {
    const char *s = src;
    for (int line = 1; line < p.line && *s; s++)
        if (*s == '\n')
            line++;
    for (int col = 1; col < p.col && *s && *s != '\n'; s++)
        col++;
    return s - src;
}

static char *raw_text(int i, int end) {
    const char *src = source_text_of(toks[i].pos.file);
    if (!src || end <= i)
        return source_text(i, end);
    long a = offset_of(src, toks[i].pos), z = offset_of(src, toks[end - 1].pos);
    Token *last = &toks[end - 1];
    if (last->kind == TK_IDENT || last->kind == TK_KEYWORD) /* as written: Self was rewritten to T (#140) */
        while (isalnum((unsigned char)src[z]) || src[z] == '_')
            z++;
    else
        z += (long)strlen(last->text);
    return xstrndup(src + a, (size_t)(z - a));
}

/* the declaration of the type attribute at token i for a header (#148):
   static let T.x:R alone, or static let x:R in its extend block, with
   the type kelvinc saw; the library defines it */
static char *type_attribute_decl(Program *prog, int i, bool alone) {
    for (int j = 0; j < prog->decls.len; j++) {
        Decl *d = prog->decls.data[j];
        if (d->kind != D_VAR || d->members.len != 1 || d->pos.line != toks[i].pos.line ||
            strcmp(d->pos.file, toks[i].pos.file))
            continue;
        Var *v = d->members.data[0];
        const char *sep = strstr(v->name, "__");
        if (!sep)
            continue;
        return strfmt("static %s %.*s%s%s:%s", v->is_let ? "let" : "var", alone ? (int)(sep - v->name) : 0, v->name,
                      alone ? "." : "", sep + 2, kelvin_type(v->type));
    }
    error_at(toks[i].pos, "a type attribute in a library: its declaration was not found");
}

static bool text_listed(List *l, const char *text) {
    for (int i = 0; i < l->len; i++)
        if (!strcmp(l->data[i], text))
            return true;
    return false;
}

/* Is the declaration at token i a function's, a method's, an operator's,
   an attribute's or a subscript's, after let, var, static let or static
   var? A global's otherwise */
static bool fn_like(int i) {
    Token *t = &toks[i];
    if (t->kind == TK_PUNCT && !is_p(t, "{") && !is_p(t, "$"))
        return true; /* an operator */
    if (is_p(t, "{") || is_kw(t, "enum") || is_kw(t, "struct") || is_kw(t, "union"))
        return true; /* a type with no tag's member, by its spelling (#121) */
    if (is_p(&toks[i + 1], "("))
        return true;
    if (is_p(&toks[i + 1], ".") && (is_p(&toks[i + 3], "(") || is_p(&toks[i + 3], ":")))
        return true;
    if (is_p(&toks[i + 1], "[") && is_p(&toks[i + 2], "]"))
        return true;
    return false;
}

/* ---------- the declarations of #inline C, for a module's .kh (#199) ---------- */

/* the C with its comments made blanks, its strings and characters kept */
static char *c_uncommented(const char *c) {
    Buf b = {0};
    for (const char *p = c; *p;) {
        if (p[0] == '/' && p[1] == '/') {
            while (*p && *p != '\n')
                p++;
        } else if (p[0] == '/' && p[1] == '*') {
            p += 2;
            while (*p && !(p[0] == '*' && p[1] == '/'))
                p++;
            p += *p ? 2 : 0;
            buf_puts(&b, " ");
        } else if (*p == '"' || *p == '\'') {
            const char *q = p + 1;
            while (*q && *q != *p && *q != '\n')
                q += q[0] == '\\' && q[1] ? 2 : 1;
            q += *q == *p;
            buf_putn(&b, p, (size_t)(q - p));
            p = q;
        } else {
            buf_putn(&b, p++, 1);
        }
    }
    return b.buf ? b.buf : xstrdup("");
}

/* past a string or a character at p, else p */
static const char *c_past_quote(const char *p) {
    if (*p != '"' && *p != '\'')
        return p;
    const char *q = p + 1;
    while (*q && *q != *p && *q != '\n')
        q += q[0] == '\\' && q[1] ? 2 : 1;
    return q + (*q == *p);
}

/* is the word w among the words of s[0..n) at depth 0 before a '(', '[', '{' or '=' */
static bool c_specifier(const char *s, size_t n, const char *w) {
    size_t wn = strlen(w);
    for (size_t i = 0; i < n; i++) {
        if (strchr("([{=", s[i]))
            return false;
        if ((i == 0 || !(isalnum((unsigned char)s[i - 1]) || s[i - 1] == '_')) && i + wn <= n &&
            !strncmp(s + i, w, wn) && (i + wn == n || !(isalnum((unsigned char)s[i + wn]) || s[i + wn] == '_')))
            return true;
    }
    return false;
}

static bool c_starts(const char *s, const char *w) {
    size_t n = strlen(w);
    return !strncmp(s, w, n) && !(isalnum((unsigned char)s[n]) || s[n] == '_');
}

/* one declaration of the C, s[0..n) with its ';' dropped, as a header has it */
static void c_declaration(Buf *out, const char *s, size_t n) {
    while (n && isspace((unsigned char)*s))
        s++, n--;
    while (n && isspace((unsigned char)s[n - 1]))
        n--;
    if (!n || c_specifier(s, n, "static") || c_specifier(s, n, "inline"))
        return; /* the file's own */
    char *d = xstrndup(s, n);
    bool tagged = c_starts(d, "struct") || c_starts(d, "union") || c_starts(d, "enum");
    if (c_starts(d, "typedef") || c_starts(d, "extern") || c_starts(d, "_Static_assert")) {
        buf_printf(out, "%s;\n", d);
        return;
    }
    if (tagged) { /* a type, unless a declarator follows it */
        const char *brace = strchr(d, '{'), *after = NULL;
        if (brace) {
            int depth = 0;
            for (const char *p = brace; *p; p = c_past_quote(p) == p ? p + 1 : c_past_quote(p)) {
                depth += (*p == '{') - (*p == '}');
                if (!depth) {
                    after = p + 1;
                    break;
                }
            }
        } else {
            after = d;
            while (*after && !isspace((unsigned char)*after))
                after++;
            while (isspace((unsigned char)*after))
                after++;
            while (*after && (isalnum((unsigned char)*after) || *after == '_'))
                after++;
        }
        while (after && isspace((unsigned char)*after))
            after++;
        if (after && !*after) {
            buf_printf(out, "%s;\n", d);
            return;
        }
    }
    /* a variable or a prototype: extern, without its initializers */
    buf_puts(out, "extern ");
    int depth = 0;
    for (const char *p = d; *p;) {
        const char *q = c_past_quote(p);
        if (q != p) {
            buf_putn(out, p, (size_t)(q - p));
            p = q;
            continue;
        }
        if (*p == '=' && !depth) {
            while (*p && !(*p == ',' && !depth)) {
                q = c_past_quote(p);
                if (q != p) {
                    p = q;
                    continue;
                }
                depth += (*p == '(' || *p == '[' || *p == '{') - (*p == ')' || *p == ']' || *p == '}');
                p++;
            }
            while (out->len && out->buf[out->len - 1] == ' ')
                out->buf[--out->len] = 0;
            continue;
        }
        depth += (*p == '(' || *p == '[' || *p == '{') - (*p == ')' || *p == ']' || *p == '}');
        buf_putn(out, p++, 1);
    }
    buf_puts(out, ";\n");
}

/* The declarations of an #inline C at the top level, for a module's .kh:
   its preprocessor lines; a function's prototype, its body dropped; a
   type; a global, extern, its initializer dropped; nothing of what is
   static or inline, which is the file's own; "" where nothing is left */
static char *c_declarations(const char *text) {
    char *c = c_uncommented(text);
    Buf out = {0};
    const char *item = NULL;
    int depth = 0;
    bool line_start = true;
    for (const char *p = c; *p;) {
        if (*p == '\n') {
            line_start = true;
            p++;
            continue;
        }
        if (line_start && isspace((unsigned char)*p)) {
            p++;
            continue;
        }
        if (line_start && *p == '#' && !depth) { /* a directive, with its continued lines */
            const char *q = p;
            while (*q && !(*q == '\n' && q[-1] != '\\'))
                q++;
            const char *e = q;
            while (e > p && (e[-1] == ' ' || e[-1] == '\t')) /* where a comment was */
                e--;
            buf_putn(&out, p, (size_t)(e - p));
            buf_puts(&out, "\n");
            p = q;
            continue;
        }
        line_start = false;
        if (!item && isspace((unsigned char)*p)) {
            p++;
            continue;
        }
        if (!item)
            item = p;
        const char *q = c_past_quote(p);
        if (q != p) {
            p = q;
            continue;
        }
        if (*p == '{' && !depth) {
            const char *b = p;
            while (b > item && isspace((unsigned char)b[-1]))
                b--;
            if (b > item && b[-1] == ')') { /* a function's body: its prototype */
                if (!c_specifier(item, (size_t)(b - item), "static") && !c_specifier(item, (size_t)(b - item), "inline"))
                    buf_printf(&out, "%.*s;\n", (int)(b - item), item);
                int d = 0;
                for (;;) {
                    if (!*p)
                        break;
                    q = c_past_quote(p);
                    if (q != p) {
                        p = q;
                        continue;
                    }
                    d += (*p == '{') - (*p == '}');
                    p++;
                    if (!d)
                        break;
                }
                item = NULL;
                continue;
            }
        }
        depth += (*p == '(' || *p == '[' || *p == '{') - (*p == ')' || *p == ']' || *p == '}');
        if (*p == ';' && !depth) {
            c_declaration(&out, item, (size_t)(p - item));
            item = NULL;
        }
        p++;
    }
    return out.buf ? out.buf : xstrdup("");
}

char *gen_header(Program *prog) {
    const char *file = toks[0].pos.file;
    Buf b = {0};
    buf_puts(&b, "");
    List seen = {0}, defined = {0};
    /* the headers of the functions defined here, so that a prototype of
       one is Kelvin's own and any other a C function's */
    for (int i = 0; toks[i].kind != TK_EOF;) {
        if (strcmp(toks[i].pos.file, file)) {
            i++;
            continue;
        }
        int k = i;
        if (is_kw(&toks[k], "static") || is_kw(&toks[k], "extern"))
            k++;
        if ((is_kw(&toks[k], "let") || is_kw(&toks[k], "var")) && fn_like(k + 1)) {
            int end;
            if (header_end(k + 1, &end) == 'b')
                list_push(&defined, raw_text(k, end));
        }
        i = toks[i].kind == TK_IMPORT || toks[i].kind == TK_IMPORT_K || toks[i].kind == TK_INLINE_C ? i + 1 : decl_end(i);
    }
    for (int i = 0; toks[i].kind != TK_EOF;) {
        Token *t = &toks[i];
        if (strcmp(t->pos.file, file)) {
            i++;
            continue;
        }
        if (t->kind == TK_IMPORT) {
            buf_printf(&b, "#import %s as C\n", t->text);
            i++;
            continue;
        }
        if (t->kind == TK_IMPORT_K) {
            buf_printf(&b, "#import %s\n", t->text);
            i++;
            continue;
        }
        if (t->kind == TK_INLINE_C) { /* in the module's object; its declarations in its header (#199) */
            char *decls = c_declarations(t->text);
            if (*decls)
                buf_printf(&b, "#inline C {\n%s}\n", decls);
            i++;
            continue;
        }
        int k = i;
        const char *storage = NULL;
        if (is_kw(t, "static") || is_kw(t, "extern"))
            storage = toks[k++].text;
        if (is_kw(&toks[k], "struct") || is_kw(&toks[k], "union") || is_kw(&toks[k], "enum")) {
            int end = decl_end(i);
            buf_printf(&b, "%s\n", raw_text(i, end));
            i = end;
            continue;
        }
        if (toks[k].kind == TK_IDENT && !strcmp(toks[k].text, "typealias")) { /* an alias (#149), as written */
            int end = decl_end(i);
            buf_printf(&b, "%s\n", raw_text(i, end));
            i = end;
            continue;
        }
        if (toks[k].kind == TK_IDENT && !strcmp(toks[k].text, "extend")) {
            int open = k + 1;
            while (!is_p(&toks[open], "{") || is_p(&toks[open - 1], ":") || is_kw(&toks[open - 1], "enum") ||
                   is_kw(&toks[open - 1], "struct") || is_kw(&toks[open - 1], "union"))
                open = is_p(&toks[open], "{") ? group_end(open) + 1 : open + 1;
            int close = group_end(open);
            buf_printf(&b, "%s\n", raw_text(i, open + 1));
            List block_seen = {0}; /* a prototype and its definition are one, within the block (#168) */
            for (int m = open + 1; m < close;) {
                int end;
                char how = header_end(m, &end);
                char *text = how == 't' ? type_attribute_decl(prog, m, false) : raw_text(m, end);
                if (how == 'b' && is_kw(&toks[m + 1], "cstr"))
                    text = raw_text(m, group_end(end) + 1); /* T.cstr() (#53) is inline: its body too */
                if (!text_listed(&block_seen, text)) {
                    list_push(&block_seen, text);
                    buf_printf(&b, "    %s\n", text);
                }
                m = how == 'b' ? group_end(end) + 1 : how == 't' ? decl_end(m) : end;
            }
            buf_puts(&b, "}\n");
            i = close + 1;
            continue;
        }
        if (is_kw(&toks[k], "let") || is_kw(&toks[k], "var")) {
            int end;
            char how = header_end(k + 1, &end);
            if (fn_like(k + 1)) {
                bool file_local = storage && !strcmp(storage, "static") && toks[k + 1].kind == TK_IDENT &&
                                  is_p(&toks[k + 2], "(");
                char *text = how == 't' ? type_attribute_decl(prog, i, true) : raw_text(i, end);
                if (how == 'b' && is_p(&toks[k + 2], ".") && is_kw(&toks[k + 3], "cstr"))
                    text = raw_text(i, group_end(end) + 1); /* let T.cstr():cstr { ... } (#53) is inline */
                if (!file_local && !text_listed(&seen, text)) {
                    list_push(&seen, text);
                    if (how == 'b' || text_listed(&defined, text) || (storage && !strcmp(storage, "extern")))
                        buf_printf(&b, "%s\n", text);
                    else
                        buf_printf(&b, "extern %s\n", text); /* a C function's prototype */
                }
            } else if (!(storage && !strcmp(storage, "static"))) {
                /* a global: extern, with the type kelvinc inferred */
                for (int j = 0; j < prog->decls.len; j++) {
                    Decl *d = prog->decls.data[j];
                    if (d->kind != D_VAR || d->pos.line != toks[i].pos.line || strcmp(d->pos.file, file))
                        continue;
                    for (int m = 0; m < d->members.len; m++) {
                        Var *v = d->members.data[m];
                        buf_printf(&b, "extern %s %s:%s\n", is_kw(&toks[k], "let") ? "let" : "var", v->name,
                                   kelvin_type(v->type));
                    }
                }
            }
            i = decl_end(i);
            continue;
        }
        i = decl_end(i);
    }
    return b.buf;
}
