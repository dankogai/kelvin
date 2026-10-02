// error: declarations are written 'name: type', as in 'r: i32^'
#import <stdio.h> as C
#import "include_types.h" as C
f(x: i32, n: size_t, p: i32^, np: size_t^, vp: any^, c: bool)
{
    i32 * r = &x;
}
