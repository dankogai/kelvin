/* sema.c - name resolution and type checking */
#include "kelvin.h"

#include <string.h>

typedef struct Scope {
    List syms;
    struct Scope *up;
} Scope;

static List structs, fns, globals;
static List used_cnames;      /* C names taken in the current function */
static List global_cnames;    /* C names taken at file scope */
static Scope *scope;
static Decl *cur_fn;
static int loop_depth;
static bool in_defer;

/* ---------- C name hygiene ---------- */

static const char *c_reserved[] = {
    "auto", "break", "case", "char", "const", "continue", "default", "do", "double",
    "else", "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long",
    "register", "restrict", "return", "short", "signed", "sizeof", "static", "struct",
    "switch", "typedef", "union", "unsigned", "void", "volatile", "while", "bool",
    "true", "false", "main", "errno", "stdin", "stdout", "stderr", "assert", "offsetof",
    "NULL", "alignas", "alignof", "noreturn", "static_assert", "thread_local", NULL,
};

static bool needs_rename(const char *name) {
    size_t n = strlen(name);
    if (name[0] == '_' && (name[1] == '_' || (name[1] >= 'A' && name[1] <= 'Z')))
        return true;
    if (n >= 2 && !strcmp(name + n - 2, "_t"))
        return true;
    for (int i = 0; c_reserved[i]; i++)
        if (!strcmp(name, c_reserved[i]))
            return true;
    return false;
}

static bool in_list(List *l, const char *s) {
    for (int i = 0; i < l->len; i++)
        if (!strcmp(l->data[i], s))
            return true;
    return false;
}

/* C spelling of a Kelvin identifier that is safe from C keywords, libc
   macros and reserved names. */
static char *c_safe(const char *name) { return needs_rename(name) ? strfmt("%s_", name) : xstrdup(name); }

static char *local_cname(const char *name) {
    char *base = c_safe(name);
    char *c = base;
    for (int n = 1; in_list(&used_cnames, c) || in_list(&global_cnames, c); n++)
        c = strfmt("%s_%d", base, n);
    list_push(&used_cnames, c);
    return c;
}

/* ---------- scopes ---------- */

static void push_scope(void) {
    Scope *s = xcalloc(1, sizeof *s);
    s->up = scope;
    scope = s;
}

static void pop_scope(void) { scope = scope->up; }

static Sym *declare_local(const char *name, Type *type, bool mut) {
    Sym *s = xcalloc(1, sizeof *s);
    s->name = (char *)name;
    s->cname = local_cname(name);
    s->type = type;
    s->mut = mut;
    list_push(&scope->syms, s);
    return s;
}

static Decl *find_decl(List *l, const char *name) {
    for (int i = 0; i < l->len; i++) {
        Decl *d = l->data[i];
        if (!strcmp(d->name, name))
            return d;
    }
    return NULL;
}

static Sym *lookup(const char *name) {
    for (Scope *s = scope; s; s = s->up)
        for (int i = s->syms.len - 1; i >= 0; i--) {
            Sym *sym = s->syms.data[i];
            if (!strcmp(sym->name, name))
                return sym;
        }
    Decl *g = find_decl(&globals, name);
    return g ? g->sym : NULL;
}

/* ---------- types ---------- */

static Type *resolve_type(TypeExpr *te, bool allow_void) {
    Type *t = NULL;
    switch (te->kind) {
    case TE_NAME: {
        t = prim_type(te->name);
        if (!t) {
            Decl *d = find_decl(&structs, te->name);
            if (!d)
                error_at(te->pos, "unknown type '%s'", te->name);
            t = d->type;
        }
        break;
    }
    case TE_PTR:
        return ptr_to(resolve_type(te->elem, true));
    case TE_ARRAY:
        t = array_of(resolve_type(te->elem, false), te->len);
        break;
    case TE_SLICE:
        t = slice_of(resolve_type(te->elem, false));
        break;
    }
    if (t == ty_void && !allow_void)
        error_at(te->pos, "'void' is only allowed as a return type or behind a pointer");
    return t;
}

static bool assignable(Type *from, Type *to) {
    if (from == to)
        return true;
    if (from->kind == TY_NULL && to->kind == TY_PTR)
        return true;
    /* any pointer converts implicitly to *void, like C (but not back) */
    if (from->kind == TY_PTR && to->kind == TY_PTR && to->elem == ty_void)
        return true;
    return false;
}

