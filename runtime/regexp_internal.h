/* regexp_internal.h - what runtime/regexp_parse.c, the parser of a pattern,
   and runtime/regexp.c, the compiler and the matcher, share (#157, #163):
   the flags, the tree, the parser's state and the helpers. kelvinc links
   the parser alone, with the Unicode tables, to check a $/.../ literal. */
#ifndef REGEXP_INTERNAL_H
#define REGEXP_INTERNAL_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

enum { RX_I = 1, RX_M = 2, RX_S = 4, RX_G = 8, RX_Y = 16, RX_D = 32, RX_U = 64, RX_B = 128 }; /* b (#171): bytes */
enum { CI_RANGE, CI_ESCAPE, CI_GC, CI_SCRIPT, CI_PROP }; /* the items of a class */
enum { LOOK_AHEAD, LOOK_NAHEAD, LOOK_BEHIND, LOOK_NBEHIND };
#define INF 0x7fffffff
#define MAX_GROUPS 127
#define NO_CP 0xFFFFFFFFu

typedef struct {
    uint32_t kind, a, b;
} Item;

typedef struct Node Node;
struct Node {
    int kind;
    uint32_t c;           /* N_CHAR */
    int min, max;         /* N_REPEAT */
    bool greedy;
    int group;            /* N_GROUP, N_BACKREF */
    int look;             /* N_LOOK */
    bool negate;          /* N_CLASS */
    Item *items;          /* N_CLASS */
    int nitems, icap;
    Node **kids;          /* N_SEQ, N_ALT; one for N_GROUP, N_REPEAT, N_LOOK */
    int nkids, kcap;
    char *name;           /* N_BACKREF by name */
    size_t at;            /* where in the pattern, for errors */
    uint32_t flags;       /* i, m and s where the node is, after (?ims-ims:...) modifiers */
};

enum {
    N_EMPTY, N_CHAR, N_ANY, N_CLASS, N_SEQ, N_ALT, N_GROUP, N_REPEAT, N_BOL, N_EOL, N_WORDB, N_NWORDB, N_BACKREF,
    N_LOOK, N_GRAPHEME
};

typedef struct {
    const uint8_t *pat;
    size_t len, i;
    uint32_t flags;
    int ngroups;
    char *names[MAX_GROUPS + 1];
    int max_backref;
    size_t max_backref_at;
} Parser;

/* an error in a pattern: ends the program, or in a check, returns to it */
void rx_fail(const uint8_t *pattern, const char *what, size_t at);
void *rx_alloc(size_t n);
void *rx_grow(void *p, size_t n);
uint32_t rx_cp_at(const uint8_t *p, int64_t n, int64_t pos, int *len);
uint32_t rx_cp_before(const uint8_t *p, int64_t n, int64_t pos, int *len);
int rx_utf8_put(uint8_t *out, uint32_t cp);
void rx_node_free(Node *n);
/* the tree of a pattern with its flags, p filled: the groups, their names */
Node *rx_parse_pattern(Parser *p, const uint8_t *pattern, const uint8_t *flags);

#endif
