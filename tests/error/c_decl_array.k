// error: declarations start with 'var', as in 'var b: size_t^[3]'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, q: size_t^, r: u64)
{
    size_t * b[3];
}
