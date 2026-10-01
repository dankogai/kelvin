// error: declarations are written 'name: type', as in 'm: size_t'
#import <stdio.h> as C
#import "include_types.h" as C
f(x: i32, n: size_t, p: i32^, np: size_t^, vp: void^, c: bool)
{
    size_t m = 3;
}
