// error: 'fp' looks like a C function-pointer declaration: write 'var fp:(...):size_t' (#31)
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, q:size_t^, r:uint64) {
    size_t * fp^(size_t);
}
