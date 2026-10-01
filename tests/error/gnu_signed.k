// error: '__signed__' is a C compiler keyword, not available in Kelvin
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, q: size_t^, r: u64)
{
    var s1: __signed__ = -1;
}