static void expect_assignable(Expr *e, Type *to, const char *what) {
    if (!assignable(e->type, to))
        error_at(e->pos, "%s: expected %s, found %s", what, to->name, e->type->name);
}

/* ---------- expressions ---------- */

static Type *check_expr(Expr *e, Type *want);

static bool is_untyped(Expr *e) {
    switch (e->kind) {
    case E_INT:
    case E_FLOAT:
    case E_NULL:
        return true;
    case E_UNARY:
        return !strcmp(e->op, "-") || !strcmp(e->op, "~") ? is_untyped(e->lhs) : false;
    case E_BINARY: {
        const char *op = e->op;
        if (!strcmp(op, "<<") || !strcmp(op, ">>"))
            return is_untyped(e->lhs);
        bool arith = strchr("+-*/%&|^", op[0]) && strcmp(op, "&&") != 0;
        return arith && is_untyped(e->lhs) && is_untyped(e->rhs);
    }
    default:
        return false;
    }
}

static bool int_fits(uint64_t mag, bool neg, Type *t) {
    if (t->is_signed) {
        uint64_t max = (UINT64_C(1) << (t->bits - 1)) - 1;
        return neg ? mag <= max + 1 : mag <= max;
    }
    if (neg)
        return mag == 0;
    return t->bits == 64 || mag < (UINT64_C(1) << t->bits);
}

static Type *check_int_lit(Expr *e, Type *want) {
    if (want && is_float(want))
        return want;
    if (want && is_int(want)) {
        if (!int_fits(e->ival, e->neg, want))
            error_at(e->pos, "integer literal %s%llu does not fit in %s", e->neg ? "-" : "",
                     (unsigned long long)e->ival, want->name);
        return want;
    }
    if (int_fits(e->ival, e->neg, ty_i32))
        return ty_i32;
    if (int_fits(e->ival, e->neg, ty_i64))
        return ty_i64;
    if (int_fits(e->ival, e->neg, ty_u64))
        return ty_u64;
    error_at(e->pos, "integer literal does not fit in any integer type");
}

/* Is e a place that can be assigned or have its address taken?
   *mut reports whether the place may be modified. */
static bool place_info(Expr *e, bool *mut) {
    switch (e->kind) {
    case E_IDENT:
        *mut = e->sym->mut;
        return true;
    case E_UNARY:
        if (!strcmp(e->op, "*")) {
            *mut = true;
            return true;
        }
        return false;
    case E_INDEX: {
        Type *t = e->lhs->type;
        if (t->kind == TY_SLICE || t->kind == TY_PTR) {
            *mut = true;
            return true;
        }
        return place_info(e->lhs, mut);
    }
    case E_FIELD: {
        Type *t = e->lhs->type;
        if (t->kind == TY_PTR) {
            *mut = true;
            return true;
        }
        if (t->kind == TY_STRUCT)
            return place_info(e->lhs, mut);
        return false;
    }
    default:
        return false;
    }
}

static void require_mutable_place(Expr *e, const char *what) {
    bool mut = false;
    if (!place_info(e, &mut))
        error_at(e->pos, "%s requires a variable, field, element or dereference", what);
    if (!mut)
        error_at(e->pos, "%s requires a mutable place; declare it with 'var' instead of 'let'", what);
}

static bool is_cmp(const char *op) {
    return !strcmp(op, "==") || !strcmp(op, "!=") || !strcmp(op, "<") || !strcmp(op, "<=") ||
           !strcmp(op, ">") || !strcmp(op, ">=");
}

