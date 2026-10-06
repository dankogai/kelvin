// error: kv_base_needs_text
#import <stdlib.h> as C
let main():i32 {
    let mode = i32(atoi("755"), 8)
    println(mode)
    return 0
}
