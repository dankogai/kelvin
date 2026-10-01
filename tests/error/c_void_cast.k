// error: C casts are not Kelvin: discard a value with 'v as void'
#import <stdio.h> as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, p: i32^, d: f64, vp: void^): i32
{
    (void)x;
    return 0;
}
