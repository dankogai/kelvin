/* codegen.c - print the Kelvin AST as C

   Kelvin's operator precedence is C's, so expressions are printed with
   exactly the parentheses the programmer wrote. The only rewrites are:

     p^        ->  (*p)
     p^.m      ->  p->m
     a ~ b     ->  a ^ b      (and ~= -> ^=)
     x: T      ->  C declarator for T around x

   `#line` directives map C compiler diagnostics back to the .k source. */
#include "kelvin.h"

#include <ctype.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>

static Buf out;
static int indent;

/* Method dispatch: every (method, receiver type) declared so far, so a
   call `v.m()` becomes _Generic((v), <C type>: <function>, ...)(v). */
typedef struct {
    const char *method;
    const char *ctype;
    const char *fn;
} Method;
static List methods;        /* Method *; a struct's derived .cstr is "cstr" */
/* the structs and unions whose .cstr is used, directly or as a member of
   another: only they get a derived .cstr, so a program that prints no
   struct gets none (char *, the record's name) */
static List cstr_used;
/* The buffers that text properties (x.hex) in the innermost block
   write into, "_kv_n_text[36]" each; NULL outside function bodies */
static List *text_bufs;
/* a cstr's .count (#52): the locals and parameters whose count the
   function asks for, and the _kv_ variable that keeps it once measured */
static List count_names;  /* char *: names whose .count the function uses */
static List count_cache;  /* name, cache name, in pairs; innermost last */
static List param_caches; /* the declarations a function's body block starts with */
static const char *count_cache_of(const char *name);
static const char *owner_free(Type *t);
static const char *owner_take(Type *t);
static const char *owner_copy(Type *t);
static Decl *tagged_type(Type *t);
static bool c_lvalue(Expr *e);
static void emit_tagged_record(Decl *d, Type *recv);
static void emit_arrays_after(Decl *d);
static void emit_derived_copy(Decl *d, Type *recv);
static int cur_decl; /* the index of the top-level declaration being emitted */
/* the block of the switch being emitted (#63): a case ends at the next,
   so `break;` goes before each label and at the end; one exhaustive by
   its cases (closed) tells C that nothing else reaches it */
static Stmt *switch_block;
static bool switch_closed;
static bool is_jump(Stmt *s) {
    return s && (s->kind == S_BREAK || s->kind == S_RETURN || s->kind == S_CONTINUE || s->kind == S_GOTO);
}
static List owner_locals; /* name, type, in pairs: the owners of the function's blocks (#54) */
static bool local_owner(Expr *e);
static Type *local_owner_type(const char *name);
static bool owner_assign(Expr *e);

/* the template literals' storage in the innermost block (#39),
   "_kv_template0[size]" each */
static List *template_vars;
static const char *template_bound(Expr *x);
static bool byte_array(Expr *x);
static char *template_room(Expr *e);
static Decl *text_method_of(const char *tag);

/* The size of the buffer that .dec, .hex, .oct or .bin of a number writes
   into, its NUL included: the longest is an i128's */
static const char *number_text_size(const char *property) {
    return !strcmp(property, "dec")   ? "41"   /* -170141183460469231731687303715884105728 */
           : !strcmp(property, "hex") ? "36"   /* -0x and 32 digits */
           : !strcmp(property, "oct") ? "47"   /* -0o and 43 digits */
                                      : "132"; /* -0b and 128 digits */
}
/* the stems of the hidden names written in the function being written,
   each followed by the number its next repeat takes (#38) */
static List hidden_names;
static Program *program;
static bool line_directives;
static int mapped_line = -1;  /* .k line that the next C line corresponds to */
static const char *mapped_file; /* and its file */