static void check_binary(Expr *e, Type *want) {
    const char *op = e->op;
    if (!strcmp(op, "&&") || !strcmp(op, "||")) {
        check_expr(e->lhs, ty_bool);
        check_expr(e->rhs, ty_bool);
        expect_assignable(e->lhs, ty_bool, strfmt("left operand of '%s'", op));
        expect_assignable(e->rhs, ty_bool, strfmt("right operand of '%s'", op));
        e->type = ty_bool;
        return;
    }
    if (!strcmp(op, "<<") || !strcmp(op, ">>")) {
        Type *lt = check_expr(e->lhs, want);
        Type *rt = check_expr(e->rhs, NULL);
        if (!is_int(lt))
            error_at(e->lhs->pos, "left operand of '%s' must be an integer, found %s", op, lt->name);
        if (!is_int(rt))
            error_at(e->rhs->pos, "shift amount must be an integer, found %s", rt->name);
        e->type = lt;
        return;
    }

    bool cmp = is_cmp(op);
    Type *operand_want = cmp ? NULL : want;
    Type *lt, *rt;
    if (is_untyped(e->lhs) && !is_untyped(e->rhs)) {
        rt = check_expr(e->rhs, operand_want);
        lt = check_expr(e->lhs, rt);
    } else {
        lt = check_expr(e->lhs, operand_want);
        rt = check_expr(e->rhs, lt);
    }
    /* `null == p` / `p == null` */
    if (lt->kind == TY_NULL && rt->kind == TY_PTR)
        lt = e->lhs->type = rt;
    if (rt->kind == TY_NULL && lt->kind == TY_PTR)
        rt = e->rhs->type = lt;
    if (lt != rt)
        error_at(e->pos, "operands of '%s' have different types: %s and %s (use 'as' to convert)", op,
                 lt->name, rt->name);

    if (!strcmp(op, "==") || !strcmp(op, "!=")) {
        if (!(is_numeric(lt) || lt->kind == TY_BOOL || lt->kind == TY_PTR))
            error_at(e->pos, "cannot compare values of type %s with '%s'", lt->name, op);
        e->type = ty_bool;
    } else if (cmp) {
        if (!is_numeric(lt))
            error_at(e->pos, "cannot order values of type %s with '%s'", lt->name, op);
        e->type = ty_bool;
    } else if (!strcmp(op, "+") || !strcmp(op, "-") || !strcmp(op, "*") || !strcmp(op, "/")) {
        if (!is_numeric(lt))
            error_at(e->pos, "operator '%s' needs numbers, found %s", op, lt->name);
        e->type = lt;
    } else {
        /* %, wrapping ops, bitwise ops */
        if (!is_int(lt))
            error_at(e->pos, "operator '%s' needs integers, found %s", op, lt->name);
        e->type = lt;
    }
}

static bool cast_ok(Type *from, Type *to) {
    if (from == to)
        return true;
    if (is_numeric(from) && is_numeric(to))
        return true;
    if (from->kind == TY_BOOL && is_int(to))
        return true;
    if (from->kind == TY_PTR && to->kind == TY_PTR)
        return true;
    if (from->kind == TY_NULL && to->kind == TY_PTR)
        return true;
    bool from_word = from == ty_usize || from == ty_isize || from == ty_u64 || from == ty_i64;
    bool to_word = to == ty_usize || to == ty_isize || to == ty_u64 || to == ty_i64;
    if (from->kind == TY_PTR && to_word)
        return true;
    if (from_word && to->kind == TY_PTR)
        return true;
    return false;
}

static void check_call(Expr *e) {
    Decl *fn = find_decl(&fns, e->name);
    if (!fn) {
        if (lookup(e->name))
            error_at(e->pos, "'%s' is a variable, not a function", e->name);
        error_at(e->pos, "unknown function '%s'", e->name);
    }
    e->fn = fn;
    int nparams = fn->params.len;
    if (e->args.len < nparams || (!fn->variadic && e->args.len > nparams))
        error_at(e->pos, "'%s' takes %s%d argument%s, but %d %s given", fn->name, fn->variadic ? "at least " : "",
                 nparams, nparams == 1 ? "" : "s", e->args.len, e->args.len == 1 ? "was" : "were");
    for (int i = 0; i < e->args.len; i++) {
        Expr *a = e->args.data[i];
        if (i < nparams) {
            Param *p = fn->params.data[i];
            check_expr(a, p->type);
            expect_assignable(a, p->type, strfmt("argument %d of '%s'", i + 1, fn->name));
        } else {
            Type *t = check_expr(a, NULL);
            if (t->kind == TY_VOID || t->kind == TY_NULL)
                error_at(a->pos, "cannot pass %s as a variadic argument", t->name);
        }
    }
    e->type = fn->ret;
}

