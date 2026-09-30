/* kelvin.h - shared declarations for kelvinc

   Kelvin is C with a different surface syntax. kelvinc parses Kelvin and
   prints the equivalent C; the C compiler does all type checking, so the
   semantics and the ABI are C's by construction. */
#ifndef KELVIN_H
#define KELVIN_H

#include <stdbool.h>
#include <stddef.h>
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

void set_source(const char *file, const char *src);
_Noreturn void fatal(const char *fmt, ...);
_Noreturn void error_at(Pos p, const char *fmt, ...);

/* ---------- lexer.c ---------- */

typedef enum {
    TK_EOF,
    TK_IDENT,
    TK_KEYWORD,
    TK_NUMBER,  /* spelled exactly as in C, passed through verbatim */
    TK_CHAR,    /* verbatim, including quotes */
    TK_STRING,  /* verbatim, including quotes */
    TK_PUNCT,
    TK_IMPORT,  /* #import <x.h> as C; text is the header name, e.g. "<x.h>" */
} TokKind;

typedef struct {
    TokKind kind;
    Pos pos;
    char *text;
} Token;

Token *lex(const char *file, const char *src, int *ntoks);

/* ---------- AST ---------- */

/* Types are written postfix: `char const^[4]` is an array of four pointers
   to const char. */
typedef enum { T_BASE, T_PTR, T_ARRAY } TypeKind;

typedef struct Expr Expr;
typedef struct Type Type;

struct Type {
    TypeKind kind;
    Pos pos;
    char *name;       /* T_BASE: "int", "unsigned long", "struct Point" */
    bool is_const, is_volatile;
    Type *elem;       /* T_PTR, T_ARRAY */
    Expr *size;       /* T_ARRAY; NULL for [] */
};

typedef enum {
    E_LITERAL,   /* number or character constant, verbatim */
    E_STRING,    /* one or more adjacent string literals */
    E_IDENT,
    E_PREFIX,    /* op x: ++ -- & - + ! ~ */
    E_POSTFIX,   /* x op: ++ -- */
    E_DEREF,     /* x^ */
    E_BINARY,    /* includes assignment and comma */
    E_TERNARY,
    E_CALL,
    E_INDEX,
    E_FIELD,     /* x.name */
    E_CAST,      /* (type)x */
    E_COMPOUND,  /* (type){...} */
    E_SIZEOF_TYPE,
    E_SIZEOF_EXPR,
    E_INIT,      /* { ... } initializer list */
} ExprKind;

struct Expr {
    ExprKind kind;
    Pos pos;
    bool paren;       /* written inside parentheses */
    const char *op;
    Expr *a, *b, *c;  /* operands; E_TERNARY a ? b : c */
    char *text;       /* E_LITERAL, E_IDENT, E_FIELD member name */
    List items;       /* E_STRING pieces, E_CALL args, E_INIT values */
    List designators; /* E_INIT: char * per item (NULL if none) */
    Type *type;       /* E_CAST, E_COMPOUND, E_SIZEOF_TYPE */
};

typedef struct {
    char *name;
    Pos pos;
    Type *type;
    Expr *init;
} Var;   /* also a parameter, struct member or enumerator */

typedef enum {
    S_BLOCK,
    S_VAR,
    S_EXPR,
    S_EMPTY,
    S_IF,
    S_WHILE,
    S_DO,
    S_FOR,
    S_SWITCH,
    S_CASE,
    S_DEFAULT,
    S_BREAK,
    S_CONTINUE,
    S_RETURN,
    S_GOTO,
    S_LABEL,
} StmtKind;

typedef struct Stmt Stmt;
struct Stmt {
    StmtKind kind;
    Pos pos;
    List stmts;        /* S_BLOCK */
    const char *storage;  /* S_VAR: NULL, "static", "extern" */
    List vars;         /* S_VAR: Var * */
    Expr *expr;        /* condition, value, case label */
    Stmt *init;        /* S_FOR */
    Expr *step;        /* S_FOR */
    Stmt *body, *els;  /* loop body / if-then, else */
    char *name;        /* S_GOTO, S_LABEL */
};

typedef enum { D_IMPORT, D_FN, D_VAR, D_STRUCT, D_UNION, D_ENUM } DeclKind;

typedef struct {
    DeclKind kind;
    Pos pos;
    const char *storage;  /* NULL, "static", "extern" */
    char *name;           /* D_IMPORT: the header name, e.g. "<stdio.h>" */
    List params;          /* D_FN: Var * */
    bool variadic;
    Type *ret;            /* D_FN: NULL means void */
    Stmt *body;           /* D_FN: NULL for a prototype */
    List members;         /* D_STRUCT/D_UNION/D_ENUM: Var *; D_VAR: Var * */
    bool has_body;        /* D_STRUCT/D_UNION/D_ENUM: false for `struct P;` */
} Decl;

typedef struct {
    List decls;
} Program;

/* ---------- parser.c / codegen.c ---------- */

Program *parse(Token *toks, int ntoks);
char *gen_program(Program *prog, bool line_directives);

#endif
