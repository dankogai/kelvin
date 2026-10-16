// error: a base is for reading text, as in i32("755", 8); i32 converts a number
#import <ctype.h> as C
let main():int32 {
    let c:int32 = '7'
    println(int32(isdigit(c) != 0, 8))
    return 0
}
