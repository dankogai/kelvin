// error: _Pragma("...") is only allowed as a statement of its own
#import <stdio.h> as C
#import "include_types.h" as C
struct pt { x: i32; y: i32; };
f(x: i32, n: size_t, q: size_t^, r: u64)
{
    var v: size_t = _Pragma("") * q;
}
