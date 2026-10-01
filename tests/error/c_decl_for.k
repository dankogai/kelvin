// error: declarations are written 'name: type', as in 'r: size_t^'
#import <stdio.h> as C
#import "include_types.h" as C
f(x: i32, n: size_t, p: i32^, np: size_t^, vp: void^, c: bool)
{
    for (size_t * r = &n; ; ) { break; }
}
