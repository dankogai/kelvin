/* a C struct with a field named like a Kelvin property */
struct blob { unsigned long size; int hex; };
static inline struct blob make_blob(void) { struct blob b = {5, 6}; return b; }
