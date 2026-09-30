/* codegen.c - emit C11 for a checked program

   Every operation that is undefined behavior in C is routed through a
   checked helper that traps with a source location instead. */
#include "kelvin.h"

#include <stdarg.h>
#include <string.h>

static Buf out;
static int indent;
static int tmp_counter;
static List defers;      /* Stmt * pending on the current path, innermost last */
static List loop_marks;  /* defers.len at entry of each enclosing loop (as intptr_t) */
static Decl *cur_fn;

static const char prelude[] =
    "#include <stdbool.h>\n"
    "#include <stddef.h>\n"
    "#include <stdint.h>\n"
    "\n"
    "_Noreturn void kv_trap(const char *loc, const char *msg);\n"
    "_Noreturn void kv_trap_index(const char *loc, int64_t i, uint64_t n);\n"
    "\n"
    "#define KV_INT_COMMON(N, T, W, BITS) \\\n"
    "static inline T kv_wadd_##N(T a, T b) { return (T)((W)a + (W)b); } \\\n"
    "static inline T kv_wsub_##N(T a, T b) { return (T)((W)a - (W)b); } \\\n"
    "static inline T kv_wmul_##N(T a, T b) { return (T)((W)a * (W)b); } \\\n"
    "static inline T kv_add_##N(T a, T b, const char *l) { T r; if (__builtin_add_overflow(a, b, &r)) kv_trap(l, \"integer overflow in +\"); return r; } \\\n"
    "static inline T kv_sub_##N(T a, T b, const char *l) { T r; if (__builtin_sub_overflow(a, b, &r)) kv_trap(l, \"integer overflow in -\"); return r; } \\\n"
    "static inline T kv_mul_##N(T a, T b, const char *l) { T r; if (__builtin_mul_overflow(a, b, &r)) kv_trap(l, \"integer overflow in *\"); return r; } \\\n"
    "static inline T kv_shl_##N(T a, int64_t s, const char *l) { if (s < 0 || s >= BITS) kv_trap(l, \"shift amount out of range\"); return (T)((W)a << s); } \\\n"
    "static inline T kv_shr_##N(T a, int64_t s, const char *l) { if (s < 0 || s >= BITS) kv_trap(l, \"shift amount out of range\"); return (T)(a >> s); }\n"
    "\n"
    "#define KV_SINT(N, T, W, BITS, MIN) KV_INT_COMMON(N, T, W, BITS) \\\n"
    "static inline T kv_div_##N(T a, T b, const char *l) { if (b == 0) kv_trap(l, \"division by zero\"); if (a == MIN && b == -1) kv_trap(l, \"integer overflow in /\"); return (T)(a / b); } \\\n"
    "static inline T kv_mod_##N(T a, T b, const char *l) { if (b == 0) kv_trap(l, \"division by zero\"); if (a == MIN && b == -1) kv_trap(l, \"integer overflow in %\"); return (T)(a % b); } \\\n"
    "static inline T kv_neg_##N(T a, const char *l) { if (a == MIN) kv_trap(l, \"integer overflow in unary -\"); return (T)-a; } \\\n"
    "static inline T kv_f2i_##N(double x, const char *l) { if (!((x > (double)MIN - 1.0 || x == (double)MIN) && x < -(double)MIN)) kv_trap(l, \"float to integer conversion out of range\"); return (T)x; }\n"
    "\n"
    "#define KV_UINT(N, T, W, BITS, LIMIT) KV_INT_COMMON(N, T, W, BITS) \\\n"
    "static inline T kv_div_##N(T a, T b, const char *l) { if (b == 0) kv_trap(l, \"division by zero\"); return (T)(a / b); } \\\n"
    "static inline T kv_mod_##N(T a, T b, const char *l) { if (b == 0) kv_trap(l, \"division by zero\"); return (T)(a % b); } \\\n"
    "static inline T kv_f2i_##N(double x, const char *l) { if (!(x > -1.0 && x < LIMIT)) kv_trap(l, \"float to integer conversion out of range\"); return (T)x; }\n"
    "\n"
    "KV_SINT(i8, int8_t, uint32_t, 8, INT8_MIN)\n"
    "KV_SINT(i16, int16_t, uint32_t, 16, INT16_MIN)\n"
    "KV_SINT(i32, int32_t, uint32_t, 32, INT32_MIN)\n"
    "KV_SINT(i64, int64_t, uint64_t, 64, INT64_MIN)\n"
    "KV_SINT(isize, ptrdiff_t, uint64_t, 64, PTRDIFF_MIN)\n"
    "KV_UINT(u8, uint8_t, uint32_t, 8, 256.0)\n"
    "KV_UINT(u16, uint16_t, uint32_t, 16, 65536.0)\n"
    "KV_UINT(u32, uint32_t, uint32_t, 32, 4294967296.0)\n"
    "KV_UINT(u64, uint64_t, uint64_t, 64, 18446744073709551616.0)\n"
    "KV_UINT(usize, size_t, uint64_t, 64, 18446744073709551616.0)\n"
    "\n"
    "static inline uint64_t kv_idx(int64_t i, uint64_t n, const char *l) { if (i < 0 || (uint64_t)i >= n) kv_trap_index(l, i, n); return (uint64_t)i; }\n"
    "static inline void *kv_nn(void *p, const char *l) { if (!p) kv_trap(l, \"null pointer dereference\"); return p; }\n";

