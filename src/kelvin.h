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
    TK_STRING,  /* verbatim, including quotes; also a template with no ${} */
    /* a template literal with ${...} (#39): its text before the first ${,
       between } and the next ${, and after the last }, each as a C string
       literal; the expressions' tokens come in between */
    TK_TPL_HEAD,
    TK_TPL_MIDDLE,
    TK_TPL_TAIL,
    TK_PUNCT,
    TK_IMPORT,  /* #import <x.h> as C; text is the header name, e.g. "<x.h>" */
} TokKind;

typedef struct {
    TokKind kind;
    Pos pos;
    char *text;
    int end_line;  /* the line the token ends on, after a multi-line template (#39) */
    bool tpl;      /* a template literal without ${...}, lexed as a TK_STRING */
} Token;

Token *lex(const char *file, const char *src, int *ntoks);

/* ---------- AST ---------- */

/* Types are written postfix: `char const^[4]` is an array of four pointers
   to const char. A function type `(i64, i64):bool` is C's pointer to a
   function (#31). `v.type` is v's type (#34), a T_TYPEOF where kelvinc
   cannot see it. */
typedef enum { T_BASE, T_PTR, T_ARRAY, T_FUNC, T_TYPEOF } TypeKind;

typedef struct Expr Expr;
typedef struct Type Type;

struct Type {
    TypeKind kind;
    Pos pos;
    char *name;       /* T_BASE: "int", "unsigned long", "struct Point";
                         T_TYPEOF: the value as written, for messages */
    bool is_const, is_volatile;
    Type *elem;       /* T_PTR, T_ARRAY; T_FUNC: the result (NULL: none);
                         T_TYPEOF: the type kelvinc sees, if any */
    Expr *size;       /* T_ARRAY; NULL for [] */
    List params;      /* T_FUNC: Type * per parameter */
    bool variadic;    /* T_FUNC: ends with ... */
    bool size_local;  /* T_ARRAY: the length names a local or a parameter;
                         T_TYPEOF: so does the value */
    Expr *of;         /* T_TYPEOF: the value whose type it is */
    bool unqual;      /* T_TYPEOF: without its qualifiers, as a value has */
};

typedef enum {
    E_LITERAL,   /* number or character constant, verbatim */
    E_STRING,    /* one or more adjacent string literals */
    E_TEMPLATE,  /* `a${x}b` (#39): items are E_STRING parts and values in turn */
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
    E_METHOD,    /* a.text(items): a method call */
    E_PROPERTY,  /* a.text: size, dec, hex, oct, bin */
    E_FUNC,      /* an anonymous function (#32): text is the C function
                    it becomes, type its function type */
} ExprKind;

struct Expr {
    ExprKind kind;
    Pos pos;
    bool paren;       /* written inside parentheses */
    bool is_bool;     /* kelvinc saw that it is a bool (#23) */
    const char *op;
    Expr *a, *b, *c;  /* operands; E_TERNARY a ? b : c */
    char *text;       /* E_LITERAL, E_IDENT, E_FIELD member name */
    List items;       /* E_STRING pieces, E_CALL args, E_INIT values */
    List designators; /* E_INIT: char * per item (NULL if none) */
    Type *type;       /* E_CAST, E_COMPOUND, E_SIZEOF_TYPE, E_FUNC */
};

typedef struct {
    char *name;
    Pos pos;
    Type *type;
    Expr *init;
    bool is_let;      /* a let (#27): C's const */
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
    S_FOR_IN,    /* for i in a..<b { } and for i in a...b { } (#28) */
    S_FOR_EACH,  /* for x in s { }: each element of a sequence (#30) */
    S_SWITCH,
    S_CASE,
    S_DEFAULT,
    S_BREAK,
    S_CONTINUE,
    S_RETURN,
    S_GOTO,
    S_LABEL,
} StmtKind;

/* what `for x in s` walks (#30) */
enum {
    EACH_POINTER,  /* s^, s.next^, ... up to 0 or nullptr; a nullptr s is empty */
    EACH_LIST,     /* node pointers along next, up to nullptr */
    EACH_ARRAY,    /* the elements, stopping early at 0 or nullptr */
    EACH_RECORDS,  /* the elements of an array of structs, all of them */
    EACH_UNSEEN,   /* a pointer whose type kelvinc cannot see, as EACH_POINTER */
};

typedef struct Stmt Stmt;
struct Stmt {
    StmtKind kind;
    Pos pos;
    List stmts;        /* S_BLOCK */
    const char *storage;  /* S_VAR: NULL, "static", "extern" */
    List vars;         /* S_VAR: Var * */
    Expr *expr;        /* condition, value, case label */
    Stmt *init;        /* S_FOR */
    Expr *step;        /* S_FOR; S_FOR_IN: the upper bound; S_FOR_EACH: a
                          let array parameter's declared length */
    Type *type;        /* S_FOR_IN, S_FOR_EACH: the loop variable's (NULL: unseen) */
    Type *elem;        /* S_FOR_EACH: what s holds (NULL: unseen); for a
                          list, the node's pointer */
    bool closed;       /* S_FOR_IN: a...b, not a..<b */
    bool from_argv;    /* S_FOR_EACH: s is main's argv, which C types char ** */
    int each;          /* S_FOR_EACH: EACH_* above */
    Stmt *body, *els;  /* loop body / if-then, else */
    char *name;        /* S_GOTO, S_LABEL, S_FOR_IN */
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
    /* D_FN that is a method, e.g. point.area(): f64 */
    Type *recv;           /* the receiver's type: struct point, f64, ... */
    char *recv_name;      /* as written before the dot: point, f64 */
    bool anon;            /* D_FN: an anonymous function (#32) */
} Decl;

typedef struct {
    List decls;
} Program;

/* ---------- parser.c / codegen.c ---------- */

Program *parse(Token *toks, int ntoks);
char *gen_program(Program *prog, bool line_directives);

#endif
