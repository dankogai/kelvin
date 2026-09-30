/* parser.c - recursive-descent parser producing the AST */
#include "kelvin.h"

#include <string.h>

static Token *toks;
static int ntoks, cur;
/* Inside `if`/`while`/`for` headers, `Name {` starts the body, not a
   struct literal. Parentheses re-enable struct literals. */
static bool no_struct_lit;

static Token *peek(void) { return &toks[cur]; }

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
    switch (t->kind) {
    case TK_EOF: return "end of file";
    case TK_STR: return "string literal";
    case TK_INT: return strfmt("number '%s'", t->text);
    case TK_FLOAT: return strfmt("number '%s'", t->text);
    default: return strfmt("'%s'", t->text);
    }
}

static Token *expect_p(const char *s) {
    if (!is_p(peek(), s))
        error_at(peek()->pos, "expected '%s', found %s", s, desc(peek()));
    return advance();
}

static void expect_kw(const char *s) {
    if (!is_kw(peek(), s))
        error_at(peek()->pos, "expected '%s', found %s", s, desc(peek()));
    advance();
}

static char *expect_ident(const char *what) {
    if (peek()->kind != TK_IDENT)
        error_at(peek()->pos, "expected %s, found %s", what, desc(peek()));
    return advance()->text;
}

/* ---------- types ---------- */

static TypeExpr *parse_type(void) {
    Token *t = peek();
    TypeExpr *te = xcalloc(1, sizeof *te);
    te->pos = t->pos;
    if (accept_p("*")) {
        te->kind = TE_PTR;
        te->elem = parse_type();
        return te;
    }
    if (accept_p("[")) {
        if (accept_p("]")) {
            te->kind = TE_SLICE;
            te->elem = parse_type();
            return te;
        }
        Token *n = advance();
        if (n->kind != TK_INT)
            error_at(n->pos, "array length must be an integer literal");
        if (n->ival == 0)
            error_at(n->pos, "array length must be positive");
        expect_p("]");
        te->kind = TE_ARRAY;
        te->len = n->ival;
        te->elem = parse_type();
        return te;
    }
    if (accept_p("(")) {
        TypeExpr *inner = parse_type();
        expect_p(")");
        return inner;
    }
    if (t->kind == TK_IDENT) {
        advance();
        te->kind = TE_NAME;
        te->name = t->text;
        return te;
    }
    error_at(t->pos, "expected a type, found %s", desc(t));
}

/* ---------- expressions ---------- */

static Expr *parse_expr(void);

static Expr *new_expr(ExprKind kind, Pos pos) {
    Expr *e = xcalloc(1, sizeof *e);
    e->kind = kind;
    e->pos = pos;
    return e;
}

