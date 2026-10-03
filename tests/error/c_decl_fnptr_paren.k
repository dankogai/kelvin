// error: 'f' looks like a C function-pointer declaration: write 'var f:(...):size_t' (#31)
#import <stddef.h> as C
main():i32 {
    size_t (*f)(size_t);
    return 0;
}
