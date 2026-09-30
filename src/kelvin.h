/* kelvin.h - shared declarations for the Kelvin bootstrap compiler */
#ifndef KELVIN_H
#define KELVIN_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

/* ---------- util.c ---------- */

typedef struct {
    const char *file;
    int line, col;
} Pos;

typedef struct {
    void **data;
    int len, cap;
} List;

typedef struct {
    char *buf;
    size_t len, cap;
} Buf;

void *xmalloc(size_t n);
void *xcalloc(size_t n, size_t sz);
void *xrealloc(void *p, size_t n);
char *xstrdup(const char *s);
char *xstrndup(const char *s, size_t n);
char *strfmt(const char *fmt, ...);
void list_push(List *l, void *x);
void buf_puts(Buf *b, const char *s);
void buf_putn(Buf *b, const char *s, size_t n);
void buf_printf(Buf *b, const char *fmt, ...);
char *c_string_literal(const char *s, size_t n);

void set_source(const char *file, const char *src);
_Noreturn void fatal(const char *fmt, ...);
_Noreturn void error_at(Pos p, const char *fmt, ...);

/* ---------- lexer.c ---------- */

typedef enum {
    TK_EOF,
    TK_IDENT,
    TK_KEYWORD,
    TK_INT,
    TK_FLOAT,
    TK_STR,
    TK_PUNCT,
} TokKind;

typedef struct {
    TokKind kind;
    Pos pos;
    char *text;     /* spelling of identifier, keyword or punctuator */
    uint64_t ival;  /* integer and character literals */
    double fval;    /* float literals */
    char *sval;     /* decoded string literal bytes */
    size_t slen;
} Token;

Token *lex(const char *file, const char *src, int *ntoks);

/* ---------- types.c ---------- */

typedef enum {
    TY_VOID,
    TY_BOOL,
    TY_INT,
    TY_FLOAT,
    TY_PTR,
    TY_ARRAY,
    TY_SLICE,
    TY_STRUCT,
    TY_NULL,    /* type of a bare `null` before it meets a pointer */
} TypeKind;

typedef struct Type Type;
typedef struct Decl Decl;

struct Type {
    TypeKind kind;
    int bits;          /* TY_INT, TY_FLOAT */
    bool is_signed;    /* TY_INT */
    Type *elem;        /* TY_PTR, TY_ARRAY, TY_SLICE */
    uint64_t len;      /* TY_ARRAY */
    Decl *decl;        /* TY_STRUCT */
    char *name;        /* Kelvin spelling, for diagnostics */
    char *cname;       /* C spelling */
    char *mangle;      /* identifier-safe unique encoding */
    bool emitted;      /* codegen bookkeeping */
    int visit;         /* sema cycle detection */
};

extern Type *ty_void, *ty_bool, *ty_null;
extern Type *ty_i8, *ty_i16, *ty_i32, *ty_i64, *ty_isize;
extern Type *ty_u8, *ty_u16, *ty_u32, *ty_u64, *ty_usize;
extern Type *ty_f32, *ty_f64;

void types_init(void);
Type *prim_type(const char *name);
Type *ptr_to(Type *t);
Type *array_of(Type *t, uint64_t len);
Type *slice_of(Type *t);
Type *struct_type(Decl *d, const char *cname);
List *all_types(void);
bool is_int(Type *t);
bool is_float(Type *t);
bool is_numeric(Type *t);
bool is_value_aggregate(Type *t);

/* ---------- ast ---------- */

typedef enum { TE_NAME, TE_PTR, TE_ARRAY, TE_SLICE } TypeExprKind;

typedef struct TypeExpr TypeExpr;
struct TypeExpr {
    TypeExprKind kind;
    Pos pos;
    char *name;
    TypeExpr *elem;
    uint64_t len;
};

typedef struct Sym {
    char *name;
    char *cname;
    Type *type;
    bool mut;
} Sym;

typedef enum {
    E_INT,
    E_FLOAT,
    E_STR,
    E_BOOL,
    E_NULL,
    E_IDENT,
    E_UNARY,
    E_BINARY,
    E_CALL,
    E_INDEX,
    E_SLICE,
    E_FIELD,
    E_CAST,
    E_STRUCTLIT,
    E_ARRAYLIT,
    E_SIZEOF,
} ExprKind;

typedef struct Expr Expr;
struct Expr {
    ExprKind kind;
    Pos pos;
    Type *type;
    bool paren;         /* written inside parentheses */
    const char *op;     /* E_UNARY, E_BINARY */
    Expr *lhs, *rhs;    /* operands; E_INDEX lhs[rhs]; E_SLICE lhs[rhs..hi] */
    Expr *hi;
    List args;          /* E_CALL args, E_ARRAYLIT elems, E_STRUCTLIT values */
    List names;         /* E_STRUCTLIT field names (char *) */
    char *name;         /* E_IDENT, E_FIELD, E_CALL callee, E_STRUCTLIT type */
    uint64_t ival;      /* E_INT magnitude, E_BOOL */
    bool neg;           /* E_INT is negative */
    double fval;
    char *sval;
    size_t slen;
    TypeExpr *texpr;    /* E_CAST, E_SIZEOF */
    Sym *sym;           /* E_IDENT */
    Decl *fn;           /* E_CALL */
    Type *target;       /* E_SIZEOF, E_CAST resolved type */
};

typedef enum {
    S_BLOCK,
    S_LET,
    S_ASSIGN,
    S_EXPR,
    S_IF,
    S_WHILE,
    S_FOR,
    S_RETURN,
    S_BREAK,
    S_CONTINUE,
    S_DEFER,
} StmtKind;

typedef struct Stmt Stmt;
struct Stmt {
    StmtKind kind;
    Pos pos;
    List stmts;             /* S_BLOCK */
    char *name;             /* S_LET, S_FOR loop variable */
    bool mut;               /* S_LET: var (true) or let (false) */
    TypeExpr *texpr;        /* S_LET */
    Expr *init;             /* S_LET */
    const char *op;         /* S_ASSIGN: "=", "+=", ... */
    Expr *lhs, *rhs;        /* S_ASSIGN */
    Expr *expr;             /* S_EXPR, S_RETURN, S_IF/S_WHILE cond, S_FOR low */
    Expr *hi;               /* S_FOR high */
    Stmt *then, *els, *body;
    Sym *sym;               /* S_LET, S_FOR */
};

typedef struct {
    char *name;
    char *cname;
    Pos pos;
    TypeExpr *texpr;
    Type *type;
    Sym *sym;
} Param;   /* also used for struct fields */

typedef enum { D_FN, D_STRUCT, D_VAR } DeclKind;

struct Decl {
    DeclKind kind;
    Pos pos;
    char *name;
    char *cname;
    /* D_FN */
    bool is_extern, variadic;
    List params;            /* Param * */
    TypeExpr *ret_texpr;
    Type *ret;
    Stmt *body;
    /* D_STRUCT */
    List fields;            /* Param * */
    Type *type;
    /* D_VAR */
    bool mut;
    TypeExpr *texpr;
    Expr *init;
    Sym *sym;
};

typedef struct {
    List decls;             /* Decl * */
} Program;

/* ---------- parser.c / sema.c / codegen.c ---------- */

Program *parse(Token *toks, int ntoks);
void check_program(Program *prog);
char *gen_program(Program *prog);

/* ---------- runtime.c ---------- */

extern const char kelvin_runtime_c[];

#endif
