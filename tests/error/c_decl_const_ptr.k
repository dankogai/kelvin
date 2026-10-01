// error: declarations start with 'var', as in 'var s: u8^ const'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, q: size_t^, r: u64)
{
    u8 * const s = "hi";
}
