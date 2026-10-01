// error: declarations start with 'var', as in 'static var m: size_t'
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, q: size_t^, r: u64)
{
    static size_t m = 0;
}
