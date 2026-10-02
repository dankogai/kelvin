// error: declarations are written 'var name: type', as in 'var p: size_t^'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, q: size_t^, r: u64)
{
    size_t * (p) = &n;
}
