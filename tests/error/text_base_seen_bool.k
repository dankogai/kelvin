// error: a base is for reading text, as in i32("755", 8); i32 converts a number
#import <ctype.h> as C
main():i32 {
    let c:i32 = '7'
    println(i32(isdigit(c) != 0, 8))
    return 0
}