static Expr *parse_primary(void) {
    Token *t = peek();
    if (t->kind == TK_INT) {
        advance();
        Expr *e = new_expr(E_INT, t->pos);
        e->ival = t->ival;
        return e;
    }
    if (t->kind == TK_FLOAT) {
        advance();
        Expr *e = new_expr(E_FLOAT, t->pos);
        e->fval = t->fval;
        return e;
    }
    if (t->kind == TK_STR) {
        /* adjacent string literals are concatenated, as in C */
        Buf b = {0};
        buf_puts(&b, "");
        while (peek()->kind == TK_STR) {
            Token *s = advance();
            buf_putn(&b, s->sval, s->slen);
        }
        Expr *e = new_expr(E_STR, t->pos);
        e->sval = b.buf;
        e->slen = b.len;
        return e;
    }
    if (accept_kw("true") || accept_kw("false")) {
        Expr *e = new_expr(E_BOOL, t->pos);
        e->ival = !strcmp(t->text, "true");
        return e;
    }
    if (accept_kw("null"))
        return new_expr(E_NULL, t->pos);
    if (accept_kw("sizeof")) {
        Expr *e = new_expr(E_SIZEOF, t->pos);
        expect_p("(");
        e->texpr = parse_type();
        expect_p(")");
        return e;
    }
    if (t->kind == TK_IDENT) {
        advance();
        if (!no_struct_lit && is_p(peek(), "{")) {
            Expr *e = new_expr(E_STRUCTLIT, t->pos);
            e->name = t->text;
            advance();
            while (!is_p(peek(), "}")) {
                list_push(&e->names, expect_ident("field name"));
                expect_p(":");
                list_push(&e->args, parse_expr());
                if (!accept_p(","))
                    break;
            }
            expect_p("}");
            return e;
        }
        Expr *e = new_expr(E_IDENT, t->pos);
        e->name = t->text;
        return e;
    }
    if (accept_p("(")) {
        bool saved = no_struct_lit;
        no_struct_lit = false;
        Expr *e = parse_expr();
        no_struct_lit = saved;
        expect_p(")");
        e->paren = true;
        return e;
    }
    if (accept_p("[")) {
        bool saved = no_struct_lit;
        no_struct_lit = false;
        Expr *e = new_expr(E_ARRAYLIT, t->pos);
        while (!is_p(peek(), "]")) {
            list_push(&e->args, parse_expr());
            if (!accept_p(","))
                break;
        }
        expect_p("]");
        no_struct_lit = saved;
        if (e->args.len == 0)
            error_at(t->pos, "array literals must have at least one element");
        return e;
    }
    error_at(t->pos, "expected an expression, found %s", desc(t));
}

static Expr *parse_postfix(void) {
    Expr *e = parse_primary();
    for (;;) {
        Token *t = peek();
        if (is_p(t, "(")) {
            if (e->kind != E_IDENT || e->paren)
                error_at(t->pos, "only named functions can be called");
            advance();
            bool saved = no_struct_lit;
            no_struct_lit = false;
            Expr *call = new_expr(E_CALL, e->pos);
            call->name = e->name;
            while (!is_p(peek(), ")")) {
                list_push(&call->args, parse_expr());
                if (!accept_p(","))
                    break;
            }
            expect_p(")");
            no_struct_lit = saved;
            e = call;
        } else if (is_p(t, "[")) {
            advance();
            bool saved = no_struct_lit;
            no_struct_lit = false;
            Expr *lo = is_p(peek(), "..") ? NULL : parse_expr();
            Expr *x;
            if (accept_p("..")) {
                x = new_expr(E_SLICE, t->pos);
                x->rhs = lo;
                x->hi = is_p(peek(), "]") ? NULL : parse_expr();
            } else {
                x = new_expr(E_INDEX, t->pos);
                x->rhs = lo;
            }
            x->lhs = e;
            expect_p("]");
            no_struct_lit = saved;
            e = x;
        } else if (is_p(t, ".")) {
            advance();
            Expr *x = new_expr(E_FIELD, t->pos);
            x->lhs = e;
            x->name = expect_ident("field name");
            e = x;
        } else {
            return e;
        }
    }
}

static Expr *parse_unary(void) {
    Token *t = peek();
    if (is_p(t, "-") || is_p(t, "!") || is_p(t, "~") || is_p(t, "*") || is_p(t, "&")) {
        advance();
        Expr *operand = parse_unary();
        /* fold negative literals so that i32 min is expressible */
        if (is_p(t, "-") && operand->kind == E_INT && !operand->neg && !operand->paren) {
            operand->neg = operand->ival != 0;
            operand->pos = t->pos;
            return operand;
        }
        Expr *e = new_expr(E_UNARY, t->pos);
        e->op = t->text;
        e->lhs = operand;
        return e;
    }
    return parse_postfix();
}

static Expr *parse_cast(void) {
    Expr *e = parse_unary();
    while (is_kw(peek(), "as")) {
        Token *t = advance();
        Expr *c = new_expr(E_CAST, t->pos);
        c->lhs = e;
        c->texpr = parse_type();
        e = c;
    }
    return e;
}

/* Unlike C, bitwise operators bind tighter than comparisons, so
   `x & 1 == 0` means `(x & 1) == 0`. */
