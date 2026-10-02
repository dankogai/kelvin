// error: C casts are not Kelvin: to discard a value, write it as a statement of its own
#import <stdio.h> as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, p: i32^, d: f64, vp: any^): i32
{
    (void)x;
    return 0;
}
