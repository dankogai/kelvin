// error: kv_no_such_method
// a pointer kelvinc cannot see is a C type error, not just a warning
#import <stdlib.h> as C
let i32.neg():i32 { return -self; }
let main():i32 {
    return getenv("HOME").neg();
}