static void line(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

/* while set, every emitted line maps to this .k position (generated
   code such as a derived .cstr) */
static Pos pinned_line;

static void line(const char *fmt, ...) {
    if (line_directives && pinned_line.file)
        buf_printf(&out, "#line %d \"%s\"\n", pinned_line.line, pinned_line.file);
    for (int i = 0; i < indent; i++)
        buf_puts(&out, "    ");
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    char *s = xmalloc((size_t)n + 1);
    va_start(ap, fmt);
    vsnprintf(s, (size_t)n + 1, fmt, ap);
    va_end(ap);
    buf_puts(&out, s);
    buf_puts(&out, "\n");
    if (mapped_line >= 0)
        mapped_line++;
}

static void sync(Pos p) {
    /* an imported Kelvin file's lines are its own (#40) */
    if (!line_directives || (mapped_line == p.line && mapped_file && !strcmp(mapped_file, p.file)))
        return;
    mapped_file = p.file;
    Buf name = {0};
    for (const char *c = p.file; *c; c++) {
        if (*c == '"' || *c == '\\')
            buf_puts(&name, "\\");
        buf_putn(&name, c, 1);
    }
    buf_printf(&out, "#line %d \"%s\"\n", p.line, name.buf);
    mapped_line = p.line;
}

/* ---------- types ---------- */

static char *expr(Expr *e);
static char *text_number(Expr *e);
static char *dispatch_call(Expr *e);
static char *operand_before(Expr *e);

/* Kelvin's sized integers are <stdint.h>'s; 128-bit ones exist where the
   C compiler provides __int128. bool, true and false are <stdbool.h>'s. */
static const char *c_type_name(const char *name) {
    static const struct { const char *kelvin, *c; } map[] = {
        {"i8", "int8_t"},   {"i16", "int16_t"},   {"i32", "int32_t"},   {"i64", "int64_t"},
        {"u8", "uint8_t"},  {"u16", "uint16_t"},  {"u32", "uint32_t"},  {"u64", "uint64_t"},
        {"i128", "__int128"}, {"u128", "unsigned __int128"},
        {"f32", "float"},     {"f64", "double"},
        {"f32 _Complex", "float _Complex"}, {"f64 _Complex", "double _Complex"},
        {"any", "void"}, /* any^ is void * */
        {"Bytes", "kv_bytes"}, /* an owner (#54) */
        {"String", "kv_string"}, /* codepoints on a Bytes (#55) */
        {"uchr", "kv_uchr"}, /* a codepoint (#56) */
    };
    for (size_t i = 0; i < sizeof map / sizeof map[0]; i++)
        if (!strcmp(name, map[i].kelvin))
            return map[i].c;
    return name;
}

static char *decl(Type *t, const char *name);

static char *declarator(Type *t, const char *inner, bool inner_is_ptr) {
    switch (t->kind) {
    case T_BASE:
        return strfmt("%s%s%s%s%s", t->is_const ? "const " : "", t->is_volatile ? "volatile " : "",
                      t->cname ? t->cname : c_type_name(t->name), *inner ? " " : "", inner);
    case T_PTR: {
        char *q = strfmt("%s%s", t->is_const ? "const" : "",
                         t->is_volatile ? (t->is_const ? " volatile" : "volatile") : "");
        char *s = strfmt("*%s%s%s", q, *q && *inner ? " " : "", inner);
        return declarator(t->elem, s, true);
    }
    case T_ARRAY: {
        char *s = inner_is_ptr ? strfmt("(%s)", inner) : xstrdup(inner);
        return declarator(t->elem, strfmt("%s[%s]", s, t->size ? expr(t->size) : ""), false);
    }
    case T_TYPEOF: /* v.type that kelvinc cannot see (#34); unqualified as a value is */
        return strfmt(t->unqual ? "%s%s__typeof__((void)0, (%s))%s%s" : "%s%s__typeof__(%s)%s%s",
                      t->is_const ? "const " : "", t->is_volatile ? "volatile " : "", expr(t->of), *inner ? " " : "",
                      inner);
    case T_FUNC: {
        /* (T, U):R is C's R (*inner)(T, U) (#31). An array parameter is
           the pointer C makes of it, so that no length is needed here */
        Buf params = {0};
        for (int i = 0; i < t->params.len; i++) {
            Type *p = t->params.data[i];
            if (p->kind == T_ARRAY) {
                Type *ptr = xcalloc(1, sizeof *ptr);
                ptr->kind = T_PTR;
                ptr->pos = p->pos;
                ptr->elem = p->elem;
                p = ptr;
            }
            buf_printf(&params, "%s%s", i ? ", " : "", decl(p, ""));
        }
        if (t->variadic)
            buf_puts(&params, ", ...");
        char *q = strfmt("%s%s", t->is_const ? "const" : "",
                         t->is_volatile ? (t->is_const ? " volatile" : "volatile") : "");
        char *s = strfmt("(*%s%s%s)(%s)", q, *q && *inner ? " " : "", inner, params.len ? params.buf : "void");
        return t->elem ? declarator(t->elem, s, false) : strfmt("void %s", s);
    }
    }
    return NULL;
}

/* `x: T` as a C declaration, or the bare type name when name is "" */
static char *decl(Type *t, const char *name) { return declarator(t, name, false); }

/* the C name of a Kelvin name: an anonymous function's $0 is kv_arg0 (#32) */
static const char *c_name(const char *name) { return name[0] == '$' ? strfmt("_kv_arg%s", name + 1) : name; }

/* A hidden name that kelvinc writes (#38): _kv_ and the name of what it
   comes from, then its kind, as _kv_n_text for n.hex's buffer, numbered
   1, 2, ... when it repeats in a function; or, when nothing names it,
   _kv_text0, _kv_text1, ... counted from 0. Each stem keeps its own
   count, and no two stems can make the same name, since a kind is one
   word after the source's last '_' */
static char *hidden(const char *source, const char *kind) {
    char *stem = source ? strfmt("_kv_%s_%s", source, kind) : strfmt("_kv_%s", kind);
    for (int i = 0; i < hidden_names.len; i += 2)
        if (!strcmp(hidden_names.data[i], stem)) {
            intptr_t n = (intptr_t)hidden_names.data[i + 1];
            hidden_names.data[i + 1] = (void *)(n + 1);
            return strfmt("%s%d", stem, (int)n);
        }
    list_push(&hidden_names, stem);
    list_push(&hidden_names, (void *)(intptr_t)1);
    return source ? stem : strfmt("%s0", stem);
}

/* The name that a hidden name for e comes from: a variable, a parameter
   ($0 is arg0), or a member of one, as in p_x for p^.x; NULL otherwise */
static const char *source_of(Expr *e) {
    switch (e->kind) {
    case E_IDENT:
        return e->text[0] == '$' ? strfmt("arg%s", e->text + 1) : e->text;
    case E_FIELD: {
        const char *a = e->a ? source_of(e->a) : NULL;
        return a ? strfmt("%s_%s", a, e->text) : NULL;
    }
    case E_DEREF:
    case E_INDEX:
        return source_of(e->a);
    case E_PROPERTY:
        return !strcmp(e->text, "next") || !strcmp(e->text, "prev") ? source_of(e->a) : NULL;
    default:
        return NULL;
    }
}

/* ---------- expressions ---------- */

static char *c_op(const char *op) {
    if (!strcmp(op, ":="))
        return "="; /* a reference assignment is C's = */
    if (!strcmp(op, "~"))
        return "^";
    if (!strcmp(op, "~="))
        return "^=";
    return (char *)op;
}

static char *initializer(Expr *e);
static Decl *kelvin_record(const char *name);

/* the _Generic associations `<C type>: <function>, ` for a method name */
static char *dispatch(const char *method) {
    Buf assoc = {0};
    buf_puts(&assoc, "");
    for (int i = 0; i < methods.len; i++) {
        Method *m = methods.data[i];
        if (!strcmp(m->method, method))
            buf_printf(&assoc, "%s: %s, ", m->ctype, m->fn);
    }
    return assoc.buf;
}

/* ---------- conditions are bool (#23) ---------- */

static bool is_comparison(const char *op) {
    return !strcmp(op, "==") || !strcmp(op, "!=") || !strcmp(op, "<") || !strcmp(op, ">") || !strcmp(op, "<=") ||
           !strcmp(op, ">=");
}

static bool is_logic(Expr *e) {
    return (e->kind == E_BINARY && (!strcmp(e->op, "&&") || !strcmp(e->op, "||"))) ||
           (e->kind == E_PREFIX && !strcmp(e->op, "!"));
}

/* Is e a bool by its shape, or did the parser see that it is one? */
static bool known_bool(Expr *e) {
    if (e->is_bool || is_logic(e) || (e->kind == E_BINARY && is_comparison(e->op)))
        return true;
    if (e->kind == E_LITERAL)
        return !strcmp(e->text, "true") || !strcmp(e->text, "false");
    if (e->kind == E_CAST)
        return e->type->kind == T_BASE && !strcmp(e->type->name, "bool");
    if (e->kind == E_TERNARY)
        return known_bool(e->b) && known_bool(e->c);
    return false;
}

static char *binary_text(Expr *e);
static char *cond(Expr *e);

/* Does e hold a condition that cond() checks with _Generic? */
static bool has_condition(Expr *e) {
    if (!e)
        return false;
    if (is_logic(e) || e->kind == E_TERNARY)
        return true;
    if (has_condition(e->a) || has_condition(e->b) || has_condition(e->c))
        return true;
    if (e->kind == E_CALL || e->kind == E_METHOD || e->kind == E_INIT || e->kind == E_TEMPLATE)
        for (int i = 0; i < e->items.len; i++)
            if (has_condition(e->items.data[i]))
                return true;
    return false;
}

/* The C for e where C wants a condition (if, while, do, for, ?:, and the
   operands of &&, || and !). Comparisons, &&, || and ! are printed as
   written, since C reads them as 0 or 1, and so is a value the parser saw
   is a bool. Anything else, such as the result of a C function, goes
   through a _Generic that only a bool passes: C reports any other type
   as an argument for kv_condition_is_not_bool. */
static char *cond(Expr *e) {
    char *s;
    if (e->kind == E_BINARY && (!strcmp(e->op, "&&") || !strcmp(e->op, "||")))
        s = strfmt("%s %s %s", cond(e->a), e->op, cond(e->b));
    else if (e->kind == E_PREFIX && !strcmp(e->op, "!"))
        s = strfmt("!%s", cond(e->a));
    else if (e->kind == E_BINARY && is_comparison(e->op))
        s = binary_text(e);
    else if (known_bool(e))
        return expr(e);
    else if (has_condition(e)) { /* a temporary keeps nested checks linear in size */
        char *tmp = hidden(source_of(e), "self");
        return strfmt("({ __auto_type %s = (%s); _Generic((%s), bool: kv_bool, default: kv_condition_is_not_bool)(%s); })",
                      tmp, expr(e), tmp, tmp);
    } else { /* parenthesized, so that a comma stays one argument */
        char *x = expr(e);
        return strfmt("_Generic((%s), bool: kv_bool, default: kv_condition_is_not_bool)((%s))", x, x);
    }
    return e->paren ? strfmt("(%s)", s) : s;
}

/* The condition of a statement, which C wraps in its own parentheses: a
   parenthesized comparison loses its now doubled parentheses, which
   clang warns about, while an assignment keeps them, as C asks */
static char *stmt_cond(Expr *e) {
    if (!e->paren || e->kind != E_BINARY || !is_comparison(e->op))
        return cond(e);
    e->paren = false;
    char *s = cond(e);
    e->paren = true;
    return s;
}

/* Does e hold a method call or a property, whose C repeats its receiver? */
static bool has_dispatch(Expr *e) {
    if (!e)
        return false;
    if (e->kind == E_METHOD || e->kind == E_PROPERTY)
        return true;
    if (has_dispatch(e->a) || has_dispatch(e->b) || has_dispatch(e->c))
        return true;
    if (e->kind == E_CALL || e->kind == E_INIT || e->kind == E_TEMPLATE)
        for (int i = 0; i < e->items.len; i++)
            if (has_dispatch(e->items.data[i]))
                return true;
    return false;
}

static char *expr_bare(Expr *e) {
    switch (e->kind) {
    case E_LITERAL: {
        /* A decimal literal above INT64_MAX has no signed C type; C reads
           it as unsigned anyway but warns. Kelvin has no suffixes, so say
           it in the C. */
        const char *t = e->text;
        if (!strcmp(t, "nullptr"))
            return "((void *)0)";
        /* Kelvin's true and false are bools; C's are the int 1 and 0 */
        if (!strcmp(t, "true") || !strcmp(t, "false"))
            return strfmt("(bool)%s", t);
        size_t n = strlen(t);
        if (n >= 19 && strspn(t, "0123456789") == n && t[0] != '0' &&
            (n > 19 || strcmp(t, "9223372036854775807") > 0))
            return strfmt("%sU", t);
        return e->text;
    }
    case E_IDENT: /* a function's name is its C name (#41) */
        if (e->target)
            return e->target->cname ? e->target->cname : e->target->name;
        if (e->cands.len)
            error_at(e->pos, "'%s' names %d functions: say which by its type, as in 'let f:(T):R := %s'", e->text,
                     e->cands.len, e->text);
        return (char *)c_name(e->text);
    case E_FUNC: /* the static function it became (#32) */
        return e->text;
    case E_TEMPLATE: {
        /* `a${x}b` (#39): built in a buffer inside the statement
           expression, from the literal parts and each value, evaluated
           once into a temporary and shown as print shows it, in order; the
           text is then copied into the template's storage, which the
           enclosing block declares with room for the parts, a NUL and each
           value's longest text. A value may read the earlier text, which is
           replaced only then. The text is a char *, as a string literal is. */
        if (e->op && !strcmp(e->op, "string")) { /* $`...` (#67): a String, appended part by part */
            Buf b = {0};
            buf_puts(&b, "({ kv_string _kv_s = kv_string_new(); ");
            for (int i = 0; i < e->items.len; i++) {
                Expr *x = e->items.data[i];
                if (i % 2 == 0) {
                    if (x->items.len && *(char *)x->items.data[0])
                        buf_printf(&b, "kv_string_append_text(&_kv_s, %s); ", expr(x));
                } else if (!strcmp(x->op, "tplstr_ref")) {
                    buf_printf(&b, "kv_string_append_ref(&_kv_s, &(%s)); ", expr(x->a));
                } else if (!strcmp(x->op, "tplstr_uchr")) {
                    buf_printf(&b, "kv_string_append_uchr(&_kv_s, %s); ", expr(x->a));
                } else {
                    buf_printf(&b, "kv_string_append_text(&_kv_s, %s); ", expr(x->a));
                }
            }
            buf_puts(&b, "_kv_s; })");
            return b.buf;
        }
        if (!template_vars) /* a type outside any block: an anonymous function's head */
            error_at(e->pos, "a template literal with ${...} is made at run time, so it cannot be part of a type");
        char *t = hidden(NULL, "template"), *build = hidden(NULL, "build");
        Buf b = {0}, lits = {0}, bounds = {0};
        buf_puts(&lits, "");
        buf_puts(&bounds, "");
        buf_printf(&b, "({ KV_TEMPLATE_BUILD(%s, %s); ", build, t);
        for (int i = 0; i < e->items.len; i++) {
            Expr *x = e->items.data[i];
            if (x->kind == E_STRING) {
                for (int j = 0; j < x->items.len; j++)
                    if (strcmp(x->items.data[j], "\"\"")) {
                        buf_printf(&b, "KV_TEMPLATE_PART(%s, %s); ", build, (char *)x->items.data[j]);
                        buf_printf(&lits, " %s", (char *)x->items.data[j]);
                    }
            } else if (byte_array(x)) {
                /* a byte array, read no further than its own size, which
                   sizeof gives without evaluating it again; written in the
                   same expression, as an array in a temporary struct
                   (mk().tag) lives no longer */
                char *value = expr_bare(x);
                const char *bound = template_bound(x);
                buf_printf(&b, "KV_TEMPLATE_BYTES(%s, %s, sizeof (%s), (%s)); ", build, bound, value, value);
                buf_printf(&bounds, " + %s", bound);
            } else {
                /* (void)0, v: a bit-field cannot initialize __auto_type */
                char *v = hidden(NULL, "value");
                char *value = expr_bare(x); /* a nested template names its storage */
                const char *bound = template_bound(x);
                buf_printf(&b, "__auto_type %s = ((void)0, (%s)); KV_TEMPLATE_VALUE(%s, %s, %s); ", v, value, build,
                           bound, v);
                buf_printf(&bounds, " + %s", bound);
            }
        }
        buf_printf(&b, "KV_TEMPLATE_TAKE(%s, %s); })", t, build);
        /* the parts with one NUL, and each value's text; declared after
           the templates in its values, whose sizes it uses */
        list_push(template_vars, strfmt("%s[sizeof%s%s]", t, lits.len ? lits.buf : " \"\"", bounds.buf));
        e->text = t;
        return b.buf;
    }
    case E_STRING: {
        Buf b = {0};
        for (int i = 0; i < e->items.len; i++)
            buf_printf(&b, "%s%s", i ? " " : "", (char *)e->items.data[i]);
        return b.buf;
    }
    case E_PREFIX: {
        if (!strcmp(e->op, "!"))
            return strfmt("((bool)!%s)", cond(e->a)); /* C's ! gives an int */
        char *a = expr(e->a);
        char last = e->op[strlen(e->op) - 1];
        /* keep `- -x` from becoming `--x` */
        bool space = (last == '-' || last == '+' || last == '&') && a[0] == last;
        return strfmt("%s%s%s", e->op, space ? " " : "", a);
    }
    case E_POSTFIX:
        return strfmt("%s%s", expr(e->a), e->op);
    case E_DEREF:
        return strfmt("(*%s)", expr(e->a));
    case E_BINARY:
        /* C's comparisons, && and || give an int; Kelvin's give a bool */
        if (!strcmp(e->op, "&&") || !strcmp(e->op, "||"))
            return strfmt("((bool)(%s %s %s))", cond(e->a), e->op, cond(e->b));
        if (is_comparison(e->op))
            return strfmt("((bool)(%s))", binary_text(e));
        return binary_text(e);
    case E_TERNARY: {
        char *s = strfmt("%s ? %s : %s", cond(e->a), expr(e->b), expr(e->c));
        return known_bool(e) ? strfmt("((bool)(%s))", s) : s; /* C promotes two bools to int */
    }
    case E_CALL: {
        if (e->op && !strcmp(e->op, "bytes")) { /* Bytes(...) (#54) */
            if (!e->items.len)
                return "kv_bytes_new()";
            if (e->items.len == 1)
                return strfmt("KV_BYTES_OF(%s)", expr(e->items.data[0]));
            return strfmt("kv_bytes_from(%s, %s)", expr(e->items.data[0]), expr(e->items.data[1]));
        }
        if (e->op && !strcmp(e->op, "string")) /* String(...) (#55) */
            return e->items.len ? strfmt("KV_STRING_OF(%s)", expr(e->items.data[0])) : "kv_string_new()";
        if (e->op && !strcmp(e->op, "dict") && e->type) { /* Dictionary<K, V>(...), $[k: v] (#65) */
            if (!strcmp(e->text, "copy"))
                return strfmt("%s_copy(%s)", e->type->cname, expr(e->items.data[0]));
            if (!e->items.len)
                return strfmt("(%s){0}", e->type->cname);
            Buf b = {0};
            buf_printf(&b, "({ %s _kv_d = {0}; ", e->type->cname);
            for (int i = 0; i < e->items.len; i++)
                buf_printf(&b, "%s_set(&_kv_d, %s, %s); ", e->type->cname, expr(e->designators.data[i]),
                           expr(e->items.data[i]));
            buf_puts(&b, "_kv_d; })");
            return b.buf;
        }
        if (e->op && !strcmp(e->op, "case_make") && e->target) { /* T.n(x), T.none (#61) */
            if (!e->items.len)
                return strfmt("_kv_%s_make_%s()", e->target->name, e->text);
            Expr *x = e->items.data[0];
            Var *c = NULL;
            for (int i = 0; i < e->target->members.len; i++)
                if (!strcmp(((Var *)e->target->members.data[i])->name, e->text))
                    c = e->target->members.data[i];
            const char *take = c && local_owner(x) ? owner_take(c->type) : NULL;
            return strfmt("_kv_%s_make_%s(%s)", e->target->name, e->text,
                          take ? strfmt("%s(&%s)", take, c_name(x->text)) : expr(x));
        }
        if (e->op && !strcmp(e->op, "array")) { /* Array<T>(...) (#57) */
            if (!e->items.len)
                return strfmt("(%s){0}", e->type->cname);
            char *x = expr(e->items.data[0]);
            if (!strcmp(e->text, "fixed"))
                return strfmt("%s_from(%s, sizeof (%s) / sizeof (%s)[0])", e->type->cname, x, x, x);
            if (!strcmp(e->text, "list")) /* Array([a, b, c]): a compound literal of the elements (#58) */
                return strfmt("%s_from(%s, %s)", e->type->cname, x, ((Expr *)e->items.data[0])->type->size->text);
            if (!strcmp(e->text, "copy"))
                return strfmt("%s_copy(%s)", e->type->cname, x);
            return strfmt("%s_zeros(%s)", e->type->cname, x);
        }
        if (e->cands.len)
            return dispatch_call(e);
        Buf b = {0};
        const char *callee = e->target ? (e->target->cname ? e->target->cname : e->target->name)
                             : e->op && !strcmp(e->op, "c") ? e->a->text /* C's own function (#41) */
                                                            : operand_before(e->a);
        if ((e->target || (e->op && !strcmp(e->op, "c"))) && e->a->paren)
            callee = strfmt("((%s))", callee); /* (f)(x) calls the function, not a macro of its name */
        buf_printf(&b, "%s(", callee);
        for (int i = 0; i < e->items.len; i++) {
            Expr *x = e->items.data[i];
            /* a local owner given by value moves into the callee (#54) */
            const char *take = e->target && i < e->target->params.len && local_owner(x)
                                   ? owner_take(((Var *)e->target->params.data[i])->type)
                                   : NULL;
            buf_printf(&b, "%s%s", i ? ", " : "", take ? strfmt("%s(&%s)", take, c_name(x->text)) : expr(x));
        }
        buf_puts(&b, ")");
        return b.buf;
    }
    case E_INDEX:
        if (e->a && e->op && !strcmp(e->op, "bytes")) /* b[i] of a Bytes, checked (#54) */
            return strfmt("(*kv_bytes_at(&%s, %s))", expr(e->a), expr(e->b));
        if (e->a && e->op && !strcmp(e->op, "dict") && e->type) /* d[k] of a Dictionary, checked (#65) */
            return strfmt("(*%s_at(&%s, %s))", e->type->cname, expr(e->a), expr(e->b));
        if (e->a && e->op && !strcmp(e->op, "array") && e->type) /* xs[i] of an Array, checked (#57) */
            return strfmt("(*%s_at(&%s, %s))", e->type->cname, expr(e->a), expr(e->b));
        return strfmt("%s[%s]", e->a ? expr(e->a) : "", expr(e->b));
    case E_FIELD:
        if (e->op && !strcmp(e->op, "case") && e->target) { /* v.n of an enum with values, checked (#61) */
            char *recv = expr(e->a);
            return c_lvalue(e->a) ? strfmt("(*_kv_%s_at_%s(&%s))", e->target->name, e->text, recv)
                                  : strfmt("_kv_%s_get_%s(%s)", e->target->name, e->text, recv);
        }
        if (e->a && e->a->kind == E_DEREF && !e->a->paren)
            return strfmt("%s->%s", expr(e->a->a), e->text);
        return strfmt("%s.%s", e->a ? expr(e->a) : "", e->text);
    case E_CAST:
        if (e->op && !strcmp(e->op, "converter"))
            return strfmt("(%s)(%s)", decl(e->type, ""), expr_bare(e->a));
        if (e->op && !strcmp(e->op, "uchr")) /* uchr(x) (#56) */
            return strfmt("KV_UCHR_OF(%s)", expr_bare(e->a));
        if (e->op && !strncmp(e->op, "text", 4))
            return text_number(e);
        return strfmt("(%s)%s", decl(e->type, ""), expr(e->a));
    case E_COMPOUND: /* without an initializer, [T](n): zero-filled (#49) */
        return strfmt("(%s)%s", decl(e->type, ""), e->a ? initializer(e->a) : "{0}");
    case E_SIZEOF_TYPE:
        return strfmt("sizeof(%s)", decl(e->type, ""));
    case E_SIZEOF_EXPR:
        /* sizeof(name) may name a C typedef, so keep single parentheses.
           Any other parenthesized operand gets double parentheses, so that
           C cannot read e.g. `sizeof (T * (U8))` as a type name */
        if (e->a->kind == E_IDENT && e->a->paren)
            return strfmt("sizeof(%s)", c_name(e->a->text));
        if (e->a->paren)
            return strfmt("sizeof (%s)", expr(e->a));
        return strfmt("sizeof %s", expr(e->a));
    case E_INIT:
        return initializer(e);
    case E_PROPERTY: {
        /* x.size is sizeof(x). x.cstr, x.hex and friends write into a
           buffer on the caller's stack and return it as u8^. The buffer
           is declared at the top of the enclosing block (see S_BLOCK), so
           the text lives until the block ends. Its size is the longest
           text of any type, -0x and 32 digits for .hex; for .cstr, that
           of the receiver's struct, or of one value. The receiver is
           evaluated once: sizeof and _Generic do not evaluate. */
        char *recv = expr(e->a);
        if (e->op && !strcmp(e->op, "tagged")) /* v.case, the tag (#61) */
            return strfmt("(%s).tag", recv);
        if (e->op && !strcmp(e->op, "uchr")) /* c.utf32 (#56) */
            return strfmt("(%s).cp", recv);
        if (e->op && !strcmp(e->op, "to")) /* n.uchr (#56) */
            return strfmt("kv_uchr_of(%s)", recv);
        if (e->op && !strcmp(e->op, "bytes")) { /* a Bytes (#54) */
            if (!strcmp(e->text, "cstr"))
                return strfmt("kv_bytes_cstr(&%s)", recv);
            if (!strcmp(e->text, "isUTF8"))
                return strfmt("kv_bytes_is_utf8(&%s)", recv);
            return strfmt("(%s).%s", recv, !strcmp(e->text, "capacity") ? "cap" : e->text);
        }
        if (e->op && !strcmp(e->op, "array")) /* an Array (#57) */
            return strfmt("(%s).%s", recv, !strcmp(e->text, "capacity") ? "cap" : e->text);
        if (e->op && !strcmp(e->op, "dict") && e->recv_type) /* d.keys, d.values (#66) */
            return strfmt("%s_%s(&%s)", e->recv_type->cname, e->text, recv);
        if (e->op && !strcmp(e->op, "dict")) /* a Dictionary's count (#65) */
            return strfmt("(%s).count", recv);
        if (e->op && !strcmp(e->op, "string")) { /* a String (#55) */
            if (!strcmp(e->text, "cstr"))
                return strfmt("kv_bytes_cstr(&(%s).b)", recv);
            if (!strcmp(e->text, "bytes"))
                return strfmt("((const kv_bytes *)&(%s).b)", recv);
            return strfmt("(%s).count", recv);
        }
        if (!strcmp(e->text, "size"))
            return strfmt("sizeof(%s)", recv);
        if (!strcmp(e->text, "count") && e->op && !strcmp(e->op, "cstr")) {
            /* strlen, measured at the first use of a local's or a
               parameter's and kept until the scope ends (#52) */
            const char *cache = e->a->kind == E_IDENT ? count_cache_of(e->a->text) : NULL;
            if (cache)
                return strfmt("(%s == (size_t)-1 ? (%s = strlen((const char *)%s)) : %s)", cache, cache, recv, cache);
            return strfmt("strlen((const char *)%s)", recv);
        }
        if (!strcmp(e->text, "count")) /* an array's elements (#49), a VLA's too */
            return strfmt("(sizeof(%s) / sizeof((%s)[0]))", recv, recv);
        if (!strcmp(e->text, "typename")) /* a type kelvinc cannot see (#34) */
            return strfmt("kv_typename((%s))", recv);
        if (!strcmp(e->text, "next") || !strcmp(e->text, "prev")) /* #26 */
            return strfmt("(%s %s 1)", recv, e->text[0] == 'n' ? "+" : "-");
        if (!strcmp(e->text, "addr")) /* #37 */
            return strfmt("((uintptr_t)(%s))", recv);
        if (!strcmp(e->text, "isNull")) /* #50: C's == gives an int */
            return strfmt("((bool)((%s) == 0))", recv);
        bool cstr = !strcmp(e->text, "cstr");
        Decl *r = cstr && e->type ? kelvin_record(e->type->name) : NULL;
        const char *size = r ? strfmt("_kv_%s_cstr_size", r->name) : cstr ? "KV_CSTR_SCALAR" : number_text_size(e->text);
        char *buf;
        if (text_bufs) {
            buf = hidden(source_of(e->a), "text");
            list_push(text_bufs, strfmt("%s[%s]", buf, size));
        } else {
            buf = strfmt("(uint8_t[%s]){0}", size); /* at file scope */
        }
        if (r)
            return strfmt("_kv_%s_cstr(%s, %s)", r->name, recv, buf); /* a struct kelvinc can see */
        if (e->op && !strcmp(e->op, "pointer")) /* p.hex of a pointer or a function (#37) */
            return strfmt("kv_hex_addr((uintptr_t)(%s), %s)", recv, buf);
        /* a receiver that holds a property or method call, as in
           x.hex[2].hex, goes into a temporary like a method's receiver,
           so that nesting stays linear in size */
        char *tmp = has_dispatch(e->a) ? hidden(source_of(e->a), "self") : NULL;
        const char *self = tmp ? tmp : recv;
        /* for .cstr, other pointers are addresses, and a Kelvin struct
           kelvinc could not see has no buffer sized for it: a C error */
        Buf structs = {0};
        buf_puts(&structs, "");
        for (int i = 0; cstr && e->op && i < methods.len; i++) {
            Method *m = methods.data[i];
            if (!strcmp(m->method, "cstr"))
                buf_printf(&structs, "%s: kv_cstr_unseen_struct, ", m->ctype);
        }
        /* .hex of what kelvinc cannot see may be of a pointer (#37) */
        const char *other = cstr                        ? "kv_cstr_ptr"
                            : !strcmp(e->text, "hex") ? strfmt("KV_HEX_DEFAULT((%s))", self)
                                                      : "kv_no_such_property";
        char *call = strfmt("_Generic((%s), KV_PROPERTY_%s %sdefault: %s)(%s, %s)", self, e->text, structs.buf, other,
                            self, buf);
        return tmp ? strfmt("({ __auto_type %s = %s; %s; })", tmp, recv, call) : call;
    }
    case E_METHOD: {
        if (e->op && !strcmp(e->op, "dict") && e->type) { /* a Dictionary method (#65), on a place */
            Buf args = {0};
            buf_puts(&args, "");
            for (int i = 0; i < e->items.len; i++)
                buf_printf(&args, ", %s", expr(e->items.data[i]));
            return strfmt("%s_%s(&%s%s)", e->type->cname, e->text, expr(e->a), args.buf);
        }
        if (e->op && !strcmp(e->op, "case_is") && e->target) { /* v.is(n) (#61) */
            int k = 0;
            for (int i = 0; i < e->target->members.len; i++)
                if (!strcmp(((Var *)e->target->members.data[i])->name, e->text))
                    k = i;
            return strfmt("((bool)((%s).tag == %d))", expr(e->a), k); /* the cast keeps C quiet about ((a == b)) */
        }
        if (e->op && !strcmp(e->op, "case_set") && e->target) { /* v.n = x (#61) */
            if (!e->items.len)
                return strfmt("_kv_%s_set_%s(&%s)", e->target->name, e->text, expr(e->a));
            Expr *x = e->items.data[0];
            Var *c = NULL;
            for (int i = 0; i < e->target->members.len; i++)
                if (!strcmp(((Var *)e->target->members.data[i])->name, e->text))
                    c = e->target->members.data[i];
            const char *take = c && local_owner(x) ? owner_take(c->type) : NULL;
            return strfmt("_kv_%s_set_%s(&%s, %s)", e->target->name, e->text, expr(e->a),
                          take ? strfmt("%s(&%s)", take, c_name(x->text)) : expr(x));
        }
        if (e->op && !strcmp(e->op, "record_copy") && e->type) { /* s.copy() of a struct that owns (#61) */
            Decl *r = kelvin_record(e->type->name);
            return strfmt("_kv_%s_copy(&%s)", r ? r->name : "?", expr(e->a));
        }
        if (e->op && !strcmp(e->op, "array")) { /* an Array method (#57), on a place */
            Type *at = local_owner_type(e->a->kind == E_IDENT ? e->a->text : "");
            const char *cn = e->type ? e->type->cname : at ? at->cname : NULL;
            char *recv = strfmt("&%s", expr(e->a));
            Buf args = {0};
            buf_puts(&args, "");
            for (int i = 0; i < e->items.len; i++)
                buf_printf(&args, ", %s", expr(e->items.data[i]));
            if (!strcmp(e->text, "append") && e->items.len == 1) {
                Expr *x = e->items.data[0];
                if (x->kind == E_PREFIX && !strcmp(x->op, "&") && x->c) /* a borrow of an Array: its elements */
                    return strfmt("%s_append_ref(%s%s)", cn, recv, args.buf);
                if (x->c) /* an Array an expression gives: appended and freed */
                    return strfmt("%s_append_owned(%s%s)", cn, recv, args.buf);
            }
            return strfmt("%s_%s(%s%s)", cn, e->text, recv, args.buf);
        }
        if (e->op && !strcmp(e->op, "string")) { /* a String method (#55), on a place */
            char *recv = strfmt("&%s", expr(e->a));
            if (!strcmp(e->text, "append"))
                return strfmt("KV_STRING_APPEND(%s, %s)", recv, expr(e->items.data[0]));
            if (!strcmp(e->text, "reserve"))
                return strfmt("kv_string_reserve(%s, %s)", recv, expr(e->items.data[0]));
            return strfmt("kv_string_%s(%s)", e->text, recv); /* clear, compact, copy */
        }
        if (e->op && !strcmp(e->op, "bytes")) { /* a Bytes method (#54), on a place */
            char *recv = strfmt("&%s", expr(e->a));
            if (!strcmp(e->text, "string"))
                return strfmt("kv_string_from_bytes(%s)", recv);
            if (!strcmp(e->text, "append"))
                return strfmt("KV_BYTES_APPEND(%s, %s)", recv, expr(e->items.data[0]));
            if (!strcmp(e->text, "insert"))
                return strfmt("KV_BYTES_INSERT(%s, %s, %s)", recv, expr(e->items.data[0]), expr(e->items.data[1]));
            if (!strcmp(e->text, "remove"))
                return strfmt("kv_bytes_remove(%s, %s, %s)", recv, expr(e->items.data[0]), expr(e->items.data[1]));
            if (!strcmp(e->text, "reserve"))
                return strfmt("kv_bytes_reserve(%s, %s)", recv, expr(e->items.data[0]));
            return strfmt("kv_bytes_%s(%s)", e->text, recv); /* clear, compact, copy */
        }
        /* The receiver is evaluated once into a temporary, which also
           keeps chains like a.b().c() linear in size (GNU statement
           expression and __auto_type, both accepted by gcc and clang) */
        char *recv = expr(e->a);
        char *tmp = hidden(source_of(e->a), "self");
        Buf args = {0};
        buf_puts(&args, "");
        for (int i = 0; i < e->items.len; i++)
            buf_printf(&args, ", %s", expr(e->items.data[i]));
        return strfmt("({ __auto_type %s = %s; _Generic((%s), %sdefault: kv_no_such_method)(%s%s); })", tmp, recv,
                      tmp, dispatch(e->text), tmp, args.buf);
    }
    }
    return NULL;
}

/* KV_NUMBER's code for a parameter of one of Kelvin's number types, or
   NULL (#41) */
static const char *number_code(Type *t) {
    static const char *names[][2] = {
        {"bool", "KV_N_BOOL"}, {"i8", "KV_N_I8"},     {"u8", "KV_N_U8"},     {"i16", "KV_N_I16"}, {"u16", "KV_N_U16"},
        {"i32", "KV_N_I32"},   {"u32", "KV_N_U32"},   {"i64", "KV_N_I64"},   {"u64", "KV_N_U64"}, {"i128", "KV_N_I128"},
        {"u128", "KV_N_U128"}, {"f32", "KV_N_F32"},   {"f64", "KV_N_F64"}};
    if (t->kind != T_BASE)
        return NULL;
    for (size_t i = 0; i < sizeof names / sizeof names[0]; i++)
        if (!strcmp(t->name, names[i][0]))
            return names[i][1];
    return NULL;
}

/* Parameter k's type as C passes it: unqualified, an array a pointer */
static Type *passed_type(Decl *d, int k) {
    Type *u = xcalloc(1, sizeof *u);
    *u = *((Var *)d->params.data[k])->type;
    u->is_const = u->is_volatile = false;
    if (u->kind == T_ARRAY) {
        u->kind = T_PTR;
        u->size = NULL;
    }
    return u;
}

/* f(args) where only C's _Generic can tell which overload fits (#41):
   the arguments go into temporaries (inside a function), then, over each
   argument kelvinc cannot see the type of, a choice among the overloads
   that may fit. Structs, pointers, enums and C typedefs are matched by
   their C types, each in a _Generic of its own, so that two types that
   are the same in C cannot clash; numbers by KV_NUMBER, as the Kelvin type
   they are, so long and long long are both i64. A number of another type
   goes to the one overload that takes a number there, which C converts
   it to, and a pointer to the one that takes a pointer; with none, to C's
   own function of the name where the program calls it (c_too), and
   otherwise, as with several, to kv_no_such_overload, a C error. An
   operator (#42) has no C function. One overload left with nothing else
   to choose is called, and C converts or reports the arguments. */
static char *generic_tree(List *cands, Expr *call, char **args, int k) {
    bool op = !isalpha((unsigned char)call->a->text[0]) && call->a->text[0] != '_';
    char *none = op ? "kv_no_such_operator" : "kv_no_such_overload";
    char *c_fn = !op && call->c_too ? call->a->text : none;
    if (cands->len == 1 && c_fn == none)
        return ((Decl *)cands->data[0])->cname;
    while (k < call->items.len) {
        if (call->unseen && !call->unseen[k]) { /* kelvinc saw it fits every overload left */
            k++;
            continue;
        }
        if (c_fn != none)
            break; /* what fits no overload left goes to C's function */
        bool differ = false;
        for (int i = 1; i < cands->len && !differ; i++) {
            Decl *a = cands->data[0], *b = cands->data[i];
            differ = k >= a->params.len || k >= b->params.len ||
                     strcmp(decl(passed_type(a, k), ""), decl(passed_type(b, k), ""));
        }
        if (differ || cands->len == 1)
            break;
        k++;
    }
    if (k >= call->items.len)
        return cands->len == 1 ? ((Decl *)cands->data[0])->cname : none; /* more than one fits equally */
    /* the overloads left, grouped by their parameter k's C type */
    List types = {0}, groups = {0}, va = {0};
    for (int i = 0; i < cands->len; i++) {
        Decl *d = cands->data[i];
        if (k >= d->params.len) {
            if (d->variadic) /* takes anything there, in its ... */
                list_push(&va, d);
            continue;
        }
        char *ct = decl(passed_type(d, k), "");
        int g = -1;
        for (int j = 0; j < types.len && g < 0; j++)
            if (!strcmp(decl(types.data[j], ""), ct))
                g = j;
        if (g < 0) {
            list_push(&types, passed_type(d, k));
            List *same = xcalloc(1, sizeof *same);
            list_push(&groups, same);
            g = types.len - 1;
        }
        list_push(groups.data[g], d);
    }
    /* what a number, a pointer and anything else of another type go to */
    int numbers = -1, pointers = -1, nn = 0, np = 0;
    for (int g = 0; g < types.len; g++) {
        Decl *d = ((List *)groups.data[g])->data[0];
        Var *p = d->params.data[k];
        Type *t = types.data[g];
        if (p->number)
            numbers = g, nn++;
        if (t->kind == T_PTR || t->kind == T_FUNC)
            pointers = g, np++;
    }
    /* where no overload takes the value there, the one whose ... takes it */
    char *other = va.len == 1 ? generic_tree(&va, call, args, k + 1) : va.len ? none : c_fn;
    char *number = nn == 1 ? generic_tree(groups.data[numbers], call, args, k + 1) : nn ? none : other;
    char *pointer = np == 1 ? generic_tree(groups.data[pointers], call, args, k + 1) : np ? none : other;
    char *rest = !strcmp(pointer, other) ? other
                 : strfmt("__builtin_choose_expr(KV_POINTER(%s), %s, %s)", args[k], pointer, other);
    rest = !strcmp(number, rest) ? rest : strfmt("__builtin_choose_expr(KV_NUMBER(%s) != 0, %s, %s)", args[k], number, rest);
    /* an enum by its C type, which C cannot tell from its integer type, so
       after the numbers; the numbers by their Kelvin type; structs,
       pointers and C typedefs by their C type, first */
    for (int g = types.len - 1; g >= 0; g--) {
        Type *t = types.data[g];
        if (t->kind == T_BASE && !strncmp(t->name, "enum ", 5))
            rest = strfmt("_Generic((%s), %s: %s, default: %s)", args[k], decl(t, ""),
                          generic_tree(groups.data[g], call, args, k + 1), rest);
    }
    for (int g = types.len - 1; g >= 0; g--) {
        const char *code = number_code(types.data[g]);
        if (code)
            rest = strfmt("__builtin_choose_expr(KV_NUMBER(%s) == %s, %s, %s)", args[k], code,
                          generic_tree(groups.data[g], call, args, k + 1), rest);
    }
    for (int g = types.len - 1; g >= 0; g--) {
        Type *t = types.data[g];
        if (!number_code(t) && !(t->kind == T_BASE && !strncmp(t->name, "enum ", 5)))
            rest = strfmt("_Generic((%s), %s: %s, default: %s)", args[k], decl(t, ""),
                          generic_tree(groups.data[g], call, args, k + 1), rest);
    }
    return rest;
}

static char *dispatch_call(Expr *e) {
    int n = e->items.len;
    char **args = xcalloc((size_t)n + 1, sizeof *args);
    Buf temps = {0};
    buf_puts(&temps, "");
    for (int i = 0; i < n; i++) {
        Expr *x = e->items.data[i];
        if (text_bufs) {
            /* (void)0, x: a bit-field cannot initialize __auto_type */
            args[i] = hidden(source_of(x), "self");
            buf_printf(&temps, "__auto_type %s = ((void)0, (%s)); ", args[i], expr_bare(x));
        } else {
            args[i] = strfmt("(%s)", expr_bare(x));
        }
    }
    Buf b = {0};
    buf_printf(&b, "%s(", generic_tree(&e->cands, e, args, 0));
    for (int i = 0; i < n; i++)
        buf_printf(&b, "%s%s", i ? ", " : "", args[i]);
    buf_puts(&b, ")");
    return text_bufs ? strfmt("({ %s%s; })", temps.buf, b.buf) : b.buf;
}

/* Text for the runtime's readers: a ?: whose arms are texts of C types
   that differ, such as main's char * argv[1] and a cstr, gets const
   void * arms (#36) */
static char *text_arg(Expr *e) {
    if (e->kind == E_TERNARY)
        return strfmt("(%s ? (const void *)%s : (const void *)%s)", cond(e->a), text_arg(e->b), text_arg(e->c));
    return strfmt("(%s)", expr_bare(e));
}

/* i32("42"), i32(text, 8) and "42".i32 (#36): the number read from text
   by the runtime's kv_text_int and friends, clamped to the type's limits
   (base 10 when none is given). Where kelvinc cannot see whether the
   value is text, KV_TEXT lets _Generic choose between reading and
   converting it, and with a base, only text compiles. Inside a function
   the value goes into a temporary first, so that it is evaluated and
   written once; at file scope, KV_TEXT of a number stays a constant. */
static char *text_number(Expr *e) {
    const char *name = e->type->name, *type = decl(e->type, ""), *bits = name + 1;
    char *base = e->b ? strfmt("(%s)", expr_bare(e->b)) : "10";
    char *read, *rest;
    if (!strcmp(name, "f32") || !strcmp(name, "f64")) {
        read = strfmt("kv_text_%s", name);
        rest = "";
    } else if (!strcmp(name, "i128") || !strcmp(name, "u128")) {
        read = strfmt("kv_text_%s", name);
        rest = strfmt(", %s", base);
    } else if (name[0] == 'u') {
        read = "kv_text_uint";
        rest = strfmt(", %s, UINT%s_MAX", base, bits);
    } else {
        read = "kv_text_int";
        rest = strfmt(", %s, INT%s_MIN, INT%s_MAX", base, bits, bits);
    }
    if (!strcmp(e->op, "text"))
        return strfmt("(%s)%s(%s%s)", type, read, text_arg(e->a), rest);
    char *v = strfmt("(%s)", expr_bare(e->a)), *x = v, *tmp = NULL;
    if (text_bufs)
        x = tmp = hidden(source_of(e->a), "self");
    char *c = e->b ? strfmt("(%s)_Generic(KV_TEXT_TAG(%s), kv_text_tag *: %s, default: kv_base_needs_text)(KV_TEXT_PTR(%s)%s)",
                            type, x, read, x, rest)
                   : strfmt("KV_TEXT(%s, %s, %s(KV_TEXT_PTR(%s)%s))", type, x, read, x, rest);
    /* (void)0, v: a bit-field cannot initialize __auto_type */
    return tmp ? strfmt("({ __auto_type %s = ((void)0, %s); %s; })", tmp, v, c) : c;
}

static char *expr(Expr *e) {
    char *s = expr_bare(e);
    return e->paren ? strfmt("(%s)", s) : s;
}

/* a binary operator other than && and ||, as C writes it */
static char *binary_text(Expr *e) {
    if (!strcmp(e->op, ","))
        return strfmt("%s, %s", expr(e->a), expr(e->b));
    if (strchr("-+*&", e->op[0]) && e->op[1] == '\0')
        return strfmt("%s %s %s", operand_before(e->a), c_op(e->op), expr(e->b));
    return strfmt("%s %s %s", expr(e->a), c_op(e->op), expr(e->b));
}

/* C reads `( type-name )` followed by an operand as a cast. A
   parenthesized name, call or index could be a C type name, as in
   (size_t) or (size_t[2]), so where an operand follows it (a binary
   - + * &, or a call's argument list) it is printed with double
   parentheses, which C never reads as a type name: Kelvin's
   `(size_t) - 1` becomes `((size_t)) - 1` and fails in C instead of
   silently casting. Elsewhere, e.g. __attribute__((fallthrough)), the
   parentheses are printed as written. */
static char *operand_before(Expr *e) {
    char *s = expr(e);
    bool may_be_type = e->kind == E_IDENT || e->kind == E_CALL || e->kind == E_INDEX;
    return e->paren && may_be_type ? strfmt("(%s)", s) : s;
}

/* The function that frees an owner of type t (#54): kv_bytes_free, or a
   struct's derived _kv_T_free; NULL for a type that owns nothing */
static const char *owner_free(Type *t) {
    if (!t)
        return NULL;
    if (t->kind == T_TYPEOF)
        return owner_free(t->elem);
    if (t->kind != T_BASE)
        return NULL;
    if (!strcmp(t->name, "Bytes"))
        return "kv_bytes_free";
    if (!strcmp(t->name, "String"))
        return "kv_string_free";
    if (t->cname) /* Array<T> (#57) */
        return strfmt("%s_free", t->cname);
    Decl *r = kelvin_record(t->name);
    if (!r || r->kind != D_STRUCT)
        return NULL;
    for (int i = 0; i < r->members.len; i++) {
        Type *m = ((Var *)r->members.data[i])->type;
        if (m && (owner_free(m) || (m->kind == T_ARRAY && owner_free(m->elem))))
            return strfmt("_kv_%s_free", r->name);
    }
    return NULL;
}

/* the function that copies an owner, from its free's name */
static const char *owner_copy(Type *t) {
    const char *f = owner_free(t);
    if (!f)
        return NULL;
    return strfmt("%.*s_copy", (int)strlen(f) - 5, f);
}

/* the record of t, if it is an enum with values (#61) */
static Decl *tagged_type(Type *t) {
    if (t && t->kind == T_TYPEOF)
        t = t->elem;
    Decl *r = t && t->kind == T_BASE && !t->cname ? kelvin_record(t->name) : NULL;
    return r && r->tagged ? r : NULL;
}

/* Is e a place in C, whose address may be taken? */
static bool c_lvalue(Expr *e) {
    switch (e->kind) {
    case E_IDENT:
    case E_DEREF:
    case E_INDEX:
        return true;
    case E_FIELD:
        return e->a && c_lvalue(e->a);
    default:
        return false;
    }
}

/* the function that moves an owner out of a place, leaving it empty */
static const char *owner_take(Type *t) {
    const char *f = owner_free(t);
    if (!f)
        return NULL;
    return strfmt("%.*s_take", (int)strlen(f) - 5, f);
}

/* Is e the name of an owner of this function, a local or a parameter? */
static bool local_owner(Expr *e) {
    if (e->kind != E_IDENT)
        return false;
    for (int i = owner_locals.len - 2; i >= 0; i -= 2)
        if (!strcmp(owner_locals.data[i], e->text))
            return true;
    return false;
}

static Type *local_owner_type(const char *name) {
    for (int i = owner_locals.len - 2; i >= 0; i -= 2)
        if (!strcmp(owner_locals.data[i], name))
            return owner_locals.data[i + 1];
    return NULL;
}

/* b = v where b owns (#54): what b held is freed, then b takes v, which an
   expression gave (a place would be a copy, which the parser rejects) */
static bool owner_assign(Expr *e) {
    if (e->a->kind == E_INDEX && e->a->op && !strcmp(e->a->op, "array") && e->a->type) {
        /* xs[i] = v where the element owns (#57) */
        const char *f = owner_free(e->a->type->elem);
        if (!f)
            return false;
        line("%.*s_assign(%s_at(&%s, %s), %s);", (int)strlen(f) - 5, f, e->a->type->cname, expr(e->a->a), expr(e->a->b),
             expr(e->b));
        return true;
    }
    Type *t = e->a->kind == E_IDENT ? local_owner_type(e->a->text) : NULL;
    const char *f = t ? owner_free(t) : NULL;
    if (!f) /* a field, a global, or no owner: C's assignment */
        return false;
    if (!strncmp(f, "kv_", 3) || !strncmp(f, "_kv_array_", 10) || !strncmp(f, "_kv_dict_", 9)) /* kv_bytes_assign, kv_string_assign, an Array's, a Dictionary's */
        line("%.*s_assign(&%s, %s);", (int)strlen(f) - 5, f, c_name(e->a->text), expr(e->b));
    else
        line("%s(&%s), %s = %s;", f, c_name(e->a->text), c_name(e->a->text), expr(e->b));
    return true;
}

/* the _kv_ variable that keeps name's .count in this scope, or NULL */
static const char *count_cache_of(const char *name) {
    for (int i = count_cache.len - 2; i >= 0; i -= 2)
        if (!strcmp(count_cache.data[i], name))
            return count_cache.data[i + 1];
    return NULL;
}

static bool counts_cstr(const char *name) {
    for (int i = 0; i < count_names.len; i++)
        if (!strcmp(count_names.data[i], name))
            return true;
    return false;
}

/* The room a template's text needs, its NUL included, as a C constant
   (#44): the parts and each value's longest text; a nested template
   counts its own room. For T.cstr() (#53), the size of T's text. */
static char *template_room(Expr *e) {
    Buf lits = {0}, bounds = {0};
    buf_puts(&lits, "");
    buf_puts(&bounds, "");
    if (e->kind == E_STRING) {
        for (int j = 0; j < e->items.len; j++)
            buf_printf(&lits, " %s", (char *)e->items.data[j]);
        return strfmt("sizeof%s", lits.buf);
    }
    for (int i = 0; i < e->items.len; i++) {
        Expr *x = e->items.data[i];
        if (x->kind == E_STRING) {
            for (int j = 0; j < x->items.len; j++)
                if (strcmp(x->items.data[j], "\"\""))
                    buf_printf(&lits, " %s", (char *)x->items.data[j]);
        } else if (x->kind == E_TEMPLATE) {
            buf_printf(&bounds, " + (%s - 1)", template_room(x));
        } else {
            buf_printf(&bounds, " + %s", template_bound(x));
        }
    }
    return strfmt("sizeof%s%s", lits.len ? lits.buf : " \"\"", bounds.buf);
}

/* the T.cstr() method that gives a struct's or union's text (#53), or NULL */
static Decl *text_method_of(const char *tag) {
    for (int i = 0; i < program->decls.len; i++) {
        Decl *d = program->decls.data[i];
        if (d->kind == D_FN && d->text_method && d->recv && !strcmp(d->recv->name, tag))
            return d;
    }
    return NULL;
}

static char *initializer(Expr *e) {
    if (e->kind != E_INIT)
        return expr(e);
    Buf b = {0};
    buf_puts(&b, "{");
    for (int i = 0; i < e->items.len; i++) {
        Expr *d = e->designators.data[i];
        buf_printf(&b, "%s%s%s%s", i ? ", " : "", d ? expr(d) : "", d ? " = " : "",
                   initializer(e->items.data[i]));
    }
    buf_puts(&b, "}");
    return b.buf;
}

/* ---------- statements ---------- */

static void stmt(Stmt *s);

/* t as C's const, for a let (#27): a let pointer is a const pointer (what
   it points to may change), and a let array has const elements */
static Type *const_type(Type *t) {
    Type *c = xcalloc(1, sizeof *c);
    *c = *t;
    if (t->kind == T_ARRAY)
        c->elem = const_type(t->elem);
    else
        c->is_const = true;
    return c;
}

static char *var_decl(const char *storage, Var *v) {
    /* an owner (#54): its block frees it (cleanup), it starts empty, and
       a let one is const to kelvinc only, as C's free takes it */
    const char *frees = text_bufs && !(storage && (!strcmp(storage, "static") || !strcmp(storage, "extern")))
                            ? owner_free(v->type)
                            : NULL;
    char *d = decl(v->is_let && !owner_free(v->type) ? const_type(v->type) : v->type, v->name);
    if (frees)
        d = strfmt("__attribute__((cleanup(%s))) %s", frees, d);
    if ((owner_free(v->type) || tagged_type(v->type)) && !v->init) /* an enum with values starts at its first case (#61) */
        return strfmt("%s%s%s = {0}", storage ? storage : "", storage ? " " : "", d);
    /* a reference declared without a value is nullptr (#20) */
    /* a v.type that C writes as __typeof__ is the type kelvinc saw (#34) */
    Type *seen = v->type->kind == T_TYPEOF && v->type->elem ? v->type->elem : v->type;
    /* [T](n) declares a zero-filled array (#49): = {0}, or, for a VLA,
       a memset after it (S_VAR) */
    bool compound = v->init && v->init->kind == E_COMPOUND && seen->kind == T_ARRAY;
    bool zeros = compound && !v->init->a;
    bool vla = zeros && seen->size && seen->size->kind != E_LITERAL;
    /* an array declared from ([T])[...] takes the list itself, as C has no
       array from a value */
    const char *init = vla                                                              ? NULL
                       : zeros                                                          ? "{0}"
                       : compound                                                       ? initializer(v->init->a)
                       : v->init                                                        ? initializer(v->init)
                       : (seen->kind == T_PTR || seen->kind == T_FUNC) && !(storage && !strcmp(storage, "extern")) ? "0"
                                                                                        : NULL;
    return strfmt("%s%s%s%s", storage ? storage : "", storage ? " " : "", d, init ? strfmt(" = %s", init) : "");
}

static void body(Stmt *s) {
    if (s->kind == S_BLOCK) {
        stmt(s);
        return;
    }
    indent++;
    stmt(s);
    indent--;
}

static void stmt(Stmt *s) {
    if (s->kind != S_BLOCK)
        sync(s->pos);
    switch (s->kind) {
    case S_BLOCK: {
        sync(s->pos);
        line("{");
        indent++;
        /* The statements are printed aside first, to collect the buffers
           of their text properties, which are then declared at the top of
           the block: the text lives until the block ends, like any local,
           also when it was made in a brace-less if or for body, or among
           a method call's arguments (a GNU statement expression) */
        List bufs = {0}, *outer_bufs = text_bufs, tmpls = {0}, *outer_tmpls = template_vars;
        Buf outer = out;
        int top = mapped_line;
        int caches = count_cache.len, owners = owner_locals.len;
        text_bufs = &bufs;
        template_vars = &tmpls;
        out = (Buf){0};
        for (int i = 0; i < param_caches.len; i++) /* a parameter's .count (#52) */
            line("%s", (char *)param_caches.data[i]);
        param_caches.len = 0;
        bool sw = s == switch_block, closed = sw && switch_closed, open = false;
        switch_block = NULL;
        Stmt *prev = NULL;
        for (int i = 0; i < s->stmts.len; i++) {
            Stmt *x = s->stmts.data[i];
            if (sw && (x->kind == S_CASE || x->kind == S_DEFAULT)) {
                /* a case is a block of its own (#63): its declarations are
                   its, and it ends with a break unless it jumps */
                if (open) {
                    if (!is_jump(prev))
                        line("break;");
                    indent--;
                    line("}");
                }
                stmt(x);
                line("{");
                indent++;
                open = true;
                prev = NULL;
                continue;
            }
            stmt(x);
            prev = x;
        }
        if (open) {
            if (!is_jump(prev))
                line("break;");
            indent--;
            line("}");
        }
        if (closed) {
            indent--;
            line("default:");
            indent++;
            line("__builtin_unreachable();");
        }
        count_cache.len = caches;
        owner_locals.len = owners;
        Buf items = out;
        out = outer;
        text_bufs = outer_bufs;
        template_vars = outer_tmpls;
        if (bufs.len || tmpls.len) {
            Buf names = {0};
            for (int i = 0; i < bufs.len; i++)
                buf_printf(&names, "%s%s", i ? ", " : "", (char *)bufs.data[i]);
            int end = mapped_line;
            mapped_line = top;
            if (bufs.len)
                line("uint8_t %s;", names.buf);
            /* templates' storage (#39, #44): no initializer, so a switch
               or goto may jump past it; unused where a macro drops the
               template, as assert does under NDEBUG */
            Buf tnames = {0};
            for (int i = 0; i < tmpls.len; i++)
                buf_printf(&tnames, "%s%s", i ? ", " : "", (char *)tmpls.data[i]);
            if (tmpls.len)
                line("__attribute__((unused)) char %s;", tnames.buf);
            if (top >= 0) { /* the statements were printed to start at line top */
                mapped_line = -1;
                sync((Pos){s->pos.file, top, 0});
            }
            mapped_line = end;
        }
        if (items.len)
            buf_putn(&out, items.buf, items.len);
        indent--;
        line("}");
        break;
    }
    case S_VAR:
        for (int i = 0; i < s->vars.len; i++) {
            Var *v = s->vars.data[i];
            sync(v->pos);
            line("%s;", var_decl(s->storage, v));
            if (owner_free(v->type) && !(s->storage && !strcmp(s->storage, "static"))) {
                list_push(&owner_locals, v->name);
                list_push(&owner_locals, v->type);
            }
            Type *t = v->type->kind == T_TYPEOF && v->type->elem ? v->type->elem : v->type;
            if (t->kind == T_PTR && t->cstr && counts_cstr(v->name)) { /* its .count, once measured (#52) */
                char *cache = hidden(v->name, "count");
                line("size_t %s = (size_t)-1;", cache);
                list_push(&count_cache, v->name);
                list_push(&count_cache, cache);
            }
            if (v->init && v->init->kind == E_COMPOUND && !v->init->a && t->kind == T_ARRAY && t->size &&
                t->size->kind != E_LITERAL) /* a VLA of [T](n) is zero-filled here (#49) */
                line("memset(%s, 0, sizeof %s);", v->name, v->name);
        }
        break;
    case S_EXPR:
        /* a && f(); or c ? f() : g(); as a statement: its value is
           discarded, so it needs no bool, which clang would call unused */
        if (s->expr->kind == E_BINARY && (!strcmp(s->expr->op, "&&") || !strcmp(s->expr->op, "||")))
            line("%s;", cond(s->expr));
        else if (s->expr->kind == E_TERNARY && !s->expr->paren)
            line("%s ? %s : %s;", cond(s->expr->a), expr(s->expr->b), expr(s->expr->c));
        else if (s->expr->kind == E_BINARY && !strcmp(s->expr->op, "=") && owner_assign(s->expr))
            ; /* an owner took a value, and freed what it held (#54) */
        else
            line("%s;", expr(s->expr));
        /* a cstr assigned anew is measured again (#52) */
        if (s->expr->kind == E_BINARY && !strcmp(s->expr->op, ":=") && s->expr->a->kind == E_IDENT &&
            count_cache_of(s->expr->a->text))
            line("%s = (size_t)-1;", count_cache_of(s->expr->a->text));
        break;
    case S_EMPTY:
        line(";");
        break;
    case S_IF:
        line("if (%s)", stmt_cond(s->expr));
        body(s->body);
        if (s->els) {
            sync(s->els->pos);
            line("else");
            body(s->els);
        }
        break;
    case S_WHILE:
        line("while (%s)", stmt_cond(s->expr));
        body(s->body);
        break;
    case S_DO:
        line("do");
        body(s->body);
        line("while (%s);", stmt_cond(s->expr));
        break;
    case S_FOR: {
        char *init = "";
        bool wrap = false;
        if (s->init && s->init->kind == S_EXPR) {
            init = expr(s->init->expr);
        } else if (s->init && s->init->vars.len == 1) {
            init = var_decl(NULL, s->init->vars.data[0]);
        } else if (s->init) {
            /* C allows only one base type per declaration, so declare
               several loop variables in an enclosing block */
            wrap = true;
            line("{");
            indent++;
            for (int i = 0; i < s->init->vars.len; i++)
                line("%s;", var_decl(NULL, s->init->vars.data[i]));
        }
        line("for (%s; %s; %s)", init, s->expr ? stmt_cond(s->expr) : "", s->step ? expr(s->step) : "");
        body(s->body);
        if (wrap) {
            indent--;
            line("}");
        }
        break;
    }
    case S_FOR_IN: {
        /* for i in a..<b: the bounds are evaluated once, and i is a const
           copy of the counter. a...b stops at b without stepping past
           it, so 0...255 as a u8 ends (#28). */
        const char *v = strcmp(s->name, "_") ? s->name : NULL;
        char *i = hidden(v, "count"), *end = hidden(v, "end"), *go = s->closed ? hidden(v, "go") : NULL;
        char *lo = expr(s->expr), *hi = expr(s->step);
        if (s->closed)
            line("for (%s = %s, %s = %s, %s = %s <= %s; %s; %s = %s != %s, %s += %s)", decl(s->type, i), lo, end,
                 hi, go, i, end, go, go, i, end, i, go);
        else
            line("for (%s = %s, %s = %s; %s < %s; %s++)", decl(s->type, i), lo, end, hi, i, end, i);
        line("{");
        indent++;
        if (strcmp(s->name, "_")) /* for _ in 0..<n names no variable */
            line("%s = %s;", decl(const_type(s->type), s->name), i);
        stmt(s->body);
        indent--;
        line("}");
        break;
    }
    case S_FOR_EACH: {
        /* for x in s (#30): s is evaluated once, into a hidden pointer that
           only reads; x is a const copy of each element, or for a list a
           const copy of each node's pointer, taken before the body runs so
           that the body may free the node. The hidden lines map to the
           for's line, where C's warnings about them belong. */
        const char *v = strcmp(s->name, "_") ? s->name : NULL;
        char *p = hidden(v, "ptr"), *end = NULL, *arr = NULL; /* end and arr name only what an array uses */
        char *seq = expr(s->expr);
        if (s->each == EACH_DICT) { /* the entries of a Dictionary, in order (#65) */
            char *d = hidden(v, "dict"), *i = hidden(v, "i");
            line("{");
            indent++;
            sync(s->pos);
            line("__auto_type %s = &(%s);", d, seq);
            sync(s->pos);
            line("for (size_t %s = 0; %s < %s->len; %s++)", i, i, d, i);
            line("{");
            indent++;
            line("if (!%s->at[%s].live)", d, i);
            line("    continue;");
            sync(s->pos);
            if (v) /* unused: a body may read the value alone, or the key alone */
                line("__attribute__((unused)) %s = %s->at[%s].key;", decl(const_type(s->type), v), d, i);
            if (s->name2 && strcmp(s->name2, "_"))
                line("__attribute__((unused)) %s = %s->at[%s].value;", decl(const_type(s->elem), s->name2), d, i);
            stmt(s->body);
            indent--;
            line("}");
            indent--;
            line("}");
            break;
        }
        Type *reader = NULL; /* const E^, for the elements; NULL: unseen */
        if (s->elem && s->each != EACH_LIST) {
            reader = xcalloc(1, sizeof *reader);
            reader->kind = T_PTR;
            reader->pos = s->elem->pos;
            reader->elem = const_type(s->elem);
        }
        if (s->from_argv) /* char ** in C, u8^^ in Kelvin */
            seq = strfmt("(%s)(%s)", decl(reader, ""), seq);
        bool wrap = s->each == EACH_ARRAY || s->each == EACH_RECORDS;
        if (s->each == EACH_BYTES) { /* a Bytes's count bytes (#54) */
            end = hidden(v, "end");
            line("{");
            indent++;
            sync(s->pos);
            line("%s = (%s).at;", decl(reader, p), seq);
            sync(s->pos);
            line("%s = %s + (%s).count;", decl(const_type(reader), end), p, seq);
            sync(s->pos);
            line("for (; %s < %s; %s++)", p, end, p);
            wrap = true;
        } else if (s->each == EACH_STRING) { /* a String's codepoints (#55), decoded as it goes */
            end = hidden(v, "end");
            line("{");
            indent++;
            sync(s->pos);
            line("const uint8_t *%s = (%s).b.at;", p, seq);
            sync(s->pos);
            line("const uint8_t *const %s = %s + (%s).b.count;", end, p, seq);
            sync(s->pos);
            line("for (; %s < %s; )", p, end);
            wrap = true;
        } else if (s->each == EACH_LIST) {
            Type *node = xcalloc(1, sizeof *node);
            *node = *s->elem;
            node->is_const = false;
            line("for (%s = %s; %s != 0; )", decl(node, p), seq, p);
        } else if (!reader) {
            line("for (__auto_type %s = %s; %s != 0 && *%s != 0; %s++)", p, seq, p, p, p);
        } else if (s->each == EACH_POINTER) {
            line("for (%s = %s; %s != 0 && *%s != 0; %s++)", decl(reader, p), seq, p, p, p);
        } else {
            /* an array: its length is known; elements up to it */
            end = hidden(v, "end");
            line("{");
            indent++;
            if (s->step) { /* a let array parameter: a pointer in C */
                sync(s->pos);
                line("%s = %s;", decl(reader, p), seq);
                sync(s->pos);
                line("%s = %s + (%s);", decl(const_type(reader), end), p, expr(s->step));
            } else {
                /* through a pointer to the array, so that s is evaluated
                   once even when sizeof would evaluate it again, as for a
                   row of a variable length array */
                arr = hidden(v, "array");
                sync(s->pos);
                line("__auto_type %s = &(%s);", arr, seq);
                sync(s->pos);
                line("%s = *%s;", decl(reader, p), arr);
                sync(s->pos);
                line("%s = %s + sizeof(*%s) / sizeof((*%s)[0]);", decl(const_type(reader), end), p, arr, arr);
            }
            sync(s->pos);
            line("for (; %s < %s%s; %s++)", p, end, s->each == EACH_ARRAY ? strfmt(" && *%s != 0", p) : "", p);
        }
        sync(s->pos);
        line("{");
        indent++;
        sync(s->pos);
        if (s->each == EACH_STRING) /* the codepoint, decoded, moves p (#55, #56) */
            line(strcmp(s->name, "_") ? "%s = (kv_uchr){kv_utf8_next(&%s)};" : "kv_utf8_next(&%s);",
                 strcmp(s->name, "_") ? decl(const_type(s->type), s->name) : p, p);
        else if (!strcmp(s->name, "_"))
            ; /* for _ in s names no variable */
        else if (s->each == EACH_LIST)
            line("%s = %s;", decl(const_type(s->type), s->name), p);
        else if (s->type)
            line("%s = *%s;", decl(const_type(s->type), s->name), p);
        else
            line("const __typeof__(*%s) %s = *%s;", p, s->name, p);
        if (s->each == EACH_LIST) {
            sync(s->pos);
            line("%s = %s->next;", p, p);
        }
        stmt(s->body);
        indent--;
        line("}");
        if (wrap) {
            indent--;
            line("}");
        }
        break;
    }
    case S_SWITCH:
        line("switch (%s)", expr(s->expr));
        switch_block = s->body;
        switch_closed = s->closed;
        body(s->body);
        break;
    case S_CASE:
        indent--;
        for (Stmt *c = s; c; c = c->els) /* case a, b: (#63) */
            line("case %s:%s", expr(c->expr), c->name ? strfmt(" /* %s */", c->name) : "");
        indent++;
        break;
    case S_DEFAULT:
        indent--;
        line("default:");
        indent++;
        break;
    case S_BREAK:
        line("break;");
        break;
    case S_CONTINUE:
        line("continue;");
        break;
    case S_RETURN:
        if (s->expr && local_owner(s->expr)) /* an owner moves out (#54) */
            line("return %s(&%s);", owner_take(local_owner_type(s->expr->text)), c_name(s->expr->text));
        else if (s->expr)
            line("return %s;", expr(s->expr));
        else
            line("return;");
        break;
    case S_GOTO:
        line("goto %s;", s->name);
        break;
    case S_LABEL:
        indent--;
        line("%s:", s->name);
        indent++;
        stmt(s->body);
        break;
    }
}

/* ---------- declarations ---------- */

/* point.area is the C function point__area, f64.half f64__half */
static char *method_cname(Decl *d) { return strfmt("%s__%s", d->recv_name, d->name); }

static void register_method(const char *method, Type *recv, const char *fn) {
    char *ctype = decl(recv, "");
    for (int i = 0; i < methods.len; i++) {
        Method *m = methods.data[i];
        if (!strcmp(m->method, method) && !strcmp(m->ctype, ctype))
            return;
        if (!strcmp(m->fn, fn))
            error_at(recv->pos, "the method %s.%s() would have the same C name, %s, as another method", ctype, method,
                     fn);
    }
    Method *m = xcalloc(1, sizeof *m);
    m->method = method;
    m->ctype = ctype;
    m->fn = fn;
    list_push(&methods, m);
}

static char *fn_head(Decl *d) {
    Buf params = {0};
    if (d->recv)
        buf_puts(&params, decl(d->recv, "self"));
    for (int i = 0; i < d->params.len; i++) {
        Var *p = d->params.data[i];
        /* a let parameter is const where the function is defined (#27),
           and an array parameter is the pointer C makes of it */
        Type *t = p->type;
        /* a C typedef kelvinc cannot see may be an array, such as jmp_buf,
           whose const would reach its elements: kelvinc checks those lets */
        bool hidden = (t->kind == T_BASE && !strcmp(c_type_name(t->name), t->name) && strcmp(t->name, "bool") &&
                       strncmp(t->name, "struct ", 7) && strncmp(t->name, "union ", 6) &&
                       strncmp(t->name, "enum ", 5)) ||
                      t->kind == T_TYPEOF;
        bool let = p->is_let && d->body && !hidden;
        /* an anonymous function's prototype says the same as its
           definition, with no length that would need a name (#32) */
        if (let || (d->anon && t->kind == T_ARRAY)) {
            if (t->kind == T_ARRAY) {
                Type *ptr = xcalloc(1, sizeof *ptr);
                ptr->kind = T_PTR;
                ptr->pos = t->pos;
                ptr->elem = t->elem;
                t = ptr;
            }
            if (let)
                t = const_type(t);
        }
        /* C insists that main's argv is char **; Kelvin writes it u8^^ */
        bool argv = !d->recv && !strcmp(d->name, "main") && i == 1;
        const char *argv_c = p->is_let && d->body ? "char **const %s" : "char **%s";
        /* $0, $1, ... (#32): the body need not use each one */
        const char *unused = p->name[0] == '$' ? "__attribute__((unused)) " : "";
        /* an owner comes in by value and moves into a local (#54) */
        const char *pname = owner_free(p->type) && d->body ? strfmt("_kv_%s_in", c_name(p->name)) : c_name(p->name);
        if (owner_free(p->type))
            t = p->type;
        buf_printf(&params, "%s%s%s", params.len ? ", " : "", unused, argv ? strfmt(argv_c, p->name) : decl(t, pname));
    }
    if (d->variadic)
        buf_puts(&params, ", ...");
    /* Kelvin's `()` means no parameters, which C spells `(void)` */
    char *inner = strfmt("%s(%s)", d->recv ? method_cname(d) : d->cname ? d->cname : d->name,
                         params.len ? params.buf : "void");
    char *head = d->ret ? decl(d->ret, inner) : strfmt("void %s", inner);
    /* an anonymous function used only where C does not evaluate, as in
       sizeof, is never emitted, which C need not mention (#32) */
    /* an operator's value is what it is for, so C warns where a statement
       drops it, as it does for `n == 2;` (#42) */
    return strfmt("%s%s%s%s%s", d->anon ? "__attribute__((unused)) " : "",
                  d->op ? "__attribute__((warn_unused_result)) " : "", d->storage ? d->storage : "",
                  d->storage ? " " : "", head);
}

/* Is `name` ("struct point") a struct or union with a body in this file? */
static Decl *kelvin_record(const char *name) {
    for (int i = 0; i < program->decls.len; i++) {
        Decl *d = program->decls.data[i];
        if ((d->kind == D_STRUCT || d->kind == D_UNION) && d->has_body &&
            !strcmp(name, strfmt("%s %s", d->kind == D_STRUCT ? "struct" : "union", d->name)))
            return d;
    }
    return NULL;
}

/* ---------- the derived text of structs: x.cstr (#22) ---------- */

/* How a pointer member is written: 's' u8^ and i8^ are text; 'a' other
   pointers kelvinc knows are addresses, as is a pointer to volatile
   bytes, as .cstr of one is (_Generic lists only plain and const
   strings); '?' a pointer to a C typedef (xmlChar^, uint8_t^) is text or
   an address as C decides */
static char pointer_kind(Type *t) {
    Type *e = t->elem;
    if (e->kind != T_BASE || e->is_volatile)
        return 'a';
    const char *n = e->name;
    if (!strcmp(n, "u8") || !strcmp(n, "i8"))
        return 's';
    bool kelvin = strcmp(c_type_name(n), n) || !strcmp(n, "bool") || !strncmp(n, "struct ", 7) ||
                  !strncmp(n, "union ", 6) || !strncmp(n, "enum ", 5);
    return kelvin ? 'a' : '?';
}

/* the longest text of a value of type t, as a C constant expression; `lv`
   names such a value inside sizeof, for the length of an array */
static char *text_bound(Type *t, const char *lv) {
    if (t->kind == T_FUNC)
        return "(sizeof(void *) * 2 + 2)";
    if (t->kind == T_PTR)
        return pointer_kind(t) == 'a' ? "(sizeof(void *) * 2 + 2)" : "KV_CSTR_STR";
    if (t->kind == T_ARRAY) {
        if (!t->size)
            return "5"; /* [...]: a flexible array member */
        /* [a, b]: brackets, and each element with ", " */
        return strfmt("(sizeof(%s) / sizeof((%s)[0]) * (%s + 2) + 2)", lv, lv,
                      text_bound(t->elem, strfmt("(%s)[0]", lv)));
    }
    static const struct { const char *type, *bound; } scalars[] = {
        {"i8", "4"},    {"u8", "3"},    {"i16", "6"},   {"u16", "5"},   {"i32", "11"},
        {"u32", "10"},  {"i64", "20"},  {"u64", "20"},  {"i128", "40"}, {"u128", "39"},
        {"f32", "15"},  {"f64", "24"},  {"bool", "5"},  {"uchr", "4"},
        {"f32 _Complex", "31"},         {"f64 _Complex", "49"},
    };
    for (size_t i = 0; i < sizeof scalars / sizeof scalars[0]; i++)
        if (!strcmp(t->name, scalars[i].type))
            return (char *)scalars[i].bound;
    Decl *r = kelvin_record(t->name);
    if (r)
        return strfmt("(_kv_%s_cstr_size - 1)", r->name);
    return "(KV_CSTR_SCALAR - 1)"; /* a C typedef, a C struct, an enum: kv_cstr_any */
}

/* Is a template's value x a byte array, u8[16] or i8[n]: its text is the
   bytes up to a NUL or its end, never past it, as a char array member's in
   .cstr (P35) */
static bool byte_array(Expr *x) {
    Type *t = x->shown;
    return t && t->kind == T_ARRAY && pointer_kind(t) == 's';
}

/* The longest text of a template's value x, as print shows it (#39, #44),
   a C constant: a nested template's storage, a struct's text size, a
   property's buffer, a byte array's length up to KV_TEMPLATE_STR, or by
   the type kelvinc reckons it by (x->shown); KV_TEMPLATE_STR, at least
   64 and so longer than any number's text, for strings and for what
   kelvinc cannot see. For numbers, KV_TEMPLATE_VALUE checks it against
   the type C sees. */
static const char *template_bound(Expr *x) {
    if (x->kind == E_TEMPLATE)
        return strfmt("(sizeof %s - 1)", x->text);
    if (x->kind == E_STRING) {
        Buf b = {0};
        for (int i = 0; i < x->items.len; i++)
            buf_printf(&b, " %s", (char *)x->items.data[i]);
        return strfmt("(sizeof%s - 1)", b.buf);
    }
    if (x->kind == E_TERNARY && !x->shown) {
        /* the longer of two texts, each named once, so that a chain of ?:
           stays as long as it is written */
        const char *b = template_bound(x->b), *c = template_bound(x->c);
        return strcmp(b, c) ? strfmt("(sizeof (union { char a[%s + 1]; char b[%s + 1]; }) - 1)", b, c) : b;
    }
    if (x->kind == E_PROPERTY) {
        const char *p = x->text;
        Decl *r = !strcmp(p, "cstr") && x->type ? kelvin_record(x->type->name) : NULL;
        if (r)
            return strfmt("(_kv_%s_cstr_size - 1)", r->name);
        if (!strcmp(p, "dec") || !strcmp(p, "hex") || !strcmp(p, "oct") || !strcmp(p, "bin"))
            return strfmt("(%s - 1)", number_text_size(p));
        if (!strcmp(p, "size") || !strcmp(p, "addr") || !strcmp(p, "count"))
            return "20";
        /* .cstr of a string is the string; .typename */
        if (strcmp(p, "next") && strcmp(p, "prev"))
            return "KV_TEMPLATE_STR";
    }
    Type *t = x->shown;
    if (!t)
        return "KV_TEMPLATE_STR";
    if (byte_array(x)) /* a longer one is cut as a string is */
        return t->size && t->size->kind == E_LITERAL
                   ? strfmt("(%s < KV_TEMPLATE_STR ? %s : KV_TEMPLATE_STR)", t->size->text, t->size->text)
                   : "KV_TEMPLATE_STR";
    if (t->kind == T_PTR || t->kind == T_ARRAY)
        return pointer_kind(t) == 'a' ? "(sizeof(void *) * 2 + 2)" : "KV_TEMPLATE_STR";
    if (t->kind != T_BASE)
        return "KV_TEMPLATE_STR";
    static const struct { const char *type, *bound; } numbers[] = {
        {"i8", "4"},   {"u8", "3"},   {"i16", "6"},   {"u16", "5"},    {"i32", "11"}, {"u32", "10"}, {"i64", "20"},
        {"u64", "20"}, {"i128", "40"}, {"u128", "39"}, {"f32", "15"}, {"f64", "24"}, {"bool", "5"}, {"uchr", "4"},
    };
    for (size_t i = 0; i < sizeof numbers / sizeof numbers[0]; i++)
        if (!strcmp(t->name, numbers[i].type))
            return numbers[i].bound;
    if (!strncmp(t->name, "enum ", 5)) /* gcc gives an enum beyond 64 bits an __int128 type */
        return "40";
    return "KV_TEMPLATE_STR";
}

/* a C expression that writes the text of `lv` (type t, not an array) at p
   and gives the end */
static char *text_writer(Type *t, const char *lv) {
    if (t->kind == T_BASE && !strcmp(t->name, "Bytes")) /* a Bytes member (#54): its bytes, cut as a string is */
        return strfmt("kv_cstr_end(kv_cstr_bytes(%s, _kv_p))", lv);
    if (t->kind == T_BASE && !strcmp(t->name, "String")) /* a String member (#55) */
        return strfmt("kv_cstr_end(kv_cstr_string(%s, _kv_p))", lv);
    /* a function's address: ISO C converts it to an integer, not to a
       data pointer */
    if (t->kind == T_FUNC)
        return strfmt("kv_cstr_put_address(_kv_p, (const void *)(uintptr_t)%s)", lv);
    if (t->kind == T_PTR) {
        char k = pointer_kind(t);
        return k == 's'   ? strfmt("kv_cstr_put_str(_kv_p, (const char *)%s)", lv)
               : k == 'a' ? strfmt("kv_cstr_put_address(_kv_p, %s)", lv)
                          : strfmt("kv_cstr_put_pointer(_kv_p, %s)", lv);
    }
    static const struct { const char *type, *fn; } direct[] = {
        {"i8", "kv_cstr_i64"},    {"i16", "kv_cstr_i64"},  {"i32", "kv_cstr_i64"},  {"i64", "kv_cstr_i64"},
        {"u8", "kv_cstr_u64"},    {"u16", "kv_cstr_u64"},  {"u32", "kv_cstr_u64"},  {"u64", "kv_cstr_u64"},
        {"i128", "kv_cstr_i128"}, {"u128", "kv_cstr_u128"}, {"f32", "kv_cstr_f32"}, {"f64", "kv_cstr_f64"},
        {"bool", "kv_cstr_bool"}, {"f32 _Complex", "kv_cstr_cf"}, {"f64 _Complex", "kv_cstr_cd"},
    };
    for (size_t i = 0; i < sizeof direct / sizeof direct[0]; i++)
        if (!strcmp(t->name, direct[i].type))
            return strfmt("kv_cstr_end(%s(%s, _kv_p))", direct[i].fn, lv);
    Decl *r = kelvin_record(t->name);
    if (r)
        return strfmt("kv_cstr_end(_kv_%s_cstr(%s, _kv_p))", r->name, lv);
    /* a C typedef, a C struct, an enum: decided by the C compiler */
    return strfmt("kv_cstr_end(kv_cstr_any(%s, _kv_p))", lv);
}

/* write the text of `lv` (type t) at p; arrays are [a, b] */
static void write_text(Type *t, const char *lv, int depth) {
    if (t->kind != T_ARRAY) {
        line("_kv_p = %s;", text_writer(t, lv));
        return;
    }
    if (!t->size) {
        line("_kv_p = kv_cstr_put(_kv_p, \"[...]\");"); /* a flexible array member */
        return;
    }
    char *i = strfmt("_kv_i%d", depth);
    line("_kv_p = kv_cstr_put(_kv_p, \"[\");");
    line("for (size_t %s = 0; %s < sizeof %s / sizeof %s[0]; %s++)", i, i, lv, lv, i);
    line("{");
    indent++;
    line("if (%s)", i);
    line("    _kv_p = kv_cstr_put(_kv_p, \", \");");
    write_text(t->elem, strfmt("%s[%s]", lv, i), depth + 1);
    indent--;
    line("}");
    line("_kv_p = kv_cstr_put(_kv_p, \"]\");");
}

/* ---------- which structs need a derived .cstr ---------- */

static bool is_cstr_used(const char *name) {
    for (int i = 0; i < cstr_used.len; i++)
        if (!strcmp(cstr_used.data[i], name))
            return true;
    return false;
}

/* mark a record, and the records among its members, arrays included */
static void use_cstr(Decl *r) {
    if (!r || is_cstr_used(r->name))
        return;
    list_push(&cstr_used, r->name);
    for (int i = 0; r->kind == D_STRUCT && i < r->members.len; i++) {
        Type *t = ((Var *)r->members.data[i])->type;
        if (!t)
            continue; /* a case with no value (#61) */
        while (t->kind == T_ARRAY)
            t = t->elem;
        if (t->kind == T_BASE)
            use_cstr(kelvin_record(t->name));
    }
}

/* the names whose .count a function asks for, as a cstr's (#52) */
static void find_counts_stmt(Stmt *s);
static void find_counts_expr(Expr *e) {
    if (!e)
        return;
    if (e->kind == E_PROPERTY && !strcmp(e->text, "count") && e->op && !strcmp(e->op, "cstr") &&
        e->a->kind == E_IDENT)
        list_push(&count_names, e->a->text);
    find_counts_expr(e->a);
    find_counts_expr(e->b);
    find_counts_expr(e->c);
    if (e->kind == E_CALL || e->kind == E_METHOD || e->kind == E_INIT || e->kind == E_TEMPLATE)
        for (int i = 0; i < e->items.len; i++)
            find_counts_expr(e->items.data[i]);
}

static void find_counts_stmt(Stmt *s) {
    if (!s)
        return;
    for (int i = 0; i < s->stmts.len; i++)
        find_counts_stmt(s->stmts.data[i]);
    for (int i = 0; i < s->vars.len; i++)
        find_counts_expr(((Var *)s->vars.data[i])->init);
    find_counts_expr(s->expr);
    find_counts_expr(s->step);
    find_counts_stmt(s->init);
    find_counts_stmt(s->body);
    find_counts_stmt(s->els);
}

static void find_cstr_stmt(Stmt *s);

static void find_cstr_expr(Expr *e) {
    if (!e)
        return;
    if (e->kind == E_PROPERTY && !strcmp(e->text, "cstr") && e->type)
        use_cstr(kelvin_record(e->type->name));
    find_cstr_expr(e->a);
    find_cstr_expr(e->b);
    find_cstr_expr(e->c);
    if (e->kind == E_CALL || e->kind == E_METHOD || e->kind == E_INIT || e->kind == E_TEMPLATE)
        for (int i = 0; i < e->items.len; i++)
            find_cstr_expr(e->items.data[i]);
}

static void find_cstr_stmt(Stmt *s) {
    if (!s)
        return;
    for (int i = 0; i < s->stmts.len; i++)
        find_cstr_stmt(s->stmts.data[i]);
    for (int i = 0; i < s->vars.len; i++)
        find_cstr_expr(((Var *)s->vars.data[i])->init);
    find_cstr_expr(s->expr);
    find_cstr_expr(s->step);
    find_cstr_stmt(s->init);
    find_cstr_stmt(s->body);
    find_cstr_stmt(s->els);
}

/* The derived text of a struct, {x: 1, y: 2}, and its size: a union,
   whose active member is unknown, is <union name>. */
static void emit_derived_cstr(Decl *d, Type *recv) {
    pinned_line = d->pos;
    char *ctype = decl(recv, "");
    Buf size = {0};
    if (d->tagged) {
        /* an enum with values (#61): the case's name, and its value in
           parentheses: n(1.5), none; room for the longest */
        buf_printf(&size, "1");
        for (int i = 0; i < d->members.len; i++) {
            Var *m = d->members.data[i];
            buf_printf(&size, " + %d", (int)strlen(m->name) + 2);
            if (m->type)
                buf_printf(&size, " + %s", text_bound(m->type, strfmt("((%s *)0)->u.%s", ctype, m->name)));
        }
        line("enum { _kv_%s_cstr_size = %s };", d->name, size.buf);
        line("__attribute__((unused)) static inline uint8_t *_kv_%s_cstr(%s, uint8_t *_kv_buf)", d->name, decl(recv, "self"));
        line("{");
        indent++;
        line("uint8_t *_kv_p = _kv_buf;");
        line("switch (self.tag)");
        line("{");
        for (int i = 0; i < d->members.len; i++) {
            Var *m = d->members.data[i];
            line("case %d:", i);
            indent++;
            line("_kv_p = kv_cstr_put(_kv_p, \"%s%s\");", m->name, m->type ? "(" : "");
            if (m->type) {
                write_text(m->type, strfmt("self.u.%s", m->name), 0);
                line("_kv_p = kv_cstr_put(_kv_p, \")\");");
            }
            line("break;");
            indent--;
        }
        line("default: kv_cstr_put(_kv_p, \"?\"); break;");
        line("}");
        line("return _kv_buf;");
        indent--;
        line("}");
        pinned_line.file = NULL;
        mapped_line = -1;
        return;
    }
    if (d->kind == D_UNION) {
        buf_printf(&size, "%d", (int)strlen(d->spelling ? d->spelling : d->name) + 9);
    } else {
        int fixed = 3; /* {, } and the NUL */
        for (int i = 0; i < d->members.len; i++) {
            Var *m = d->members.data[i];
            fixed += (i ? 2 : 0) + (int)strlen(m->name) + 2;
        }
        buf_printf(&size, "%d", fixed);
        for (int i = 0; i < d->members.len; i++) {
            Var *m = d->members.data[i];
            buf_printf(&size, " + %s", text_bound(m->type, strfmt("((%s *)0)->%s", ctype, m->name)));
        }
    }
    line("enum { _kv_%s_cstr_size = %s };", d->name, size.buf);
    /* unused is a GNU attribute, like the statement expressions (P31) */
    line("__attribute__((unused)) static inline uint8_t *_kv_%s_cstr(%s, uint8_t *_kv_buf)", d->name, decl(recv, "self"));
    line("{");
    indent++;
    if (d->kind == D_UNION) {
        line("(void)self;");
        line("kv_cstr_put(_kv_buf, \"<%s>\");", d->spelling ? d->spelling : strfmt("union %s", d->name));
    } else {
        line("uint8_t *_kv_p = _kv_buf;");
        line("_kv_p = kv_cstr_put(_kv_p, \"{\");");
        for (int i = 0; i < d->members.len; i++) {
            Var *m = d->members.data[i];
            line("_kv_p = kv_cstr_put(_kv_p, \"%s%s: \");", i ? ", " : "", m->name);
            write_text(m->type, strfmt("self.%s", m->name), 0);
        }
        line("kv_cstr_put(_kv_p, \"}\");");
    }
    line("return _kv_buf;");
    indent--;
    line("}");
    pinned_line.file = NULL;
    mapped_line = -1;
}

/* the Array<T> types first used by top-level decl i (#57): their C, once */
/* Is t the struct or union that d declares? Its Array's functions then
   follow d, as they need the element complete (#61) */
static bool declares_elem(Decl *d, Type *t) {
    if (!d || (d->kind != D_STRUCT && d->kind != D_UNION) || !d->name || !t || t->kind != T_BASE)
        return false;
    return !strcmp(t->name, strfmt("%s %s", d->kind == D_STRUCT ? "struct" : "union", d->name));
}

static bool is_dict(Type *t) { return t->cname && !strncmp(t->cname, "_kv_dict_", 9); }

/* the arguments of KV_DICT (#65): the key kept and given, the value, the
   C name, and the key's hash, equality, storing and missing-key
   functions, by its kind, with the free and copy of what owns */
static char *dict_args(Type *t) {
    bool text = !strcmp(t->key->name, "String");
    const char *vf = owner_free(t->elem);
    return strfmt("%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s", decl(t->key, ""),
                  text ? "const uint8_t *" : decl(t->key, ""), decl(t->elem, ""), t->cname,
                  text ? "KV_HASH_TEXT" : "KV_HASH_INT", text ? "KV_EQ_TEXT" : "KV_EQ_INT",
                  text ? "KV_STORE_TEXT" : "KV_STORE_INT", text ? "KV_MISSING_TEXT" : "KV_MISSING_INT",
                  text ? "kv_string_free" : "KV_PLAIN_FREE", text ? "kv_string_copy" : "KV_PLAIN_COPY",
                  vf ? vf : "KV_PLAIN_FREE", vf ? owner_copy(t->elem) : "KV_PLAIN_COPY");
}

static void emit_array_funcs(Type *t) {
    if (is_dict(t)) {
        line("KV_DICT_FUNCS(%s)", dict_args(t));
        return;
    }
    const char *f = owner_free(t->elem); /* an element that owns is freed and copied with it */
    line("KV_ARRAY_FUNCS(%s, %s, %s, %s)", decl(t->elem, ""), t->cname, f ? f : "KV_PLAIN_FREE",
         f ? owner_copy(t->elem) : "KV_PLAIN_COPY");
}

/* d.keys and d.values (#66): an Array of copies, by a function after the
   Dictionary's and the Array's C */
static void emit_views_before(int i) {
    for (int k = 0; k < program->views.len; k++) {
        DictView *v = program->views.data[k];
        if (v->decl != i)
            continue;
        bool text = !strcmp(v->dict->key->name, "String");
        const char *copy = v->keys ? (text ? "kv_string_copy" : "KV_PLAIN_COPY")
                                   : (owner_copy(v->dict->elem) ? owner_copy(v->dict->elem) : "KV_PLAIN_COPY");
        line("__attribute__((unused)) static inline %s %s_%s(const %s *d)", v->arr->cname, v->dict->cname,
             v->keys ? "keys" : "values", v->dict->cname);
        line("{");
        indent++;
        line("%s v = {0};", v->arr->cname);
        line("%s_reserve(&v, d->count);", v->arr->cname);
        line("for (size_t i = 0; i < d->len; i++)");
        indent++;
        line("if (d->at[i].live)");
        line("    v.at[v.count++] = %s(&d->at[i].%s);", copy, v->keys ? "key" : "value");
        indent--;
        line("return v;");
        indent--;
        line("}");
    }
}

static void emit_arrays_before(int i) {
    Decl *d = program->decls.data[i];
    for (int k = 0; k < program->arrays.len; k++) {
        if ((int)(intptr_t)program->array_decls.data[k] != i)
            continue;
        Type *t = program->arrays.data[k];
        if (declares_elem(d, t->elem)) { /* the functions follow the element's declaration */
            if (is_dict(t))
                line("KV_DICT_TYPE(%s)", t->cname);
            else
                line("KV_ARRAY_TYPE(%s, %s)", decl(t->elem, ""), t->cname);
            continue;
        }
        if (is_dict(t)) { /* a Dictionary (#65) */
            line("KV_DICT(%s)", dict_args(t));
            continue;
        }
        const char *f = owner_free(t->elem); /* an element that owns is freed and copied with it */
        line("KV_ARRAY(%s, %s, %s, %s)", decl(t->elem, ""), t->cname, f ? f : "KV_PLAIN_FREE",
             f ? owner_copy(t->elem) : "KV_PLAIN_COPY");
    }
}

/* after the struct d declares: the functions of the Arrays of it, with
   the prototypes of its own free and copy, which they call */
static void emit_arrays_after(Decl *d) {
    bool any = false;
    for (int k = 0; k < program->arrays.len; k++) {
        Type *t = program->arrays.data[k];
        if ((int)(intptr_t)program->array_decls.data[k] != cur_decl || !declares_elem(d, t->elem))
            continue;
        if (!any && owner_free(t->elem)) {
            line("__attribute__((unused)) static inline void _kv_%s_free(%s *self);", d->name, decl(t->elem, ""));
            line("__attribute__((unused)) static inline %s _kv_%s_copy(const %s *self);", decl(t->elem, ""), d->name,
                 decl(t->elem, ""));
        }
        any = true;
        emit_array_funcs(t);
    }
}

/* the derived copy of a struct that owns (#61): each member that owns
   is copied, the rest with the bytes */
static void emit_derived_copy(Decl *d, Type *recv) {
    line("__attribute__((unused)) static inline %s _kv_%s_copy(const %s *self)", decl(recv, ""), d->name, decl(recv, ""));
    line("{");
    indent++;
    line("%s _kv_v = *self;", decl(recv, ""));
    for (int i = 0; i < d->members.len; i++) {
        Var *m = d->members.data[i];
        const char *f = m->type ? owner_copy(m->type) : NULL;
        if (f) {
            line("_kv_v.%s = %s(&self->%s);", m->name, f, m->name);
        } else if (m->type && m->type->kind == T_ARRAY && (f = owner_copy(m->type->elem))) {
            line("for (size_t _kv_i = 0; _kv_i < sizeof self->%s / sizeof self->%s[0]; _kv_i++)", m->name, m->name);
            indent++;
            line("_kv_v.%s[_kv_i] = %s(&self->%s[_kv_i]);", m->name, f, m->name);
            indent--;
        }
    }
    line("return _kv_v;");
    indent--;
    line("}");
}

/* An enum with values (#61): a struct of a byte tag and a union of the
   cases' values, its names, and per case: at (a checked pointer), get
   (checked, by value), set (frees what it held) and make. */
static void emit_tagged_record(Decl *d, Type *recv) {
    char *ctype = decl(recv, "");
    bool values = false;
    for (int i = 0; i < d->members.len; i++)
        values = values || ((Var *)d->members.data[i])->type;
    line("/* %s */", d->spelling ? d->spelling : strfmt("enum %s: %s", d->name, "a tagged union"));
    line("struct %s", d->name);
    line("{");
    indent++;
    line("uint8_t tag;");
    if (values) {
        line("union");
        line("{");
        indent++;
        for (int i = 0; i < d->members.len; i++) {
            Var *m = d->members.data[i];
            if (m->type) {
                sync(m->pos);
                line("%s;", decl(m->type, m->name));
            }
        }
        indent--;
        line("} u;");
    }
    indent--;
    line("};");
    Buf names = {0};
    buf_puts(&names, "");
    for (int i = 0; i < d->members.len; i++)
        buf_printf(&names, "%s\"%s\"", i ? ", " : "", ((Var *)d->members.data[i])->name);
    line("__attribute__((unused)) static const char *const _kv_%s_cases[] = {%s};", d->name, names.buf);
    emit_arrays_after(d);
    bool owns = owner_free(recv) != NULL;
    if (owns) {
        line("__attribute__((unused)) static inline void _kv_%s_free(%s *self)", d->name, ctype);
        line("{");
        indent++;
        line("switch (self->tag)");
        line("{");
        for (int i = 0; i < d->members.len; i++) {
            Var *m = d->members.data[i];
            const char *f = m->type ? owner_free(m->type) : NULL;
            if (f) {
                line("case %d: %s(&self->u.%s); break;", i, f, m->name);
            } else if (m->type && m->type->kind == T_ARRAY && (f = owner_free(m->type->elem))) {
                line("case %d:", i);
                indent++;
                line("for (size_t _kv_i = 0; _kv_i < sizeof self->u.%s / sizeof self->u.%s[0]; _kv_i++)", m->name, m->name);
                line("    %s(&self->u.%s[_kv_i]);", f, m->name);
                line("break;");
                indent--;
            }
        }
        line("default: break;");
        line("}");
        line("*self = (%s){0};", ctype);
        indent--;
        line("}");
        line("__attribute__((unused)) static inline %s _kv_%s_take(%s *self)", ctype, d->name, ctype);
        line("{");
        indent++;
        line("%s _kv_v = *self;", ctype);
        line("*self = (%s){0};", ctype);
        line("return _kv_v;");
        indent--;
        line("}");
        line("__attribute__((unused)) static inline %s _kv_%s_copy(const %s *self)", ctype, d->name, ctype);
        line("{");
        indent++;
        line("%s _kv_v = *self;", ctype);
        line("switch (self->tag)");
        line("{");
        for (int i = 0; i < d->members.len; i++) {
            Var *m = d->members.data[i];
            const char *f = m->type ? owner_copy(m->type) : NULL;
            if (f) {
                line("case %d: _kv_v.u.%s = %s(&self->u.%s); break;", i, m->name, f, m->name);
            } else if (m->type && m->type->kind == T_ARRAY && (f = owner_copy(m->type->elem))) {
                line("case %d:", i);
                indent++;
                line("for (size_t _kv_i = 0; _kv_i < sizeof self->u.%s / sizeof self->u.%s[0]; _kv_i++)", m->name, m->name);
                line("    _kv_v.u.%s[_kv_i] = %s(&self->u.%s[_kv_i]);", m->name, f, m->name);
                line("break;");
                indent--;
            }
        }
        line("default: break;");
        line("}");
        line("return _kv_v;");
        indent--;
        line("}");
    }
    for (int i = 0; i < d->members.len; i++) {
        Var *m = d->members.data[i];
        const char *check = strfmt("if (self->tag != %d) kv_case_fail(\"%s\", \"%s\", _kv_%s_cases[self->tag]);", i,
                                   d->spelling ? d->spelling : d->name, m->name, d->name);
        if (m->type) {
            char *mt = decl(m->type, "");
            line("__attribute__((unused)) static inline %s *_kv_%s_at_%s(const %s *self)", mt, d->name, m->name, ctype);
            line("{");
            indent++;
            line("%s", check);
            line("return (%s *)&self->u.%s;", mt, m->name);
            indent--;
            line("}");
            line("__attribute__((unused)) static inline %s _kv_%s_get_%s(%s self)", mt, d->name, m->name, ctype);
            line("{");
            indent++;
            line("if (self.tag != %d) kv_case_fail(\"%s\", \"%s\", _kv_%s_cases[self.tag]);", i,
                 d->spelling ? d->spelling : d->name, m->name, d->name);
            line("return self.u.%s;", m->name);
            indent--;
            line("}");
            line("__attribute__((unused)) static inline void _kv_%s_set_%s(%s *self, %s v)", d->name, m->name, ctype, mt);
            line("{");
            indent++;
            if (owns)
                line("_kv_%s_free(self);", d->name);
            line("self->tag = %d;", i);
            line("self->u.%s = v;", m->name);
            indent--;
            line("}");
            line("__attribute__((unused)) static inline %s _kv_%s_make_%s(%s v)", ctype, d->name, m->name, mt);
            line("{");
            indent++;
            line("%s _kv_v = {0};", ctype);
            line("_kv_v.tag = %d;", i);
            line("_kv_v.u.%s = v;", m->name);
            line("return _kv_v;");
            indent--;
            line("}");
        } else {
            line("__attribute__((unused)) static inline void _kv_%s_set_%s(%s *self)", d->name, m->name, ctype);
            line("{");
            indent++;
            if (owns)
                line("_kv_%s_free(self);", d->name);
            line("self->tag = %d;", i);
            indent--;
            line("}");
            line("__attribute__((unused)) static inline %s _kv_%s_make_%s(void)", ctype, d->name, m->name);
            line("{");
            indent++;
            line("%s _kv_v = {0};", ctype);
            line("_kv_v.tag = %d;", i);
            line("return _kv_v;");
            indent--;
            line("}");
        }
    }
}

static void emit_decl(Decl *d) {
    sync(d->pos);
    hidden_names.len = 0;
    switch (d->kind) {
    case D_IMPORT:
        line("#include %s", d->name);
        break;
    case D_FN:
        /* registered before the body, so a method can call itself */
        if (d->recv)
            register_method(d->name, d->recv, method_cname(d));
        if (d->text_method) {
            /* T.cstr() (#53): the template's text, built in the method's
               block as any template is, then copied into the caller's
               buffer, which has room for it (the enum at the struct) */
            Stmt *only = d->body->stmts.data[0];
            Expr *put = xcalloc(1, sizeof *put);
            put->kind = E_CALL;
            put->pos = only->pos;
            put->a = xcalloc(1, sizeof *put->a);
            put->a->kind = E_IDENT;
            put->a->pos = only->pos;
            put->a->text = "kv_cstr_put";
            Expr *buf = xcalloc(1, sizeof *buf);
            buf->kind = E_IDENT;
            buf->pos = only->pos;
            buf->text = "_kv_buf";
            list_push(&put->items, buf);
            list_push(&put->items, only->expr);
            Stmt *copy = xcalloc(1, sizeof *copy);
            copy->kind = S_EXPR;
            copy->pos = only->pos;
            copy->expr = put;
            Stmt *ret = xcalloc(1, sizeof *ret);
            ret->kind = S_RETURN;
            ret->pos = only->pos;
            ret->expr = buf;
            Stmt *body = xcalloc(1, sizeof *body);
            body->kind = S_BLOCK;
            body->pos = d->body->pos;
            list_push(&body->stmts, copy);
            list_push(&body->stmts, ret);
            line("__attribute__((unused)) static inline uint8_t *_kv_%s_cstr(%s, uint8_t *_kv_buf)",
                 d->recv->name + (strncmp(d->recv->name, "struct ", 7) ? 6 : 7), decl(d->recv, "self"));
            count_names = (List){0};
            param_caches.len = count_cache.len = 0;
            stmt(body);
        } else if (!d->body) {
            line("%s;", fn_head(d));
        } else {
            line("%s", fn_head(d));
            count_names = (List){0};
            find_counts_stmt(d->body);
            param_caches.len = count_cache.len = owner_locals.len = 0;
            for (int i = 0; i < d->params.len; i++) {
                Var *p = d->params.data[i];
                const char *frees = owner_free(p->type);
                if (frees) { /* an owner moved in (#54): the body's block frees it */
                    list_push(&param_caches, strfmt("__attribute__((cleanup(%s))) %s = _kv_%s_in;", frees,
                                                    decl(p->type, c_name(p->name)), c_name(p->name)));
                    list_push(&owner_locals, p->name);
                    list_push(&owner_locals, p->type);
                }
                if (p->type->kind == T_PTR && p->type->cstr && counts_cstr(p->name)) {
                    char *cache = hidden(p->name, "count");
                    list_push(&param_caches, strfmt("size_t %s = (size_t)-1;", cache));
                    list_push(&count_cache, p->name);
                    list_push(&count_cache, cache);
                }
            }
            stmt(d->body);
        }
        break;
    case D_VAR:
        for (int i = 0; i < d->members.len; i++) {
            Var *v = d->members.data[i];
            sync(v->pos);
            line("%s;", var_decl(d->storage, v));
        }
        break;
    case D_STRUCT:
    case D_UNION:
    case D_ENUM: {
        const char *kw = d->kind == D_STRUCT ? "struct" : d->kind == D_UNION ? "union" : "enum";
        const char *name = d->name ? strfmt(" %s", d->name) : "";
        if (!d->has_body) {
            line("%s%s;", kw, name);
            break;
        }
        if (d->tagged) { /* an enum with values (#61) */
            Type *recv = xcalloc(1, sizeof *recv);
            recv->kind = T_BASE;
            recv->pos = d->pos;
            recv->name = strfmt("struct %s", d->name);
            emit_tagged_record(d, recv);
            Decl *tm = text_method_of(recv->name);
            if (tm) {
                Stmt *only = tm->body->stmts.data[0];
                line("enum { _kv_%s_cstr_size = %s };", d->name, template_room(only->expr));
                line("__attribute__((unused)) static inline uint8_t *_kv_%s_cstr(%s, uint8_t *_kv_buf);", d->name,
                     decl(recv, "self"));
            } else if (is_cstr_used(d->name)) {
                emit_derived_cstr(d, recv);
            }
            register_method("cstr", recv, strfmt("_kv_%s_cstr", d->name));
            break;
        }
        if (d->spelling) /* a struct or union with no tag (#59, #60), as written */
            line("/* %s */", d->spelling);
        line("%s%s", kw, name);
        line("{");
        indent++;
        for (int i = 0; i < d->members.len; i++) {
            Var *m = d->members.data[i];
            sync(m->pos);
            if (d->kind == D_ENUM)
                line("%s%s,", m->name, m->init ? strfmt(" = %s", expr(m->init)) : "");
            else
                line("%s;", decl(m->type, m->name));
        }
        indent--;
        line("};");
        if (d->kind != D_ENUM && d->name)
            emit_arrays_after(d); /* the Arrays of this struct, which it may hold (#61) */
        if (d->kind != D_ENUM && d->name) {
            /* every struct and union has a derived .cstr */
            Type *recv = xcalloc(1, sizeof *recv);
            recv->kind = T_BASE;
            recv->pos = d->pos;
            recv->name = strfmt("%s %s", kw, d->name);
            line("%s", "");
            if (d->kind == D_STRUCT && owner_free(recv)) { /* a struct that owns (#54) */
                line("__attribute__((unused)) static inline void _kv_%s_free(%s *self)", d->name, decl(recv, ""));
                line("{");
                indent++;
                for (int i = 0; i < d->members.len; i++) {
                    Var *m = d->members.data[i];
                    const char *f = owner_free(m->type);
                    if (f) {
                        line("%s(&self->%s);", f, m->name);
                    } else if (m->type->kind == T_ARRAY && (f = owner_free(m->type->elem))) {
                        line("for (size_t _kv_i = 0; _kv_i < sizeof self->%s / sizeof self->%s[0]; _kv_i++)", m->name,
                             m->name);
                        indent++;
                        line("%s(&self->%s[_kv_i]);", f, m->name);
                        indent--;
                    }
                }
                indent--;
                line("}");
                line("__attribute__((unused)) static inline %s _kv_%s_take(%s *self)", decl(recv, ""), d->name,
                     decl(recv, ""));
                line("{");
                indent++;
                line("%s _kv_v = *self;", decl(recv, ""));
                line("*self = (%s){0};", decl(recv, ""));
                line("return _kv_v;");
                indent--;
                line("}");
                emit_derived_copy(d, recv);
            }
            Decl *tm = text_method_of(recv->name);
            if (tm) {
                /* T.cstr() (#53): its size from its template, and its
                   prototype here, its definition where it is written */
                Stmt *only = tm->body->stmts.data[0];
                line("enum { _kv_%s_cstr_size = %s };", d->name, template_room(only->expr));
                line("__attribute__((unused)) static inline uint8_t *_kv_%s_cstr(%s, uint8_t *_kv_buf);", d->name,
                     decl(recv, "self"));
            } else if (is_cstr_used(d->name)) {
                emit_derived_cstr(d, recv);
            }
            /* registered either way, for receivers kelvinc cannot see */
            register_method("cstr", recv, strfmt("_kv_%s_cstr", d->name));
        }
        break;
    }
    }
}

char *gen_program(Program *prog, bool with_lines) {
    out = (Buf){0};
    indent = 0;
    line_directives = with_lines;
    mapped_line = -1;
    /* the prelude (print, println) comes from libkelvin */
    buf_puts(&out, "/* generated by kelvinc */\n#include <stdbool.h>\n#include <stdint.h>\n#include <string.h>\n"
                   "#include <kelvin_prelude.h>\n");
    program = prog;
    methods = (List){0};
    cstr_used = (List){0};
    for (int i = 0; i < prog->decls.len; i++) {
        Decl *d = prog->decls.data[i];
        find_cstr_stmt(d->body);
        for (int j = 0; d->kind == D_VAR && j < d->members.len; j++)
            find_cstr_expr(((Var *)d->members.data[j])->init);
    }
    text_bufs = NULL;
    hidden_names = (List){0};
    pinned_line.file = NULL;
    for (int i = 0; i < prog->decls.len; i++) {
        cur_decl = i;
        emit_arrays_before(i);
        emit_views_before(i);
        if (i)
            line("%s", "");
        emit_decl(prog->decls.data[i]);
    }
    return out.buf ? out.buf : xstrdup("");
}
