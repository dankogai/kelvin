// error: this value would be dropped: a body returns its value without 'return' only when it is one expression
#import <stdio.h> as C
buffer_bytes(n:i64):i64 {
    let count:i64 = n + 1
    BUFSIZ * count
}
main():i32 {
    println(buffer_bytes(1))
    return 0
}
