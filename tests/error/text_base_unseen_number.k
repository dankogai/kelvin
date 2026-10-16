// error: kv_base_needs_text
#import <stdlib.h> as C
let main():int32 {
    let mode = int32(atoi("755"), 8)
    println(mode)
    return 0
}
