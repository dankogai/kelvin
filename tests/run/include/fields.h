/* a C struct whose fields are named like Kelvin's types (#36) */
struct fields {
    long i64;
    unsigned char u8;
};

/* a C struct with a field named addr, also behind a typedef (#37) */
struct place {
    int addr;
};
typedef struct place place_t;
