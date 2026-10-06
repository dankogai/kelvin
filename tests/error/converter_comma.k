// error: a base is for reading text, as in i32("755", 8); i32 converts a number
#import <stdio.h> as C
let f(x:i32, n:size_t, p:i32^) {
    var y:i32 = i32(x, 2);
}
