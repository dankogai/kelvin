/* parser.c - recursive descent over C's grammar with Kelvin's changes:

   - declarations put the type after the name: `var x: int`, `fn f() -> int`
   - types are postfix: `int^` is a pointer to int
   - dereference is postfix: `p^`, so `p->m` is written `p^.m`
   - XOR is binary `~` (and `~=`); `^` only means "pointer"

   Operator precedence is otherwise exactly C's. */
#include "kelvin.h"

#include <string.h>

static Token *toks;
static int cur;

static Token *peek(void) { return &toks[cur]; }
static Token *peek2(void) { return toks[cur].kind == TK_EOF ? &toks[cur] : &toks[cur + 1]; }

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
static const char *base_words[] = {"i8",  "i16",  "i32", "i64", "i128", "u8",       "u16", "u32",
                                   "u64", "u128", "f32", "f64", "bool", "_Complex", "void", NULL};

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
};

static bool is_base_word(Token *t) {
    for (int i = 0; base_words[i]; i++)
        if (is_kw(t, base_words[i]))
            return true;
    return false;
}

static void reject_c_int_name(Token *t) {
    for (size_t i = 0; i < sizeof dead_words / sizeof dead_words[0]; i++)
        if (is_kw(t, dead_words[i].c))
            error_at(t->pos, "'%s' is not a Kelvin type; use %s", t->text, dead_words[i].kelvin);
}

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
static Type *parse_type(void) {
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
        if (name->kind != TK_IDENT && (!is_base_word(name) || is_kw(name, "_Complex")))
            error_at(name->pos, "expected a type, found %s", desc(name));
        advance();
        base->name = name->text;
        parse_qualifiers(base);
        if ((is_kw(name, "f32") || is_kw(name, "f64")) && accept_kw("_Complex"))
            base->name = strfmt("%s _Complex", name->text);
    }
    parse_qualifiers(base);

    Type *t = base;
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
            error_at(tok->pos, "pointer types are written with a postfix '^', as in 'int^'");
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

/* ---------- expressions ---------- */

static Expr *parse_expr(void);
static Expr *parse_cast(void);
static Expr *parse_initializer(void);

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
            Expr *x = new_expr(E_INDEX, t->pos);
            x->a = e;
            x->b = parse_expr();
            expect_p("]");
            e = x;
        } else if (accept_p("(")) {
            Expr *x = new_expr(E_CALL, t->pos);
            x->a = e;
            while (!is_p(peek(), ")")) {
                list_push(&x->items, parse_assign());
                if (!accept_p(","))
                    break;
            }
            expect_p(")");
            e = x;
        } else if (accept_p(".")) {
            Expr *x = new_expr(E_FIELD, t->pos);
            x->a = e;
            x->text = expect_ident("a member name");
            e = x;
        } else if (accept_p("^")) {
            Expr *x = new_expr(E_DEREF, t->pos);
            x->a = e;
            e = x;
        } else if (is_p(t, "++") || is_p(t, "--")) {
            advance();
            Expr *x = new_expr(E_POSTFIX, t->pos);
            x->op = t->text;
            x->a = e;
            e = x;
        } else if (is_p(t, "->")) {
            error_at(t->pos, "write 'p^.member' instead of 'p->member'");
        } else {
            return e;
        }
    }
}

static Expr *parse_primary(void) {
    Token *t = peek();
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
    if (accept_p("(")) {
        Expr *e = parse_expr();
        expect_p(")");
        e->paren = true;
        return e;
    }
    error_at(t->pos, "expected an expression, found %s", desc(t));
}

static Expr *parse_unary(void) {
    Token *t = peek();
    if (is_p(t, "++") || is_p(t, "--") || is_p(t, "&") || is_p(t, "-") || is_p(t, "+") || is_p(t, "!") ||
        is_p(t, "~")) {
        advance();
        Expr *e = new_expr(E_PREFIX, t->pos);
        e->op = t->text;
        e->a = (is_p(t, "++") || is_p(t, "--")) ? parse_unary() : parse_cast();
        return e;
    }
    if (is_p(t, "*"))
        error_at(t->pos, "dereference is a postfix '^' in Kelvin: write 'p^' instead of '*p'");
    if (accept_kw("sizeof")) {
        if (is_p(peek(), "(") && starts_type(peek2())) {
            advance();
            Expr *e = new_expr(E_SIZEOF_TYPE, t->pos);
            e->type = parse_type();
            expect_p(")");
            return e;
        }
        Expr *e = new_expr(E_SIZEOF_EXPR, t->pos);
        e->a = parse_unary();
        return e;
    }
    return parse_postfix_ops(parse_primary());
}

