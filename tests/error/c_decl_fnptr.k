// error: 'fp' looks like a C function-pointer declaration: write 'var fp:(...):size_t' (#31)
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:i32; y:i32; };
let f(x:i32, n:size_t, q:size_t^, r:u64) {
    size_t * fp^(size_t);
}
