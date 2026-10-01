// error: c_cast_typedef_call.k:5:
#import <stdio.h> as C
f(x: i32, n: size_t, p: i32^)
{
    var y: size_t = (size_t)(n + 1);
}
