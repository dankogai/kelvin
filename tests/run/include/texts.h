/* text of the C types kelvinc cannot see, and C structs with fields named
   like Kelvin's types (#36) */
#include <stdint.h>

typedef unsigned char xmlChar;
typedef char gchar;

static inline const unsigned char *column_text(void) { return (const unsigned char *)"31"; }
static inline const char *const_text(void) { return "32"; }
static inline signed char *signed_text(void) {
    static signed char s[] = "33";
    return s;
}
static inline unsigned char *unsigned_text(void) {
    static unsigned char s[] = "34";
    return s;
}
static inline xmlChar *get_prop(void) { return (xmlChar *)"42"; }
static inline gchar *get_str(void) {
    static gchar s[] = "17";
    return s;
}

typedef union {
    int64_t i64;
    uint64_t u64;
    double f64;
} object_union;
typedef struct object {
    int type;
    object_union via;
} object;
typedef struct {
    long i64;
    unsigned char u8;
} tfields;
static inline object make_object(int64_t n) {
    object o = {1, {.i64 = n}};
    return o;
}
