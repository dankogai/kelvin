// error: sizeof_type_product.k:5:
#import <stdio.h> as C
#import "include_types.h" as C
f(x:i32, n:size_t, p:i32^, np:size_t^, vp:any^, c:bool) {
    var z:u64 = sizeof (T * (U8));
}
