// error: 'f' looks like a C function-pointer declaration: write 'var f:(...):size_t' (#31)
#import <stddef.h> as C
size_t (*f)(i64);
let main():i32 { return 0; }
