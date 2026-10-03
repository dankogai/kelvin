// error: a converter takes exactly one value: i32(v)
#import <stdio.h> as C
f(x:i32, n:size_t, p:i32^) {
    var y:i32 = i32(x, 2);
}
