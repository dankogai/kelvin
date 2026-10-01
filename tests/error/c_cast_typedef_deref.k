// error: c_cast_typedef_deref.k:5:
#import <stdio.h> as C
f(x: i32, n: size_t, p: i32^)
{
    y: i32 = (int32_t)*p;
}
