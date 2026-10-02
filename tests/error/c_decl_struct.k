// error: declarations are written 'name: type', as in 's: struct pt'
#import <stdio.h> as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, p: i32^, d: f64, vp: any^): i32
{
    struct pt s;
    return 0;
}
