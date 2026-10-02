// error: kv_no_such_property
// a pointer kelvinc cannot see is a C type error, not just a warning
#import <stdlib.h> as C
main(): i32
{
    println(getenv("HOME").hex);
    return 0;
}
