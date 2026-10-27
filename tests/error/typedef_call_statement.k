// a statement name(x) of a name kelvinc does not see (#402) is if (1)
// name(x) in C, where a declaration is no statement: were name a C
// typedef, C would otherwise declare an x that shadows this one, silently
#import <stdio.h> as C
let main():i32 {
    var n:i64 = 3
    if true {
        size_t(n)
        n += 1
    }
    println(n)
    return 0
}
// error: expected expression
