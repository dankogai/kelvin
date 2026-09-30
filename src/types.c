/* types.c - interned types: identical types are pointer-equal */
#include "kelvin.h"

#include <string.h>

Type *ty_void, *ty_bool, *ty_null;
Type *ty_i8, *ty_i16, *ty_i32, *ty_i64, *ty_isize;
Type *ty_u8, *ty_u16, *ty_u32, *ty_u64, *ty_usize;
Type *ty_f32, *ty_f64;

static List prims;
static List composites; /* pointers, arrays, slices, structs in creation order */

static Type *mk(TypeKind kind, const char *name, const char *cname, const char *mangle) {
    Type *t = xcalloc(1, sizeof *t);
    t->kind = kind;
    t->name = xstrdup(name);
    t->cname = xstrdup(cname);
    t->mangle = xstrdup(mangle);
    return t;
}

static Type *prim(TypeKind kind, int bits, bool is_signed, const char *name, const char *cname,
                  const char *mangle) {
    Type *t = mk(kind, name, cname, mangle);
    t->bits = bits;
    t->is_signed = is_signed;
    list_push(&prims, t);
    return t;
}

void types_init(void) {
    ty_void = prim(TY_VOID, 0, false, "void", "void", "v");
    ty_bool = prim(TY_BOOL, 8, false, "bool", "bool", "b");
    ty_i8 = prim(TY_INT, 8, true, "i8", "int8_t", "i8");
    ty_i16 = prim(TY_INT, 16, true, "i16", "int16_t", "i16");
    ty_i32 = prim(TY_INT, 32, true, "i32", "int32_t", "i32");
    ty_i64 = prim(TY_INT, 64, true, "i64", "int64_t", "i64");
    ty_isize = prim(TY_INT, 64, true, "isize", "ptrdiff_t", "isize");
    ty_u8 = prim(TY_INT, 8, false, "u8", "uint8_t", "u8");
    ty_u16 = prim(TY_INT, 16, false, "u16", "uint16_t", "u16");
    ty_u32 = prim(TY_INT, 32, false, "u32", "uint32_t", "u32");
    ty_u64 = prim(TY_INT, 64, false, "u64", "uint64_t", "u64");
    ty_usize = prim(TY_INT, 64, false, "usize", "size_t", "usize");
    ty_f32 = prim(TY_FLOAT, 32, true, "f32", "float", "f32");
    ty_f64 = prim(TY_FLOAT, 64, true, "f64", "double", "f64");
    ty_null = mk(TY_NULL, "null", "void *", "n");
}

Type *prim_type(const char *name) {
    for (int i = 0; i < prims.len; i++) {
        Type *t = prims.data[i];
        if (!strcmp(t->name, name))
            return t;
    }
    return NULL;
}

Type *ptr_to(Type *elem) {
    for (int i = 0; i < composites.len; i++) {
        Type *t = composites.data[i];
        if (t->kind == TY_PTR && t->elem == elem)
            return t;
    }
    Type *t = mk(TY_PTR, strfmt("*%s", elem->name), strfmt("%s *", elem->cname),
                 strfmt("p%s", elem->mangle));
    t->elem = elem;
    list_push(&composites, t);
    return t;
}

/* Fixed arrays are wrapped in a C struct so they are values: they can be
   assigned, passed and returned without decaying to pointers. */
Type *array_of(Type *elem, uint64_t len) {
    for (int i = 0; i < composites.len; i++) {
        Type *t = composites.data[i];
        if (t->kind == TY_ARRAY && t->elem == elem && t->len == len)
            return t;
    }
    char *mangle = strfmt("a%llu_%s", (unsigned long long)len, elem->mangle);
    Type *t = mk(TY_ARRAY, strfmt("[%llu]%s", (unsigned long long)len, elem->name),
                 strfmt("kv_%s", mangle), mangle);
    t->elem = elem;
    t->len = len;
    list_push(&composites, t);
    return t;
}

Type *slice_of(Type *elem) {
    for (int i = 0; i < composites.len; i++) {
        Type *t = composites.data[i];
        if (t->kind == TY_SLICE && t->elem == elem)
            return t;
    }
    char *mangle = strfmt("s%s", elem->mangle);
    Type *t = mk(TY_SLICE, strfmt("[]%s", elem->name), strfmt("kv_%s", mangle), mangle);
    t->elem = elem;
    list_push(&composites, t);
    return t;
}

Type *struct_type(Decl *d, const char *cname) {
    Type *t = mk(TY_STRUCT, d->name, cname, strfmt("S%zu%s", strlen(d->name), d->name));
    t->decl = d;
    list_push(&composites, t);
    return t;
}

List *all_types(void) { return &composites; }

bool is_int(Type *t) { return t->kind == TY_INT; }
bool is_float(Type *t) { return t->kind == TY_FLOAT; }
bool is_numeric(Type *t) { return t->kind == TY_INT || t->kind == TY_FLOAT; }
bool is_value_aggregate(Type *t) { return t->kind == TY_STRUCT || t->kind == TY_ARRAY; }
