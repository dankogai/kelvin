// error: this value would be dropped: a body returns its value without 'return' only when it is one expression
#import <stdio.h> as C
let buffer_bytes(n:i64):i64 {
    let count:int64 = n + 1
    BUFSIZ * count
}
let main():i32 {
    println(buffer_bytes(1))
    return 0
}
