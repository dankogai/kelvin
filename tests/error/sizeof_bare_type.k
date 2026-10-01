// error: sizeof a type needs parentheses: sizeof(i32)
#import <stdio.h> as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, p: i32^, d: f64, vp: void^): i32
{
    var z: u64 = sizeof i32;
    return 0;
}
