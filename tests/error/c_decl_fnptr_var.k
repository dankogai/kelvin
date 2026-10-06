// a C function-pointer declaration after var in a body is one, not a
// function declared there (#31, #45)
#import <stddef.h> as C
let main():i32 {
    var size_t (*fp)(i32)
    return 0
}
// error: 'fp' looks like a C function-pointer declaration: write 'var fp:(...):size_t' (#31)
