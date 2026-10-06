// error: C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type; pointer types are written with a postfix '^', as in 'i32^'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x:i32; y:i32; };
let f(x:i32, n:size_t, q:size_t^, var r:u64) {
    r = (size_t const *)q as u64;
}