static int binprec(Token *t) {
    if (t->kind != TK_PUNCT)
        return -1;
    static const struct { const char *op; int prec; } table[] = {
        {"||", 1}, {"&&", 2},
        {"==", 3}, {"!=", 3}, {"<", 3}, {"<=", 3}, {">", 3}, {">=", 3},
        {"|", 4}, {"^", 5}, {"&", 6}, {"<<", 7}, {">>", 7},
        {"+", 8}, {"-", 8}, {"+%", 8}, {"-%", 8},
        {"*", 9}, {"/", 9}, {"%", 9}, {"*%", 9},
    };
    for (size_t i = 0; i < sizeof table / sizeof table[0]; i++)
        if (!strcmp(t->text, table[i].op))
            return table[i].prec;
    return -1;
}

static Expr *parse_binary(int minprec) {
    Expr *lhs = parse_cast();
    for (;;) {
        Token *t = peek();
        int prec = binprec(t);
        if (prec < 0 || prec < minprec)
            return lhs;
        if (prec == 3 && lhs->kind == E_BINARY && binprec(&(Token){.kind = TK_PUNCT, .text = (char *)lhs->op}) == 3 &&
            !lhs->paren)
            error_at(t->pos, "comparison operators cannot be chained; use && or parentheses");
        advance();
        Expr *e = new_expr(E_BINARY, t->pos);
        e->op = t->text;
        e->lhs = lhs;
        e->rhs = parse_binary(prec + 1);
        lhs = e;
    }
}

static Expr *parse_expr(void) { return parse_binary(1); }

static Expr *parse_cond(void) {
    bool saved = no_struct_lit;
    no_struct_lit = true;
    Expr *e = parse_expr();
    no_struct_lit = saved;
    return e;
}

/* ---------- statements ---------- */

static Stmt *parse_stmt(void);

static Stmt *new_stmt(StmtKind kind, Pos pos) {
    Stmt *s = xcalloc(1, sizeof *s);
    s->kind = kind;
    s->pos = pos;
    return s;
}

static Stmt *parse_block(void) {
    Token *t = expect_p("{");
    Stmt *s = new_stmt(S_BLOCK, t->pos);
    while (!is_p(peek(), "}")) {
        if (peek()->kind == TK_EOF)
            error_at(t->pos, "unterminated block");
        list_push(&s->stmts, parse_stmt());
    }
    advance();
    return s;
}

static const char *assign_ops[] = {"=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=",
                                   "<<=", ">>=", "+%=", "-%=", "*%=", NULL};

static Stmt *parse_simple_stmt(void) {
    Pos pos = peek()->pos;
    Expr *e = parse_expr();
    for (int i = 0; assign_ops[i]; i++) {
        if (is_p(peek(), assign_ops[i])) {
            Token *op = advance();
            Stmt *s = new_stmt(S_ASSIGN, op->pos);
            s->op = op->text;
            s->lhs = e;
            s->rhs = parse_expr();
            expect_p(";");
            return s;
        }
    }
    Stmt *s = new_stmt(S_EXPR, pos);
    s->expr = e;
    expect_p(";");
    return s;
}

static Stmt *parse_let(void) {
    Token *t = advance(); /* let | var */
    Stmt *s = new_stmt(S_LET, t->pos);
    s->mut = !strcmp(t->text, "var");
    s->name = expect_ident("variable name");
    if (accept_p(":"))
        s->texpr = parse_type();
    if (accept_p("="))
        s->init = parse_expr();
    expect_p(";");
    return s;
}

static Stmt *parse_if(void) {
    Token *t = advance();
    Stmt *s = new_stmt(S_IF, t->pos);
    s->expr = parse_cond();
    s->then = parse_block();
    if (accept_kw("else"))
        s->els = is_kw(peek(), "if") ? parse_if() : parse_block();
    return s;
}

