// error: cstr is u8^: convert with 'v as cstr'
#import <stdlib.h> as C
let main():i32 {
    p := cstr(malloc(8));
    return 0;
}
