// error: pointer types are written with a postfix '^', as in 'i32^'
#import <stdio.h> as C
#import "include_types.h" as C
f(x: i32, n: size_t, p: i32^, np: size_t^, vp: void^, c: bool)
{
    r: u8^ = c ? p as u8* : vp;
}