static Stmt *parse_stmt(void) {
    Token *t = peek();
    if (is_p(t, "{"))
        return parse_block();
    if (is_kw(t, "let") || is_kw(t, "var"))
        return parse_let();
    if (is_kw(t, "if"))
        return parse_if();
    if (accept_kw("while")) {
        Stmt *s = new_stmt(S_WHILE, t->pos);
        s->expr = parse_cond();
        s->body = parse_block();
        return s;
    }
    if (accept_kw("for")) {
        Stmt *s = new_stmt(S_FOR, t->pos);
        s->name = expect_ident("loop variable");
        expect_kw("in");
        s->expr = parse_cond();
        expect_p("..");
        s->hi = parse_cond();
        s->body = parse_block();
        return s;
    }
    if (accept_kw("return")) {
        Stmt *s = new_stmt(S_RETURN, t->pos);
        if (!is_p(peek(), ";"))
            s->expr = parse_expr();
        expect_p(";");
        return s;
    }
    if (accept_kw("break")) {
        expect_p(";");
        return new_stmt(S_BREAK, t->pos);
    }
    if (accept_kw("continue")) {
        expect_p(";");
        return new_stmt(S_CONTINUE, t->pos);
    }
    if (accept_kw("defer")) {
        Stmt *s = new_stmt(S_DEFER, t->pos);
        s->body = is_p(peek(), "{") ? parse_block() : parse_simple_stmt();
        return s;
    }
    return parse_simple_stmt();
}

/* ---------- declarations ---------- */

static Decl *new_decl(DeclKind kind, Pos pos) {
    Decl *d = xcalloc(1, sizeof *d);
    d->kind = kind;
    d->pos = pos;
    return d;
}

static Decl *parse_fn(bool is_extern, Pos pos) {
    Decl *d = new_decl(D_FN, pos);
    d->is_extern = is_extern;
    d->name = expect_ident("function name");
    expect_p("(");
    while (!is_p(peek(), ")")) {
        if (is_p(peek(), "...")) {
            Token *dots = advance();
            if (!is_extern)
                error_at(dots->pos, "only extern functions can be variadic");
            d->variadic = true;
            if (!is_p(peek(), ")"))
                error_at(peek()->pos, "'...' must be the last parameter");
            break;
        }
        Param *p = xcalloc(1, sizeof *p);
        p->pos = peek()->pos;
        p->name = expect_ident("parameter name");
        expect_p(":");
        p->texpr = parse_type();
        list_push(&d->params, p);
        if (!accept_p(","))
            break;
    }
    expect_p(")");
    if (accept_p("->"))
        d->ret_texpr = parse_type();
    if (is_extern)
        expect_p(";");
    else
        d->body = parse_block();
    return d;
}

static Decl *parse_struct(Pos pos) {
    Decl *d = new_decl(D_STRUCT, pos);
    d->name = expect_ident("struct name");
    expect_p("{");
    while (!is_p(peek(), "}")) {
        Param *f = xcalloc(1, sizeof *f);
        f->pos = peek()->pos;
        f->name = expect_ident("field name");
        expect_p(":");
        f->texpr = parse_type();
        list_push(&d->fields, f);
        if (!accept_p(","))
            break;
    }
    expect_p("}");
    return d;
}

Program *parse(Token *tokens, int n) {
    toks = tokens;
    ntoks = n;
    cur = 0;
    Program *prog = xcalloc(1, sizeof *prog);
    while (peek()->kind != TK_EOF) {
        Token *t = peek();
        if (accept_kw("extern")) {
            expect_kw("fn");
            list_push(&prog->decls, parse_fn(true, t->pos));
        } else if (accept_kw("fn")) {
            list_push(&prog->decls, parse_fn(false, t->pos));
        } else if (accept_kw("struct")) {
            list_push(&prog->decls, parse_struct(t->pos));
        } else if (is_kw(t, "let") || is_kw(t, "var")) {
            Stmt *s = parse_let();
            Decl *d = new_decl(D_VAR, s->pos);
            d->name = s->name;
            d->mut = s->mut;
            d->texpr = s->texpr;
            d->init = s->init;
            list_push(&prog->decls, d);
        } else {
            error_at(t->pos, "expected a declaration (fn, extern fn, struct, let, var), found %s", desc(t));
        }
    }
    return prog;
}