static Type *check_expr(Expr *e, Type *want) {
    switch (e->kind) {
    case E_INT:
        e->type = check_int_lit(e, want);
        break;
    case E_FLOAT:
        if (want && is_int(want))
            error_at(e->pos, "float literal used where %s is expected", want->name);
        e->type = want && is_float(want) ? want : ty_f64;
        break;
    case E_STR:
        e->type = ptr_to(ty_u8);
        break;
    case E_BOOL:
        e->type = ty_bool;
        break;
    case E_NULL:
        e->type = want && want->kind == TY_PTR ? want : ty_null;
        break;
    case E_IDENT: {
        Sym *s = lookup(e->name);
        if (!s) {
            if (find_decl(&fns, e->name))
                error_at(e->pos, "function '%s' used as a value (function pointers are not supported yet)",
                         e->name);
            error_at(e->pos, "unknown identifier '%s'", e->name);
        }
        e->sym = s;
        e->type = s->type;
        break;
    }
    case E_UNARY: {
        const char *op = e->op;
        if (!strcmp(op, "-")) {
            Type *t = check_expr(e->lhs, want);
            if (!is_numeric(t) || (is_int(t) && !t->is_signed))
                error_at(e->pos, "unary '-' needs a signed number, found %s (use 0 -%% x to wrap)", t->name);
            e->type = t;
        } else if (!strcmp(op, "!")) {
            Type *t = check_expr(e->lhs, ty_bool);
            if (t != ty_bool)
                error_at(e->pos, "'!' needs a bool, found %s (write x == 0 for integers)", t->name);
            e->type = ty_bool;
        } else if (!strcmp(op, "~")) {
            Type *t = check_expr(e->lhs, want);
            if (!is_int(t))
                error_at(e->pos, "'~' needs an integer, found %s", t->name);
            e->type = t;
        } else if (!strcmp(op, "*")) {
            Type *t = check_expr(e->lhs, NULL);
            if (t->kind != TY_PTR)
                error_at(e->pos, "cannot dereference a value of type %s", t->name);
            if (t->elem == ty_void)
                error_at(e->pos, "cannot dereference *void; cast it to a typed pointer first");
            e->type = t->elem;
        } else { /* & */
            check_expr(e->lhs, NULL);
            require_mutable_place(e->lhs, "taking an address");
            e->type = ptr_to(e->lhs->type);
        }
        break;
    }
    case E_BINARY:
        check_binary(e, want);
        break;
    case E_CALL:
        check_call(e);
        break;
    case E_INDEX: {
        Type *t = check_expr(e->lhs, NULL);
        Type *it = check_expr(e->rhs, NULL);
        if (!is_int(it))
            error_at(e->rhs->pos, "index must be an integer, found %s", it->name);
        if (t->kind == TY_ARRAY || t->kind == TY_SLICE)
            e->type = t->elem;
        else if (t->kind == TY_PTR && t->elem != ty_void)
            e->type = t->elem;
        else
            error_at(e->pos, "cannot index a value of type %s", t->name);
        break;
    }
    case E_SLICE: {
        Type *t = check_expr(e->lhs, NULL);
        if (e->rhs && !is_int(check_expr(e->rhs, ty_usize)))
            error_at(e->rhs->pos, "slice bound must be an integer, found %s", e->rhs->type->name);
        if (e->hi && !is_int(check_expr(e->hi, ty_usize)))
            error_at(e->hi->pos, "slice bound must be an integer, found %s", e->hi->type->name);
        if (t->kind == TY_ARRAY) {
            require_mutable_place(e->lhs, "slicing an array");
        } else if (t->kind == TY_PTR) {
            if (t->elem == ty_void)
                error_at(e->pos, "cannot slice *void");
            if (!e->hi)
                error_at(e->pos, "slicing a pointer needs an explicit upper bound");
        } else if (t->kind != TY_SLICE) {
            error_at(e->pos, "cannot slice a value of type %s", t->name);
        }
        e->type = slice_of(t->elem);
        break;
    }
    case E_FIELD: {
        Type *t = check_expr(e->lhs, NULL);
        Type *st = t->kind == TY_PTR ? t->elem : t;
        if (st->kind == TY_STRUCT) {
            for (int i = 0; i < st->decl->fields.len; i++) {
                Param *f = st->decl->fields.data[i];
                if (!strcmp(f->name, e->name)) {
                    e->type = f->type;
                    return e->type;
                }
            }
            error_at(e->pos, "struct %s has no field '%s'", st->name, e->name);
        }
        if (t->kind == TY_ARRAY && !strcmp(e->name, "len")) {
            e->type = ty_usize;
            break;
        }
        if (t->kind == TY_SLICE && !strcmp(e->name, "len")) {
            e->type = ty_usize;
            break;
        }
        if (t->kind == TY_SLICE && !strcmp(e->name, "ptr")) {
            e->type = ptr_to(t->elem);
            break;
        }
        error_at(e->pos, "type %s has no field '%s'", t->name, e->name);
    }
    case E_CAST: {
        Type *to = resolve_type(e->texpr, false);
        Type *from = check_expr(e->lhs, is_numeric(to) ? NULL : to);
        if (!cast_ok(from, to))
            error_at(e->pos, "cannot cast %s to %s", from->name, to->name);
        e->target = to;
        e->type = to;
        break;
    }
    case E_STRUCTLIT: {
        Decl *d = find_decl(&structs, e->name);
        if (!d)
            error_at(e->pos, "unknown struct '%s'", e->name);
        for (int i = 0; i < e->names.len; i++) {
            char *name = e->names.data[i];
            Param *field = NULL;
            for (int j = 0; j < d->fields.len; j++)
                if (!strcmp(((Param *)d->fields.data[j])->name, name))
                    field = d->fields.data[j];
            Expr *v = e->args.data[i];
            if (!field)
                error_at(v->pos, "struct %s has no field '%s'", d->name, name);
            for (int j = 0; j < i; j++)
                if (!strcmp(e->names.data[j], name))
                    error_at(v->pos, "field '%s' is initialized twice", name);
            check_expr(v, field->type);
            expect_assignable(v, field->type, strfmt("field '%s'", name));
        }
        e->type = d->type;
        break;
    }
    case E_ARRAYLIT: {
        Type *elem = want && want->kind == TY_ARRAY ? want->elem : NULL;
        for (int i = 0; i < e->args.len; i++) {
            Expr *v = e->args.data[i];
            Type *t = check_expr(v, elem);
            if (!elem) {
                if (t->kind == TY_NULL || t->kind == TY_VOID)
                    error_at(v->pos, "cannot infer the element type of this array literal");
                elem = t;
            }
            expect_assignable(v, elem, "array element");
        }
        if (want && want->kind == TY_ARRAY && want->len != (uint64_t)e->args.len)
            error_at(e->pos, "array literal has %d elements, but %s needs %llu", e->args.len, want->name,
                     (unsigned long long)want->len);
        e->type = array_of(elem, (uint64_t)e->args.len);
        break;
    }
    case E_SIZEOF:
        e->target = resolve_type(e->texpr, false);
        e->type = ty_usize;
        break;
    }
    return e->type;
}

