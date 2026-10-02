// error: 'int' is not a Kelvin type; use i32 or u32
#import <stdio.h> as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, p: i32^, d: f64, vp: any^): i32
{
    var z: i32 = (int){1};
    return 0;
}
