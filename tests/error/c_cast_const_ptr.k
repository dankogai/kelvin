// error: C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type; pointer types are written with a postfix '^', as in 'i32^'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:int32; y:int32; };
let f(x:int32, n:size_t, q:size_t^, var r:uint64) {
    r = (size_t const *)q as uint64;
}