/* ---------- statements ---------- */

static void check_stmt(Stmt *s);

static void check_block(Stmt *s) {
    push_scope();
    for (int i = 0; i < s->stmts.len; i++)
        check_stmt(s->stmts.data[i]);
    pop_scope();
}

static void check_stmt(Stmt *s) {
    switch (s->kind) {
    case S_BLOCK:
        check_block(s);
        break;
    case S_LET: {
        Type *t = s->texpr ? resolve_type(s->texpr, false) : NULL;
        if (s->init) {
            Type *it = check_expr(s->init, t);
            if (t)
                expect_assignable(s->init, t, strfmt("initializer of '%s'", s->name));
            else if (it->kind == TY_NULL)
                error_at(s->init->pos, "cannot infer a type from null; write '%s: *T = null'", s->name);
            else if (it->kind == TY_VOID)
                error_at(s->init->pos, "cannot initialize '%s' with a void value", s->name);
            else
                t = it;
        } else if (!t) {
            error_at(s->pos, "'%s' needs a type or an initializer", s->name);
        } else if (!s->mut) {
            error_at(s->pos, "'let %s' needs an initializer (use 'var' for a zero-initialized variable)",
                     s->name);
        }
        s->sym = declare_local(s->name, t, s->mut);
        break;
    }
    case S_ASSIGN: {
        Type *lt = check_expr(s->lhs, NULL);
        require_mutable_place(s->lhs, "assignment");
        if (!strcmp(s->op, "=")) {
            check_expr(s->rhs, lt);
            expect_assignable(s->rhs, lt, "assignment");
            break;
        }
        /* compound assignment reuses the binary operator rules */
        char *bop = xstrndup(s->op, strlen(s->op) - 1);
        Expr probe = {.kind = E_BINARY, .pos = s->pos, .op = bop, .lhs = s->lhs, .rhs = s->rhs};
        check_binary(&probe, lt);
        if (probe.type != lt)
            error_at(s->pos, "'%s' cannot be applied to %s", s->op, lt->name);
        break;
    }
    case S_EXPR:
        check_expr(s->expr, NULL);
        if (s->expr->kind != E_CALL)
            error_at(s->expr->pos, "expression result is unused");
        break;
    case S_IF:
        check_expr(s->expr, ty_bool);
        expect_assignable(s->expr, ty_bool, "if condition");
        check_block(s->then);
        if (s->els)
            check_stmt(s->els);
        break;
    case S_WHILE:
        check_expr(s->expr, ty_bool);
        expect_assignable(s->expr, ty_bool, "while condition");
        loop_depth++;
        check_block(s->body);
        loop_depth--;
        break;
    case S_FOR: {
        Type *t;
        if (is_untyped(s->expr) && !is_untyped(s->hi)) {
            t = check_expr(s->hi, NULL);
            check_expr(s->expr, t);
        } else {
            t = check_expr(s->expr, NULL);
            check_expr(s->hi, t);
        }
        if (!is_int(t))
            error_at(s->expr->pos, "for-range bounds must be integers, found %s", t->name);
        if (s->hi->type != t)
            error_at(s->hi->pos, "for-range bounds have different types: %s and %s", t->name, s->hi->type->name);
        push_scope();
        s->sym = declare_local(s->name, t, false);
        loop_depth++;
        check_block(s->body);
        loop_depth--;
        pop_scope();
        break;
    }
    case S_RETURN:
        if (in_defer)
            error_at(s->pos, "cannot return from inside a defer");
        if (cur_fn->ret == ty_void) {
            if (s->expr)
                error_at(s->expr->pos, "function '%s' does not return a value", cur_fn->name);
        } else {
            if (!s->expr)
                error_at(s->pos, "function '%s' must return a %s", cur_fn->name, cur_fn->ret->name);
            check_expr(s->expr, cur_fn->ret);
            expect_assignable(s->expr, cur_fn->ret, "return value");
        }
        break;
    case S_BREAK:
    case S_CONTINUE:
        if (loop_depth == 0)
            error_at(s->pos, "'%s' outside of a loop", s->kind == S_BREAK ? "break" : "continue");
        break;
    case S_DEFER: {
        bool saved_defer = in_defer;
        int saved_depth = loop_depth;
        in_defer = true;
        loop_depth = 0;
        check_stmt(s->body);
        in_defer = saved_defer;
        loop_depth = saved_depth;
        break;
    }
    }
}

