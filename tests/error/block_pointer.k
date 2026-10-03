// error: 'F ~ cb' as a statement would be read by C as a block-pointer declaration
#import <stdio.h> as C
#import "include_types.h" as C
f(x:i32, n:size_t, p:i32^, np:size_t^, vp:any^, c:bool) {
    F ~ cb = 0;
}
