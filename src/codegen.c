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
static bool line_directives;
static int mapped_line = -1;  /* .k line that the next C line corresponds to */

static void line(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

static void line(const char *fmt, ...) {
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

/* Kelvin's sized integers are <stdint.h>'s; 128-bit ones exist where the
   C compiler provides __int128. bool, true and false are <stdbool.h>'s. */
static const char *c_type_name(const char *name) {
    static const struct { const char *kelvin, *c; } map[] = {
        {"i8", "int8_t"},   {"i16", "int16_t"},   {"i32", "int32_t"},   {"i64", "int64_t"},
        {"u8", "uint8_t"},  {"u16", "uint16_t"},  {"u32", "uint32_t"},  {"u64", "uint64_t"},
        {"i128", "__int128"}, {"u128", "unsigned __int128"},
        {"f32", "float"},     {"f64", "double"},
        {"f32 _Complex", "float _Complex"}, {"f64 _Complex", "double _Complex"},
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
    if (!strcmp(op, "~"))
        return "^";
    if (!strcmp(op, "~="))
        return "^=";
    return (char *)op;
}

static char *initializer(Expr *e);

static char *expr_bare(Expr *e) {
    switch (e->kind) {
    case E_LITERAL:
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
        return strfmt("%s %s %s", expr(e->a), c_op(e->op), expr(e->b));
    case E_TERNARY:
        return strfmt("%s ? %s : %s", expr(e->a), expr(e->b), expr(e->c));
    case E_CALL: {
        Buf b = {0};
        buf_printf(&b, "%s(", expr(e->a));
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
        return strfmt("(%s)%s", decl(e->type, ""), expr(e->a));
    case E_COMPOUND:
        return strfmt("(%s)%s", decl(e->type, ""), initializer(e->a));
    case E_SIZEOF_TYPE:
        return strfmt("sizeof(%s)", decl(e->type, ""));
    case E_SIZEOF_EXPR:
        return strfmt("sizeof %s", expr(e->a));
    case E_INIT:
        return initializer(e);
    }
    return NULL;
}

static char *expr(Expr *e) {
    char *s = expr_bare(e);
    return e->paren ? strfmt("(%s)", s) : s;
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
    char *d = decl(v->type, v->name);
    return strfmt("%s%s%s%s", storage ? storage : "", storage ? " " : "", d,
                  v->init ? strfmt(" = %s", initializer(v->init)) : "");
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

static char *fn_head(Decl *d) {
    Buf params = {0};
    for (int i = 0; i < d->params.len; i++) {
        Var *p = d->params.data[i];
        /* C insists that main's argv is char **; Kelvin writes it u8^^ */
        bool argv = !strcmp(d->name, "main") && i == 1;
        buf_printf(&params, "%s%s", i ? ", " : "", argv ? strfmt("char **%s", p->name) : decl(p->type, p->name));
    }
    if (d->variadic)
        buf_puts(&params, ", ...");
    /* Kelvin's `()` means no parameters, which C spells `(void)` */
    char *inner = strfmt("%s(%s)", d->name, params.len ? params.buf : "void");
    char *head = d->ret ? decl(d->ret, inner) : strfmt("void %s", inner);
    return strfmt("%s%s%s", d->storage ? d->storage : "", d->storage ? " " : "", head);
}

static void emit_decl(Decl *d) {
    sync(d->pos);
    switch (d->kind) {
    case D_IMPORT:
        line("#include %s", d->name);
        break;
    case D_FN:
        if (!d->body) {
            line("%s;", fn_head(d));
            break;
        }
        line("%s", fn_head(d));
        stmt(d->body);
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
        break;
    }
    }
}

char *gen_program(Program *prog, bool with_lines) {
    out = (Buf){0};
    indent = 0;
    line_directives = with_lines;
    mapped_line = -1;
    buf_puts(&out, "/* generated by kelvinc */\n#include <stdbool.h>\n#include <stdint.h>\n");
    for (int i = 0; i < prog->decls.len; i++) {
        if (i)
            line("%s", "");
        emit_decl(prog->decls.data[i]);
    }
    return out.buf ? out.buf : xstrdup("");
}