/* ---------- declarations ---------- */

static void check_struct_cycles(Type *t, Pos pos) {
    if (t->kind == TY_ARRAY) {
        check_struct_cycles(t->elem, pos);
        return;
    }
    if (t->kind != TY_STRUCT)
        return;
    if (t->visit == 2)
        return;
    if (t->visit == 1)
        error_at(pos, "struct %s contains itself by value; use a pointer", t->name);
    t->visit = 1;
    for (int i = 0; i < t->decl->fields.len; i++) {
        Param *f = t->decl->fields.data[i];
        check_struct_cycles(f->type, f->pos);
    }
    t->visit = 2;
}

static void declare_global_name(Decl *d, List *kind_list) {
    if (find_decl(&structs, d->name) || find_decl(&fns, d->name) || find_decl(&globals, d->name))
        error_at(d->pos, "'%s' is already declared", d->name);
    if (prim_type(d->name))
        error_at(d->pos, "'%s' is a built-in type name", d->name);
    list_push(kind_list, d);
}

void check_program(Program *prog) {
    /* pass 1: names of structs, functions and globals, so that declaration
       order never matters */
    for (int i = 0; i < prog->decls.len; i++) {
        Decl *d = prog->decls.data[i];
        switch (d->kind) {
        case D_STRUCT:
            declare_global_name(d, &structs);
            d->cname = c_safe(d->name);
            d->type = struct_type(d, d->cname);
            break;
        case D_FN:
            declare_global_name(d, &fns);
            d->cname = !strcmp(d->name, "main") && !d->is_extern ? xstrdup("kv_main")
                       : d->is_extern                         ? xstrdup(d->name)
                                                              : c_safe(d->name);
            break;
        case D_VAR:
            declare_global_name(d, &globals);
            d->cname = c_safe(d->name);
            break;
        }
        list_push(&global_cnames, d->cname);
    }

    /* pass 2: struct fields */
    for (int i = 0; i < structs.len; i++) {
        Decl *d = structs.data[i];
        for (int j = 0; j < d->fields.len; j++) {
            Param *f = d->fields.data[j];
            for (int k = 0; k < j; k++)
                if (!strcmp(((Param *)d->fields.data[k])->name, f->name))
                    error_at(f->pos, "duplicate field '%s'", f->name);
            f->type = resolve_type(f->texpr, false);
            f->cname = c_safe(f->name);
        }
    }
    for (int i = 0; i < structs.len; i++) {
        Decl *d = structs.data[i];
        check_struct_cycles(d->type, d->pos);
    }

    /* pass 3: function signatures */
    for (int i = 0; i < fns.len; i++) {
        Decl *d = fns.data[i];
        d->ret = d->ret_texpr ? resolve_type(d->ret_texpr, true) : ty_void;
        for (int j = 0; j < d->params.len; j++) {
            Param *p = d->params.data[j];
            for (int k = 0; k < j; k++)
                if (!strcmp(((Param *)d->params.data[k])->name, p->name))
                    error_at(p->pos, "duplicate parameter '%s'", p->name);
            p->type = resolve_type(p->texpr, false);
        }
        if (d->variadic && d->params.len == 0)
            error_at(d->pos, "a variadic function needs at least one named parameter");
        if (!strcmp(d->name, "main") && !d->is_extern) {
            if (d->ret != ty_void && d->ret != ty_i32)
                error_at(d->pos, "main must return i32 or nothing");
            bool ok = d->params.len == 0;
            if (d->params.len == 2) {
                Param *a = d->params.data[0], *b = d->params.data[1];
                ok = a->type == ty_i32 && b->type == ptr_to(ptr_to(ty_u8));
            }
            if (!ok)
                error_at(d->pos, "main takes no parameters or (argc: i32, argv: **u8)");
        }
    }

    /* pass 4: globals; initializers must be literals so they are constant in C */
    for (int i = 0; i < globals.len; i++) {
        Decl *d = globals.data[i];
        Type *t = d->texpr ? resolve_type(d->texpr, false) : NULL;
        if (d->init) {
            ExprKind k = d->init->kind;
            if (k != E_INT && k != E_FLOAT && k != E_BOOL && k != E_NULL && k != E_STR)
                error_at(d->init->pos, "global initializers must be literals for now");
            Type *it = check_expr(d->init, t);
            if (t)
                expect_assignable(d->init, t, strfmt("initializer of '%s'", d->name));
            else if (it->kind == TY_NULL)
                error_at(d->init->pos, "cannot infer a type from null");
            else
                t = it;
        } else if (!t) {
            error_at(d->pos, "'%s' needs a type or an initializer", d->name);
        } else if (!d->mut) {
            error_at(d->pos, "'let %s' needs an initializer", d->name);
        }
        d->type = t;
        d->sym = xcalloc(1, sizeof(Sym));
        d->sym->name = d->name;
        d->sym->cname = d->cname;
        d->sym->type = t;
        d->sym->mut = d->mut;
    }

    /* pass 5: bodies */
    for (int i = 0; i < fns.len; i++) {
        Decl *d = fns.data[i];
        if (d->is_extern)
            continue;
        cur_fn = d;
        used_cnames = (List){0};
        push_scope();
        for (int j = 0; j < d->params.len; j++) {
            Param *p = d->params.data[j];
            p->sym = declare_local(p->name, p->type, false);
            p->cname = p->sym->cname;
        }
        check_block(d->body);
        pop_scope();
    }
}
