// error: 'long' is not a Kelvin type, use f64 (long double has no Kelvin type yet)
#import <stdio.h> as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, p: i32^, d: f64, vp: void^): i32
{
    var e: f64 = (long double)d;
    return 0;
}
