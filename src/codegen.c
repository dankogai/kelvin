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
static List methods;        /* Method * */
static int method_temps;    /* names the receiver temporaries */
static Program *program;
static bool line_directives;
static int mapped_line = -1;  /* .k line that the next C line corresponds to */

static void line(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

/* while set, every emitted line maps to this .k position (generated
   code such as a derived toString) */
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
        {"String", "kv_String"},
        {"any", "void"}, /* any^ is void * */
    };
    for (size_t i = 0; i < sizeof map / sizeof map[0]; i++)
        if (!strcmp(name, map[i].kelvin))
            return map[i].c;
    return name;
}

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
    }
    return NULL;
}

/* `x: T` as a C declaration, or the bare type name when name is "" */
static char *decl(Type *t, const char *name) { return declarator(t, name, false); }

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
        return e->text;
    case E_STRING: {
        Buf b = {0};
        for (int i = 0; i < e->items.len; i++)
            buf_printf(&b, "%s%s", i ? " " : "", (char *)e->items.data[i]);
        return b.buf;
    }
    case E_PREFIX: {
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
        if (!strcmp(e->op, ","))
            return strfmt("%s, %s", expr(e->a), expr(e->b));
        if (strchr("-+*&", e->op[0]) && e->op[1] == '\0')
            return strfmt("%s %s %s", operand_before(e->a), c_op(e->op), expr(e->b));
        return strfmt("%s %s %s", expr(e->a), c_op(e->op), expr(e->b));
    case E_TERNARY:
        return strfmt("%s ? %s : %s", expr(e->a), expr(e->b), expr(e->c));
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
            return strfmt("sizeof(%s)", e->a->text);
        if (e->a->paren)
            return strfmt("sizeof (%s)", expr(e->a));
        return strfmt("sizeof %s", expr(e->a));
    case E_INIT:
        return initializer(e);
    case E_METHOD: {
        /* The receiver is evaluated once into a temporary, which also
           keeps chains like a.b().c() linear in size (GNU statement
           expression and __auto_type, both accepted by gcc and clang) */
        char *recv = expr(e->a);
        char *tmp = strfmt("kv_self%d", ++method_temps);
        Buf assoc = {0};
        buf_puts(&assoc, "");
        if (!strcmp(e->text, "toString") || !strcmp(e->text, "fmt"))
            buf_printf(&assoc, "KV_METHOD_%s ", e->text);
        for (int i = 0; i < methods.len; i++) {
            Method *m = methods.data[i];
            if (!strcmp(m->method, e->text))
                buf_printf(&assoc, "%s: %s, ", m->ctype, m->fn);
        }
        const char *fallback = !strcmp(e->text, "toString") ? "kv_toString_ptr"
                               : !strcmp(e->text, "fmt")    ? "kv_fmt_ptr"
                                                            : "kv_no_such_method";
        Buf args = {0};
        buf_puts(&args, "");
        for (int i = 0; i < e->items.len; i++)
            buf_printf(&args, ", %s", expr(e->items.data[i]));
        return strfmt("({ __auto_type %s = %s; _Generic((%s), %sdefault: %s)(%s%s); })", tmp, recv, tmp, assoc.buf,
                      fallback, tmp, args.buf);
    }
    }
    return NULL;
}

static char *expr(Expr *e) {
    char *s = expr_bare(e);
    return e->paren ? strfmt("(%s)", s) : s;
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

static char *var_decl(const char *storage, Var *v) {
    if (v->assign)
        return strfmt("%s = %s", v->name, expr(v->init));
    char *d = decl(v->type, v->name);
    /* a reference declared without a value is nullptr (#20) */
    const char *init = v->init                                                         ? initializer(v->init)
                       : v->type->kind == T_PTR && !(storage && !strcmp(storage, "extern")) ? "0"
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
    case S_BLOCK:
        sync(s->pos);
        line("{");
        indent++;
        for (int i = 0; i < s->stmts.len; i++)
            stmt(s->stmts.data[i]);
        indent--;
        line("}");
        break;
    case S_VAR:
        for (int i = 0; i < s->vars.len; i++) {
            Var *v = s->vars.data[i];
            sync(v->pos);
            line("%s;", var_decl(s->storage, v));
        }
        break;
    case S_EXPR:
        line("%s;", expr(s->expr));
        break;
    case S_EMPTY:
        line(";");
        break;
    case S_IF:
        line("if (%s)", expr(s->expr));
        body(s->body);
        if (s->els) {
            sync(s->els->pos);
            line("else");
            body(s->els);
        }
        break;
    case S_WHILE:
        line("while (%s)", expr(s->expr));
        body(s->body);
        break;
    case S_DO:
        line("do");
        body(s->body);
        line("while (%s);", expr(s->expr));
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
        line("for (%s; %s; %s)", init, s->expr ? expr(s->expr) : "", s->step ? expr(s->step) : "");
        body(s->body);
        if (wrap) {
            indent--;
            line("}");
        }
        break;
    }
    case S_SWITCH:
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

/* point.toString is the C function point__toString, f64.half f64__half */
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
        /* C insists that main's argv is char **; Kelvin writes it u8^^ */
        bool argv = !d->recv && !strcmp(d->name, "main") && i == 1;
        buf_printf(&params, "%s%s", params.len ? ", " : "", argv ? strfmt("char **%s", p->name) : decl(p->type, p->name));
    }
    if (d->variadic)
        buf_puts(&params, ", ...");
    /* Kelvin's `()` means no parameters, which C spells `(void)` */
    char *inner = strfmt("%s(%s)", d->recv ? method_cname(d) : d->name, params.len ? params.buf : "void");
    char *head = d->ret ? decl(d->ret, inner) : strfmt("void %s", inner);
    return strfmt("%s%s%s", d->storage ? d->storage : "", d->storage ? " " : "", head);
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

