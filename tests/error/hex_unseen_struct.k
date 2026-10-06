// error: kv_no_such_property
// .hex of a C struct kelvinc cannot see is still a C error that names
// kv_no_such_property, while a pointer's is its address (#37)
#import <stdlib.h> as C
let main():i32 {
    println(div(7, 2).hex)
    return 0
}
