/* codegen.c - print the Kelvin AST as C

   Kelvin's operator precedence is C's, so expressions are printed with
   exactly the parentheses the programmer wrote. The only rewrites are:

     p^        ->  (*p)
     p^.m      ->  p->m
     a ~ b     ->  a ^ b      (and ~= -> ^=)
     x: T      ->  C declarator for T around x

   `#line` directives map C compiler diagnostics back to the .k source. */
#include "kelvin.h"

#include <stdarg.h>
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
/* the template literals' storage in the innermost block (#39), and in
   the function's body, where a block that a switch or goto jumps into
   puts its own: C cannot jump past a cleanup variable's initializer */
static List *template_vars, *fn_template_vars;
static Stmt *fn_body, *switch_body;
static bool jumped_into(Stmt *s, bool owned);
/* the stems of the hidden names written in the function being written,
   each followed by the number its next repeat takes (#38) */
static List hidden_names;
static Program *program;
static bool line_directives;
static int mapped_line = -1;  /* .k line that the next C line corresponds to */

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
    if (!line_directives || mapped_line == p.line)
        return;
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
                      c_type_name(t->name), *inner ? " " : "", inner);
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
    case E_IDENT:
        return (char *)c_name(e->text);
    case E_FUNC: /* the static function it became (#32) */
        return e->text;
    case E_TEMPLATE: {
        /* `a${x}b` (#39): built in a fresh kv_template from the literal
           parts and each value, evaluated once into a temporary and shown
           as print shows it, in order; then it replaces the text in the
           template's storage, which the enclosing block declares and frees
           when it ends. A value may read the earlier text, which is freed
           only then. The text is a char *, as a string literal is. */
        char *t = hidden(NULL, "template"), *build = hidden(NULL, "build");
        list_push(template_vars, t);
        Buf b = {0};
        buf_printf(&b, "({ kv_template %s = {0}; ", build);
        for (int i = 0; i < e->items.len; i++) {
            Expr *x = e->items.data[i];
            if (x->kind == E_STRING) {
                for (int j = 0; j < x->items.len; j++)
                    if (strcmp(x->items.data[j], "\"\""))
                        buf_printf(&b, "kv_template_part(&%s, %s, sizeof %s - 1); ", build, (char *)x->items.data[j],
                                   (char *)x->items.data[j]);
            } else {
                /* (void)0, v: a bit-field cannot initialize __auto_type */
                char *v = hidden(NULL, "value");
                buf_printf(&b, "__auto_type %s = ((void)0, (%s)); KV_TEMPLATE_VALUE(&%s, %s); ", v, expr_bare(x), build,
                           v);
            }
        }
        buf_printf(&b, "kv_template_take(&%s, &%s); })", t, build);
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
        Buf b = {0};
        buf_printf(&b, "%s(", operand_before(e->a));
        for (int i = 0; i < e->items.len; i++)
            buf_printf(&b, "%s%s", i ? ", " : "", expr(e->items.data[i]));
        buf_puts(&b, ")");
        return b.buf;
    }
    case E_INDEX:
        return strfmt("%s[%s]", e->a ? expr(e->a) : "", expr(e->b));
    case E_FIELD:
        if (e->a && e->a->kind == E_DEREF && !e->a->paren)
            return strfmt("%s->%s", expr(e->a->a), e->text);
        return strfmt("%s.%s", e->a ? expr(e->a) : "", e->text);
    case E_CAST:
        if (e->op && !strcmp(e->op, "converter"))
            return strfmt("(%s)(%s)", decl(e->type, ""), expr_bare(e->a));
        if (e->op && !strncmp(e->op, "text", 4))
            return text_number(e);
        return strfmt("(%s)%s", decl(e->type, ""), expr(e->a));
    case E_COMPOUND:
        return strfmt("(%s)%s", decl(e->type, ""), initializer(e->a));
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
        if (!strcmp(e->text, "size"))
            return strfmt("sizeof(%s)", recv);
        if (!strcmp(e->text, "typename")) /* a type kelvinc cannot see (#34) */
            return strfmt("kv_typename((%s))", recv);
        if (!strcmp(e->text, "next") || !strcmp(e->text, "prev")) /* #26 */
            return strfmt("(%s %s 1)", recv, e->text[0] == 'n' ? "+" : "-");
        if (!strcmp(e->text, "addr")) /* #37 */
            return strfmt("((uintptr_t)(%s))", recv);
        bool cstr = !strcmp(e->text, "cstr");
        Decl *r = cstr && e->type ? kelvin_record(e->type->name) : NULL;
        const char *size = r                          ? strfmt("_kv_%s_cstr_size", r->name)
                           : cstr                     ? "KV_CSTR_SCALAR"
                           : !strcmp(e->text, "dec")  ? "41"   /* -170141183460469231731687303715884105728 */
                           : !strcmp(e->text, "hex")  ? "36"   /* -0x and 32 digits */
                           : !strcmp(e->text, "oct")  ? "47"   /* -0o and 43 digits */
                                                      : "132"; /* -0b and 128 digits */
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
    char *d = decl(v->is_let ? const_type(v->type) : v->type, v->name);
    /* a reference declared without a value is nullptr (#20) */
    /* a v.type that C writes as __typeof__ is the type kelvinc saw (#34) */
    Type *seen = v->type->kind == T_TYPEOF && v->type->elem ? v->type->elem : v->type;
    const char *init = v->init                                                         ? initializer(v->init)
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
        text_bufs = &bufs;
        if (s == fn_body)
            fn_template_vars = &tmpls;
        template_vars = (s == switch_body || jumped_into(s, false)) && fn_template_vars ? fn_template_vars : &tmpls;
        out = (Buf){0};
        for (int i = 0; i < s->stmts.len; i++)
            stmt(s->stmts.data[i]);
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
            /* a template's text is freed when the block ends (#39) */
            for (int i = 0; i < tmpls.len; i++)
                line("__attribute__((cleanup(kv_template_free))) kv_template %s = {0};", (char *)tmpls.data[i]);
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
        }
        break;
    case S_EXPR:
        /* a && f(); or c ? f() : g(); as a statement: its value is
           discarded, so it needs no bool, which clang would call unused */
        if (s->expr->kind == E_BINARY && (!strcmp(s->expr->op, "&&") || !strcmp(s->expr->op, "||")))
            line("%s;", cond(s->expr));
        else if (s->expr->kind == E_TERNARY && !s->expr->paren)
            line("%s ? %s : %s;", cond(s->expr->a), expr(s->expr->b), expr(s->expr->c));
        else
            line("%s;", expr(s->expr));
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
        if (s->each == EACH_LIST) {
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
        if (!strcmp(s->name, "_"))
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
        switch_body = s->body;
        line("switch (%s)", expr(s->expr));
        body(s->body);
        break;
    case S_CASE:
        indent--;
        line("case %s:", expr(s->expr));
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
        if (s->expr)
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
        buf_printf(&params, "%s%s%s", params.len ? ", " : "", unused,
                   argv ? strfmt(argv_c, p->name) : decl(t, c_name(p->name)));
    }
    if (d->variadic)
        buf_puts(&params, ", ...");
    /* Kelvin's `()` means no parameters, which C spells `(void)` */
    char *inner = strfmt("%s(%s)", d->recv ? method_cname(d) : d->name, params.len ? params.buf : "void");
    char *head = d->ret ? decl(d->ret, inner) : strfmt("void %s", inner);
    /* an anonymous function used only where C does not evaluate, as in
       sizeof, is never emitted, which C need not mention (#32) */
    return strfmt("%s%s%s%s", d->anon ? "__attribute__((unused)) " : "", d->storage ? d->storage : "",
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
        {"f32", "15"},  {"f64", "24"},  {"bool", "5"},
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

/* a C expression that writes the text of `lv` (type t, not an array) at p
   and gives the end */
static char *text_writer(Type *t, const char *lv) {
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
        while (t->kind == T_ARRAY)
            t = t->elem;
        if (t->kind == T_BASE)
            use_cstr(kelvin_record(t->name));
    }
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
    if (d->kind == D_UNION) {
        buf_printf(&size, "%d", (int)strlen(d->name) + 9);
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
        line("kv_cstr_put(_kv_buf, \"<union %s>\");", d->name);
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

/* Can a goto or a switch jump into block s past its start, where a
   template's storage would be declared: does s hold a label, or a case
   that no switch inside s owns? (#39) */
static bool jumped_into(Stmt *s, bool owned) {
    if (!s)
        return false;
    if (s->kind == S_LABEL || ((s->kind == S_CASE || s->kind == S_DEFAULT) && !owned))
        return true;
    owned = owned || s->kind == S_SWITCH;
    if (jumped_into(s->body, owned) || jumped_into(s->els, owned) || jumped_into(s->init, owned))
        return true;
    for (int i = 0; i < s->stmts.len; i++)
        if (jumped_into(s->stmts.data[i], owned))
            return true;
    return false;
}

static void emit_decl(Decl *d) {
    sync(d->pos);
    hidden_names.len = 0;
    fn_body = d->kind == D_FN ? d->body : NULL;
    fn_template_vars = NULL;
    switch (d->kind) {
    case D_IMPORT:
        line("#include %s", d->name);
        break;
    case D_FN:
        /* registered before the body, so a method can call itself */
        if (d->recv)
            register_method(d->name, d->recv, method_cname(d));
        if (!d->body) {
            line("%s;", fn_head(d));
        } else {
            line("%s", fn_head(d));
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
        if (d->kind != D_ENUM && d->name) {
            /* every struct and union has a derived .cstr */
            Type *recv = xcalloc(1, sizeof *recv);
            recv->kind = T_BASE;
            recv->pos = d->pos;
            recv->name = strfmt("%s %s", kw, d->name);
            line("%s", "");
            if (is_cstr_used(d->name))
                emit_derived_cstr(d, recv);
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
    buf_puts(&out, "/* generated by kelvinc */\n#include <stdbool.h>\n#include <stdint.h>\n"
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
        if (i)
            line("%s", "");
        emit_decl(prog->decls.data[i]);
    }
    return out.buf ? out.buf : xstrdup("");
}