/* The C expression for the String form of `lv`, an lvalue of type t. */
static char *to_string_expr(Type *t, const char *lv) {
    if (t->kind == T_PTR) {
        Type *e = t->elem;
        if (e->kind == T_BASE && (!strcmp(e->name, "u8") || !strcmp(e->name, "i8")))
            return strfmt("kv_toString_str((const char *)%s)", lv);
        return strfmt("kv_toString_ptr((const void *)%s)", lv);
    }
    const char *n = t->name;
    static const struct { const char *type, *fn; } direct[] = {
        {"i8", "kv_toString_i64"},    {"i16", "kv_toString_i64"},  {"i32", "kv_toString_i64"},
        {"i64", "kv_toString_i64"},   {"u8", "kv_toString_u64"},   {"u16", "kv_toString_u64"},
        {"u32", "kv_toString_u64"},   {"u64", "kv_toString_u64"},  {"i128", "kv_toString_i128"},
        {"u128", "kv_toString_u128"}, {"f32", "kv_toString_f32"},  {"f64", "kv_toString_f64"},
        {"bool", "kv_toString_bool"}, {"String", "kv_toString_String"},
        {"f32 _Complex", "kv_toString_cf"}, {"f64 _Complex", "kv_toString_cd"},
    };
    for (size_t i = 0; i < sizeof direct / sizeof direct[0]; i++)
        if (!strcmp(n, direct[i].type))
            return strfmt("%s(%s)", direct[i].fn, lv);
    Decl *r = kelvin_record(n);
    if (r)
        return strfmt("%s__toString(%s)", r->name, lv);
    for (int i = 0; i < methods.len; i++) {
        Method *m = methods.data[i];
        if (!strcmp(m->method, "toString") && !strcmp(m->ctype, n))
            return strfmt("%s(%s)", m->fn, lv); /* e.g. a toString for a header struct */
    }
    /* a C typedef, a C struct, an enum: decided by the C compiler */
    return strfmt("kv_toString_any(%s)", lv);
}

/* append the String form of `lv` (type t) to kv_s; arrays print as [a, b] */
static void append_value(Type *t, const char *lv, int depth) {
    if (t->kind != T_ARRAY) {
        line("kv_string_append(&kv_s, (const char *)%s.bytes);", to_string_expr(t, lv));
        return;
    }
    if (!t->size) {
        line("kv_string_append(&kv_s, \"[...]\");"); /* a flexible array member */
        return;
    }
    char *i = strfmt("kv_i%d", depth);
    line("kv_string_append(&kv_s, \"[\");");
    line("for (size_t %s = 0; %s < sizeof %s / sizeof %s[0]; %s++)", i, i, lv, lv, i);
    line("{");
    indent++;
    line("if (%s)", i);
    line("    kv_string_append(&kv_s, \", \");");
    append_value(t->elem, strfmt("%s[%s]", lv, i), depth + 1);
    indent--;
    line("}");
    line("kv_string_append(&kv_s, \"]\");");
}

/* The derived toString of a struct, {x: 1, y: 2}; a union, whose active
   member is unknown, prints as <union name>. */
static void emit_derived_tostring(Decl *d, Type *recv) {
    pinned_line = d->pos;
    line("static inline kv_String %s__toString(%s)", d->name, decl(recv, "self"));
    line("{");
    indent++;
    line("kv_String kv_s = {{0}};");
    if (d->kind == D_UNION) {
        line("kv_string_append(&kv_s, \"<union %s>\");", d->name);
    } else {
        line("kv_string_append(&kv_s, \"{\");");
        for (int i = 0; i < d->members.len; i++) {
            Var *m = d->members.data[i];
            line("kv_string_append(&kv_s, \"%s%s: \");", i ? ", " : "", m->name);
            append_value(m->type, strfmt("self.%s", m->name), 0);
        }
        line("kv_string_append(&kv_s, \"}\");");
    }
    line("return kv_s;");
    indent--;
    line("}");
    pinned_line.file = NULL;
    mapped_line = -1;
}

/* the user's toString for a receiver type name, if any */
static Decl *user_tostring_decl(const char *recv) {
    for (int i = 0; i < program->decls.len; i++) {
        Decl *d = program->decls.data[i];
        if (d->kind == D_FN && d->recv && !strcmp(d->name, "toString") && !strcmp(d->recv->name, recv))
            return d;
    }
    return NULL;
}

static void emit_decl(Decl *d) {
    sync(d->pos);
    switch (d->kind) {
    case D_IMPORT:
        line("#include %s", d->name);
        break;
    case D_FN:
        if (d->recv && !strcmp(d->name, "toString") && kelvin_record(d->recv->name) && !d->body)
            break; /* already declared right after the struct */
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
            /* every struct and union has toString: the user's, or a derived one */
            Type *recv = xcalloc(1, sizeof *recv);
            recv->kind = T_BASE;
            recv->pos = d->pos;
            recv->name = strfmt("%s %s", kw, d->name);
            line("%s", "");
            Decl *user = user_tostring_decl(recv->name);
            if (user)
                line("%s;", fn_head(user)); /* as the user declares it, e.g. static */
            else
                emit_derived_tostring(d, recv);
            register_method("toString", recv, strfmt("%s__toString", d->name));
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
    method_temps = 0;
    pinned_line.file = NULL;
    for (int i = 0; i < prog->decls.len; i++) {
        if (i)
            line("%s", "");
        emit_decl(prog->decls.data[i]);
    }
    return out.buf ? out.buf : xstrdup("");
}
