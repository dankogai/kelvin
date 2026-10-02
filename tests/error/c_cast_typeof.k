// error: c_cast_typeof.k:6:
#import <stdio.h> as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, p: i32^, d: f64, vp: any^): i32
{
    a: u64 = (__typeof__(x))-1;
    return 0;
}
