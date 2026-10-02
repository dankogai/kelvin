// error: kv_no_such_method
// a pointer kelvinc cannot see is a C type error, not just a warning
#import <stdlib.h> as C
i32.neg(): i32 { return -self; }
main(): i32
{
    return getenv("HOME").neg();
}
