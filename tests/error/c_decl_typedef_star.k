// error: declarations are written 'var name: type', as in 'var q: size_t^'
#import <stdio.h> as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, p: i32^, d: f64, vp: any^): i32
{
    size_t * q = &n;
    return 0;
}
