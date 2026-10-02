/* C types that kelvinc cannot see into, for .cstr */
#include <stddef.h>
typedef unsigned long long ticks_t;
typedef const char *name_t;
struct opaque { int a; };
static inline struct opaque make_opaque(void) { struct opaque o = {1}; return o; }
typedef char label_t[16];       /* a char array behind a typedef */
typedef char full_t[4];         /* filled to the end, with no NUL */
struct cs { const char *cstr; int size; };   /* a C field named cstr */
typedef unsigned char xmlChar;  /* as in libxml2 */
typedef void *handle_t;
typedef char *restrict rstr_t;
typedef double _Complex dc_t;
typedef unsigned char bytes_t[4];  /* binary, not text */
typedef char flex_t[];          /* a flexible array member, behind a typedef */
