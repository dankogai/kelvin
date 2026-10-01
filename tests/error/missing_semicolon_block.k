// error: expected ';', found '{'
#import <stdio.h> as C
#import "include_types.h" as C
f(x: i32, n: size_t, p: i32^, np: size_t^, vp: void^, c: bool)
{
    var t: i32 = (x + 1)
    {
        x = 3;
    }
}
