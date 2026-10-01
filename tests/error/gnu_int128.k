// error: '__int128' is a C compiler keyword; use i128 or u128
#import <stdio.h> as C
#import "include_types.h" as C
f(x: i32, n: size_t, p: i32^, np: size_t^, vp: void^, c: bool)
{
    var y: __int128 = 0;
}
