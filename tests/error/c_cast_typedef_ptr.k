// error: C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type; pointer types are written with a postfix '^', as in 'i32^'
#import <stdio.h> as C
#import "include_types.h" as C
f(x: i32, n: size_t, p: i32^, np: size_t^, vp: any^, c: bool)
{
    q: U8^ := (U8*)p;
}