/* cast := '(' type ')' cast | '(' type ')' '{' ... '}' postfix-ops | unary */
static Expr *parse_cast(void) {
    Token *t = peek();
    if (is_p(t, "(") && starts_type(peek2())) {
        advance();
        Type *type = parse_type();
        expect_p(")");
        if (is_p(peek(), "{")) {
            Expr *e = new_expr(E_COMPOUND, t->pos);
            e->type = type;
            e->a = parse_initializer();
            return parse_postfix_ops(e);
        }
        Expr *e = new_expr(E_CAST, t->pos);
        e->type = type;
        e->a = parse_cast();
        return e;
    }
    return parse_unary();
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
        lhs = e;
    }
}

static Expr *parse_conditional(void) {
    Expr *c = parse_binary(1);
    Token *t = peek();
    if (!accept_p("?"))
        return c;
    Expr *e = new_expr(E_TERNARY, t->pos);
    e->a = c;
    e->b = parse_expr();
    expect_p(":");
    e->c = parse_conditional();
    return e;
}

static const char *assign_ops[] = {"=", "+=", "-=", "*=", "/=", "%=", "<<=", ">>=", "&=", "~=", "|=", NULL};

static Expr *parse_assign(void) {
    Expr *lhs = parse_conditional();
    Token *t = peek();
    for (int i = 0; assign_ops[i]; i++)
        if (is_p(t, assign_ops[i])) {
            advance();
            Expr *e = new_expr(E_BINARY, t->pos);
            e->op = t->text;
            e->a = lhs;
            e->b = parse_assign();
            return e;
        }
    return lhs;
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
                x->text = expect_ident("a member name");
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

/* The Kelvin type of an initializer that can be inferred: an integer
   literal is i64 and a floating literal is f64 (optionally negated).
   Returns NULL otherwise; `true` and `false` are not inferred. */
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

/* name: type [= init], or (for variables) name = literal, where an
   integer literal is an i64 and a double literal is an f64 */
static Var *parse_var(bool with_init) {
    Var *v = xcalloc(1, sizeof *v);
    v->pos = peek()->pos;
    v->name = expect_ident("a name");
    if (with_init && is_p(peek(), "=")) {
        advance();
        v->init = parse_initializer();
        const char *inferred = literal_type(v->init);
        if (!inferred)
            error_at(v->pos, "'%s' needs a type: only integer literals (i64) and floating literals (f64) are inferred",
                     v->name);
        v->type = base_type(inferred, v->pos);
        return v;
    }
    expect_p(":");
    v->type = parse_type();
    if (with_init && accept_p("="))
        v->init = parse_initializer();
    return v;
}

/* after `var`: name: type [= init] {, name: type [= init]} */
static void parse_var_list(List *out) {
    do
        list_push(out, parse_var(true));
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

static Expr *parse_paren_expr(void) {
    expect_p("(");
    Expr *e = parse_expr();
    expect_p(")");
    return e;
}

static Stmt *parse_stmt(void) {
    Token *t = peek();
    Pos pos = t->pos;

    if (is_p(t, "{"))
        return parse_block();
    if (accept_p(";"))
        return new_stmt(S_EMPTY, pos);
    if ((is_kw(t, "static") || is_kw(t, "extern")) && is_kw(peek2(), "var")) {
        Stmt *s = new_stmt(S_VAR, pos);
        s->storage = parse_storage();
        advance();
        parse_var_list(&s->vars);
        expect_p(";");
        return s;
    }
    if (accept_kw("var")) {
        Stmt *s = new_stmt(S_VAR, pos);
        parse_var_list(&s->vars);
        expect_p(";");
        return s;
    }
    if (accept_kw("if")) {
        Stmt *s = new_stmt(S_IF, pos);
        s->expr = parse_paren_expr();
        s->body = parse_stmt();
        if (accept_kw("else"))
            s->els = parse_stmt();
        return s;
    }
    if (accept_kw("while")) {
        Stmt *s = new_stmt(S_WHILE, pos);
        s->expr = parse_paren_expr();
        s->body = parse_stmt();
        return s;
    }
    if (accept_kw("do")) {
        Stmt *s = new_stmt(S_DO, pos);
        s->body = parse_stmt();
        if (!accept_kw("while"))
            error_at(peek()->pos, "expected 'while' after the body of 'do'");
        s->expr = parse_paren_expr();
        expect_p(";");
        return s;
    }
    if (accept_kw("for")) {
        Stmt *s = new_stmt(S_FOR, pos);
        expect_p("(");
        if (is_kw(peek(), "var")) {
            s->init = new_stmt(S_VAR, advance()->pos);
            parse_var_list(&s->init->vars);
        } else if (!is_p(peek(), ";")) {
            s->init = new_stmt(S_EXPR, peek()->pos);
            s->init->expr = parse_expr();
        }
        expect_p(";");
        if (!is_p(peek(), ";"))
            s->expr = parse_expr();
        expect_p(";");
        if (!is_p(peek(), ")"))
            s->step = parse_expr();
        expect_p(")");
        s->body = parse_stmt();
        return s;
    }
    if (accept_kw("switch")) {
        Stmt *s = new_stmt(S_SWITCH, pos);
        s->expr = parse_paren_expr();
        s->body = parse_stmt();
        return s;
    }
    if (accept_kw("case")) {
        Stmt *s = new_stmt(S_CASE, pos);
        s->expr = parse_conditional();
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
        s->body = parse_stmt();
        return s;
    }
    if (starts_type(t))
        error_at(pos, "declarations start with 'var', as in 'var x: %s'", t->text);
    Stmt *s = new_stmt(S_EXPR, pos);
    s->expr = parse_expr();
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
    d->name = expect_ident("a function name");
    expect_p("(");
    while (!is_p(peek(), ")")) {
        if (accept_p("...")) {
            if (d->params.len == 0)
                error_at(pos, "a variadic function needs at least one named parameter");
            d->variadic = true;
            break;
        }
        list_push(&d->params, parse_var(false));
        if (!accept_p(","))
            break;
    }
    expect_p(")");
    if (accept_p(":"))
        d->ret = parse_type();
    if (!accept_p(";"))
        d->body = parse_block();
    return d;
}

static Decl *parse_record(Pos pos, DeclKind kind) {
    Decl *d = new_decl(kind, pos, NULL);
    if (kind == D_ENUM && is_p(peek(), "{"))
        d->name = NULL; /* anonymous enum: a group of int constants */
    else
        d->name = expect_ident("a tag name");
    if (accept_p("{")) {
        d->has_body = true;
        while (!is_p(peek(), "}")) {
            if (kind == D_ENUM) {
                Var *v = xcalloc(1, sizeof *v);
                v->pos = peek()->pos;
                v->name = expect_ident("an enumerator");
                if (accept_p("="))
                    v->init = parse_conditional();
                list_push(&d->members, v);
                if (!accept_p(","))
                    break;
            } else {
                do
                    list_push(&d->members, parse_var(false));
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
        if (peek()->kind == TK_IDENT && is_p(peek2(), "(")) {
            list_push(&prog->decls, parse_fn(t->pos, storage));
        } else if (accept_kw("var")) {
            Decl *d = new_decl(D_VAR, t->pos, storage);
            parse_var_list(&d->members);
            expect_p(";");
            list_push(&prog->decls, d);
        } else if (!storage && accept_kw("struct")) {
            list_push(&prog->decls, parse_record(t->pos, D_STRUCT));
        } else if (!storage && accept_kw("union")) {
            list_push(&prog->decls, parse_record(t->pos, D_UNION));
        } else if (!storage && accept_kw("enum")) {
            list_push(&prog->decls, parse_record(t->pos, D_ENUM));
        } else {
            error_at(peek()->pos, "expected a declaration (name(...): type, var, struct, union, enum), found %s", desc(peek()));
        }
    }
    return prog;
}
