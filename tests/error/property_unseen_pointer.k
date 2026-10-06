// error: kv_no_such_property
// a pointer kelvinc cannot see has no .oct: a C type error, not just a
// warning (its .hex is its address, #37)
#import <stdlib.h> as C
let main():i32 {
    println(getenv("HOME").oct);
    return 0;
}