/* ---------- helpers ---------- */

static void line(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

static void line(const char *fmt, ...) {
    for (int i = 0; i < indent; i++)
        buf_puts(&out, "    ");
    va_list ap;
    va_start(ap, fmt);
    char *s;
    int n = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    s = xmalloc((size_t)n + 1);
    va_start(ap, fmt);
    vsnprintf(s, (size_t)n + 1, fmt, ap);
    va_end(ap);
    buf_puts(&out, s);
    buf_puts(&out, "\n");
}

static char *loc(Pos p) {
    char *s = strfmt("%s:%d:%d", p.file, p.line, p.col);
    return c_string_literal(s, strlen(s));
}

static char *decl_var(Type *t, const char *name) { return strfmt("%s %s", t->cname, name); }

/* ---------- expressions ---------- */

static char *expr(Expr *e);

static char *int_literal(Expr *e) {
    Type *t = e->type;
    unsigned long long mag = e->ival;
    if (is_float(t))
        return strfmt("((%s)%s%llu.0)", t->cname, e->neg ? "-" : "", mag);
    if (!e->neg) {
        if (t == ty_i32 && mag <= INT32_MAX)
            return strfmt("%llu", mag);
        return strfmt("((%s)%lluULL)", t->cname, mag);
    }
    if (t == ty_i32 && mag <= INT32_MAX)
        return strfmt("(-%llu)", mag);
    /* -(mag-1)-1 is representable even for the minimum value */
    return strfmt("((%s)(-%lldLL - 1))", t->cname, (long long)(mag - 1));
}

static char *float_literal(Expr *e) {
    char *s = strfmt("%.17g", e->fval);
    if (!strpbrk(s, ".eEn"))
        s = strfmt("%s.0", s);
    return strfmt("((%s)%s)", e->type->cname, s);
}

static char *int_binop(const char *op, Type *t, char *a, char *b, Pos p) {
    const char *n = t->mangle;
    if (!strcmp(op, "+")) return strfmt("kv_add_%s(%s, %s, %s)", n, a, b, loc(p));
    if (!strcmp(op, "-")) return strfmt("kv_sub_%s(%s, %s, %s)", n, a, b, loc(p));
    if (!strcmp(op, "*")) return strfmt("kv_mul_%s(%s, %s, %s)", n, a, b, loc(p));
    if (!strcmp(op, "/")) return strfmt("kv_div_%s(%s, %s, %s)", n, a, b, loc(p));
    if (!strcmp(op, "%")) return strfmt("kv_mod_%s(%s, %s, %s)", n, a, b, loc(p));
    if (!strcmp(op, "+%")) return strfmt("kv_wadd_%s(%s, %s)", n, a, b);
    if (!strcmp(op, "-%")) return strfmt("kv_wsub_%s(%s, %s)", n, a, b);
    if (!strcmp(op, "*%")) return strfmt("kv_wmul_%s(%s, %s)", n, a, b);
    if (!strcmp(op, "<<")) return strfmt("kv_shl_%s(%s, (int64_t)(%s), %s)", n, a, b, loc(p));
    if (!strcmp(op, ">>")) return strfmt("kv_shr_%s(%s, (int64_t)(%s), %s)", n, a, b, loc(p));
    /* & | ^ : cast back because C promotes narrow operands to int */
    return strfmt("((%s)(%s %s %s))", t->cname, a, op, b);
}

static bool is_cmp_or_logic(const char *op) {
    return !strcmp(op, "==") || !strcmp(op, "!=") || !strcmp(op, "<") || !strcmp(op, "<=") ||
           !strcmp(op, ">") || !strcmp(op, ">=") || !strcmp(op, "&&") || !strcmp(op, "||");
}

static char *binary(Expr *e) {
    char *a = expr(e->lhs), *b = expr(e->rhs);
    if (is_cmp_or_logic(e->op) || is_float(e->type))
        return strfmt("(%s %s %s)", a, e->op, b);
    return int_binop(e->op, e->type, a, b, e->pos);
}

static char *checked_ptr(Expr *p) {
    return strfmt("((%s)kv_nn(%s, %s))", p->type->cname, expr(p), loc(p->pos));
}

static char *expr(Expr *e) {
    switch (e->kind) {
    case E_INT:
        return int_literal(e);
    case E_FLOAT:
        return float_literal(e);
    case E_STR:
        return strfmt("((uint8_t *)%s)", c_string_literal(e->sval, e->slen));
    case E_BOOL:
        return xstrdup(e->ival ? "true" : "false");
    case E_NULL:
        return strfmt("((%s)0)", e->type->cname);
    case E_IDENT:
        return xstrdup(e->sym->cname);
    case E_UNARY: {
        const char *op = e->op;
        if (!strcmp(op, "-"))
            return is_float(e->type) ? strfmt("(-%s)", expr(e->lhs))
                                     : strfmt("kv_neg_%s(%s, %s)", e->type->mangle, expr(e->lhs), loc(e->pos));
        if (!strcmp(op, "!"))
            return strfmt("(!%s)", expr(e->lhs));
        if (!strcmp(op, "~"))
            return strfmt("((%s)~%s)", e->type->cname, expr(e->lhs));
        if (!strcmp(op, "*"))
            return strfmt("(*%s)", checked_ptr(e->lhs));
        return strfmt("(&%s)", expr(e->lhs));
    }
    case E_BINARY:
        return binary(e);
    case E_CALL: {
        Buf b = {0};
        buf_printf(&b, "%s(", e->fn->cname);
        for (int i = 0; i < e->args.len; i++)
            buf_printf(&b, "%s%s", i ? ", " : "", expr(e->args.data[i]));
        buf_puts(&b, ")");
        return b.buf;
    }
    case E_INDEX: {
        Type *t = e->lhs->type;
        char *i = expr(e->rhs);
        if (t->kind == TY_ARRAY)
            return strfmt("%s.a[kv_idx((int64_t)(%s), %lluULL, %s)]", expr(e->lhs), i, (unsigned long long)t->len,
                          loc(e->pos));
        if (t->kind == TY_SLICE)
            return strfmt("(*kv_sidx_%s(%s, (int64_t)(%s), %s))", t->mangle, expr(e->lhs), i, loc(e->pos));
        return strfmt("%s[%s]", checked_ptr(e->lhs), i);
    }
    case E_SLICE: {
        Type *t = e->lhs->type;
        Type *st = e->type;
        char *lo = e->rhs ? strfmt("(int64_t)(%s)", expr(e->rhs)) : xstrdup("0");
        char *hi = e->hi ? strfmt("(int64_t)(%s)", expr(e->hi)) : NULL;
        if (t->kind == TY_ARRAY)
            return strfmt("kv_sub_%s(%s.a, %lluULL, %s, %s, %s)", st->mangle, expr(e->lhs),
                          (unsigned long long)t->len, lo, hi ? hi : strfmt("%llu", (unsigned long long)t->len),
                          loc(e->pos));
        if (t->kind == TY_SLICE)
            return strfmt("kv_subs_%s(%s, %s, %s, %s, %s)", st->mangle, expr(e->lhs), lo, hi ? hi : "0",
                          hi ? "true" : "false", loc(e->pos));
        return strfmt("kv_sub_%s(%s, UINT64_MAX, %s, %s, %s)", st->mangle, checked_ptr(e->lhs), lo, hi,
                      loc(e->pos));
    }
    case E_FIELD: {
        Type *t = e->lhs->type;
        if (t->kind == TY_ARRAY)
            return strfmt("((size_t)%lluULL)", (unsigned long long)t->len);
        if (t->kind == TY_SLICE)
            return strfmt("%s.%s", expr(e->lhs), e->name);
        Type *st = t->kind == TY_PTR ? t->elem : t;
        const char *cname = e->name;
        for (int i = 0; i < st->decl->fields.len; i++) {
            Param *f = st->decl->fields.data[i];
            if (!strcmp(f->name, e->name))
                cname = f->cname;
        }
        if (t->kind == TY_PTR)
            return strfmt("%s->%s", checked_ptr(e->lhs), cname);
        return strfmt("%s.%s", expr(e->lhs), cname);
    }
    case E_CAST: {
        Type *from = e->lhs->type, *to = e->target;
        if (is_float(from) && is_int(to))
            return strfmt("kv_f2i_%s((double)(%s), %s)", to->mangle, expr(e->lhs), loc(e->pos));
        return strfmt("((%s)(%s))", to->cname, expr(e->lhs));
    }
    case E_STRUCTLIT: {
        if (e->args.len == 0)
            return strfmt("((%s){0})", e->type->cname);
        Buf b = {0};
        buf_printf(&b, "((%s){", e->type->cname);
        Decl *d = e->type->decl;
        for (int i = 0; i < e->args.len; i++) {
            const char *cname = e->names.data[i];
            for (int j = 0; j < d->fields.len; j++) {
                Param *f = d->fields.data[j];
                if (!strcmp(f->name, e->names.data[i]))
                    cname = f->cname;
            }
            buf_printf(&b, "%s.%s = %s", i ? ", " : "", cname, expr(e->args.data[i]));
        }
        buf_puts(&b, "})");
        return b.buf;
    }
    case E_ARRAYLIT: {
        Buf b = {0};
        buf_printf(&b, "((%s){{", e->type->cname);
        for (int i = 0; i < e->args.len; i++)
            buf_printf(&b, "%s%s", i ? ", " : "", expr(e->args.data[i]));
        buf_puts(&b, "}})");
        return b.buf;
    }
    case E_SIZEOF:
        return strfmt("((size_t)sizeof(%s))", e->target->cname);
    }
    return NULL;
}

/* ---------- statements ---------- */

/* `if (x == y)` rather than `if ((x == y))` */
static char *cond(Expr *e) {
    char *s = expr(e);
    size_t n = strlen(s);
    int depth = 0;
    if (n < 2 || s[0] != '(' || s[n - 1] != ')')
        return strfmt("(%s)", s);
    for (size_t i = 0; i < n; i++) {
        if (s[i] == '"') {
            for (i++; s[i] != '"'; i++)
                if (s[i] == '\\')
                    i++;
            continue;
        }
        if (s[i] == '(')
            depth++;
        else if (s[i] == ')')
            depth--;
        if (depth == 0 && i < n - 1)
            return strfmt("(%s)", s);
    }
    return s;
}

static void stmt(Stmt *s);

static void run_defers_down_to(int mark) {
    for (int i = defers.len - 1; i >= mark; i--) {
        Stmt *d = defers.data[i];
        /* hide this defer (and inner ones) while emitting its body */
        int saved = defers.len;
        defers.len = i;
        stmt(d->body);
        defers.len = saved;
    }
}

static bool ends_in_jump(Stmt *s) {
    if (s->kind != S_BLOCK || s->stmts.len == 0)
        return false;
    StmtKind k = ((Stmt *)s->stmts.data[s->stmts.len - 1])->kind;
    return k == S_RETURN || k == S_BREAK || k == S_CONTINUE;
}

static void block_body(Stmt *s) {
    int mark = defers.len;
    for (int i = 0; i < s->stmts.len; i++)
        stmt(s->stmts.data[i]);
    if (!ends_in_jump(s))
        run_defers_down_to(mark);
    defers.len = mark;
}

static void block(Stmt *s) {
    line("{");
    indent++;
    block_body(s);
    indent--;
    line("}");
}

static void stmt(Stmt *s) {
    switch (s->kind) {
    case S_BLOCK:
        block(s);
        break;
    case S_LET:
        if (s->init)
            line("%s = %s;", decl_var(s->sym->type, s->sym->cname), expr(s->init));
        else
            line("%s = {0};", decl_var(s->sym->type, s->sym->cname));
        break;
    case S_ASSIGN: {
        Type *t = s->lhs->type;
        if (!strcmp(s->op, "=")) {
            line("%s = %s;", expr(s->lhs), expr(s->rhs));
            break;
        }
        char *op = xstrndup(s->op, strlen(s->op) - 1);
        if (is_float(t)) {
            line("%s %s= %s;", expr(s->lhs), op, expr(s->rhs));
            break;
        }
        /* evaluate the place once, then apply the checked operator */
        int n = tmp_counter++;
        line("{");
        indent++;
        line("%s *kv_p%d = &%s;", t->cname, n, expr(s->lhs));
        line("*kv_p%d = %s;", n, int_binop(op, t, strfmt("*kv_p%d", n), expr(s->rhs), s->pos));
        indent--;
        line("}");
        break;
    }
    case S_EXPR:
        line("%s;", expr(s->expr));
        break;
    case S_IF: {
        line("if %s", cond(s->expr));
        block(s->then);
        Stmt *e = s->els;
        while (e) {
            if (e->kind == S_IF) {
                line("else if %s", cond(e->expr));
                block(e->then);
                e = e->els;
            } else {
                line("else");
                block(e);
                e = NULL;
            }
        }
        break;
    }
    case S_WHILE:
        line("while %s", cond(s->expr));
        list_push(&loop_marks, (void *)(intptr_t)defers.len);
        block(s->body);
        loop_marks.len--;
        break;
    case S_FOR: {
        Type *t = s->sym->type;
        int n = tmp_counter++;
        line("for (%s = %s, kv_end%d = %s; %s < kv_end%d; %s++)", decl_var(t, s->sym->cname), expr(s->expr), n,
             expr(s->hi), s->sym->cname, n, s->sym->cname);
        list_push(&loop_marks, (void *)(intptr_t)defers.len);
        block(s->body);
        loop_marks.len--;
        break;
    }
    case S_RETURN:
        if (defers.len == 0) {
            if (s->expr)
                line("return %s;", expr(s->expr));
            else
                line("return;");
            break;
        }
        line("{");
        indent++;
        if (s->expr)
            line("%s = %s;", decl_var(cur_fn->ret, "kv_ret"), expr(s->expr));
        run_defers_down_to(0);
        line(s->expr ? "return kv_ret;" : "return;");
        indent--;
        line("}");
        break;
    case S_BREAK:
    case S_CONTINUE: {
        int mark = (int)(intptr_t)loop_marks.data[loop_marks.len - 1];
        const char *kw = s->kind == S_BREAK ? "break" : "continue";
        if (defers.len == mark) {
            line("%s;", kw);
            break;
        }
        line("{");
        indent++;
        run_defers_down_to(mark);
        line("%s;", kw);
        indent--;
        line("}");
        break;
    }
    case S_DEFER:
        list_push(&defers, s);
        break;
    }
}

/* ---------- types ---------- */

static void emit_value_type(Type *t) {
    if (t->emitted || !is_value_aggregate(t))
        return;
    if (t->kind == TY_ARRAY) {
        emit_value_type(t->elem);
        line("struct %s { %s; };", t->cname, decl_var(t->elem, strfmt("a[%llu]", (unsigned long long)t->len)));
    } else {
        Decl *d = t->decl;
        for (int i = 0; i < d->fields.len; i++)
            emit_value_type(((Param *)d->fields.data[i])->type);
        line("struct %s {", t->cname);
        indent++;
        for (int i = 0; i < d->fields.len; i++) {
            Param *f = d->fields.data[i];
            line("%s;", decl_var(f->type, f->cname));
        }
        if (d->fields.len == 0)
            line("char kv_empty;");
        indent--;
        line("};");
    }
    t->emitted = true;
}

static void emit_types(void) {
    List *types = all_types();
    for (int i = 0; i < types->len; i++) {
        Type *t = types->data[i];
        if (t->kind == TY_STRUCT || t->kind == TY_ARRAY || t->kind == TY_SLICE)
            line("typedef struct %s %s;", t->cname, t->cname);
    }
    for (int i = 0; i < types->len; i++) {
        Type *t = types->data[i];
        if (t->kind == TY_SLICE)
            line("struct %s { %s *ptr; size_t len; };", t->cname, t->elem->cname);
    }
    for (int i = 0; i < types->len; i++)
        emit_value_type(types->data[i]);
    for (int i = 0; i < types->len; i++) {
        Type *t = types->data[i];
        if (t->kind != TY_SLICE)
            continue;
        const char *S = t->cname, *M = t->mangle, *E = t->elem->cname;
        line("static inline %s *kv_sidx_%s(%s s, int64_t i, const char *l) { return &s.ptr[kv_idx(i, s.len, l)]; }",
             E, M, S);
        line("static inline %s kv_sub_%s(%s *p, uint64_t n, int64_t lo, int64_t hi, const char *l) { "
             "if (lo < 0 || hi < lo || (uint64_t)hi > n) kv_trap(l, \"slice bounds out of range\"); "
             "%s r = { p ? p + lo : p, (size_t)(hi - lo) }; return r; }",
             S, M, E, S);
        line("static inline %s kv_subs_%s(%s s, int64_t lo, int64_t hi, bool has_hi, const char *l) { "
             "return kv_sub_%s(s.ptr, s.len, lo, has_hi ? hi : (int64_t)s.len, l); }",
             S, M, S, M);
    }
}

/* ---------- functions ---------- */

static char *prototype(Decl *d, bool with_names) {
    Buf b = {0};
    buf_printf(&b, "%s %s(", d->ret->cname, d->cname);
    for (int i = 0; i < d->params.len; i++) {
        Param *p = d->params.data[i];
        buf_printf(&b, "%s%s", i ? ", " : "",
                   with_names ? decl_var(p->type, p->cname) : p->type->cname);
    }
    if (d->variadic)
        buf_puts(&b, ", ...");
    if (d->params.len == 0 && !d->variadic)
        buf_puts(&b, "void");
    buf_puts(&b, ")");
    return b.buf;
}

static void emit_fn(Decl *d) {
    cur_fn = d;
    defers.len = 0;
    loop_marks.len = 0;
    line("%s", prototype(d, true));
    line("{");
    indent++;
    block_body(d->body);
    if (d->ret != ty_void)
        line("kv_trap(%s, \"reached end of function without returning a value\");", loc(d->pos));
    indent--;
    line("}");
    line("%s", "");
}

char *gen_program(Program *prog) {
    out = (Buf){0};
    buf_puts(&out, "/* generated by kelvinc; do not edit */\n");
    buf_puts(&out, prelude);
    line("%s", "");
    emit_types();
    line("%s", "");

    Decl *main_fn = NULL;
    for (int i = 0; i < prog->decls.len; i++) {
        Decl *d = prog->decls.data[i];
        if (d->kind == D_FN) {
            line("%s;", prototype(d, false));
            if (!d->is_extern && !strcmp(d->name, "main"))
                main_fn = d;
        }
    }
    line("%s", "");
    for (int i = 0; i < prog->decls.len; i++) {
        Decl *d = prog->decls.data[i];
        if (d->kind == D_VAR)
            line("%s = %s;", decl_var(d->type, d->cname), d->init ? expr(d->init) : "{0}");
    }
    line("%s", "");
    for (int i = 0; i < prog->decls.len; i++) {
        Decl *d = prog->decls.data[i];
        if (d->kind == D_FN && !d->is_extern)
            emit_fn(d);
    }

    if (main_fn) {
        const char *args = main_fn->params.len ? "(int32_t)argc, (uint8_t **)argv" : "";
        line("int main(int argc, char **argv)");
        line("{");
        indent++;
        line("(void)argc;");
        line("(void)argv;");
        if (main_fn->ret == ty_void) {
            line("kv_main(%s);", args);
            line("return 0;");
        } else {
            line("return (int)kv_main(%s);", args);
        }
        indent--;
        line("}");
    }
    return out.buf;
}
