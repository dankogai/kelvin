// each path of a function with a result returns (#625): an if and its
// else, a switch whose cases all return, a loop with no way out, a call
// that never returns, C's or one of the program's, which kelvinc finds
// and marks so for C, and a body of one expression
#import <stdlib.h> as C
let fail(why:cstr) {
    println("fail: ", why)
    exit(1)
}
let sign(a:i64):i64 {
    if a > 0 { return 1 } else if a < 0 { return -1 } else { return 0 }
}
let name(a:i64):cstr {
    switch a {
    case 0: return "zero"
    case 1: fallthrough
    case 2: return "small"
    default: return "big"
    }
}
let find(a:i64):i64 {
    var i:i64 = 0
    while true {
        if i * i >= a { return i }
        i += 1
    }
}
let half(a:i64):i64 {
    if a % 2 == 0 { return a / 2 }
    fail("odd")
}
let get(o:i64?):i64 {
    if let v = o { return v } else { abort() }
}
let twice(a:i64):i64 { a * 2 }
let main():int32 {
    println(sign(-3), " ", name(1), " ", find(10), " ", half(8), " ", get(5), " ", twice(4))
    let pos := { (a:i64):i64 in if a > 0 { return 1 } else { return 0 } }
    println(pos(2))
    return 0
}
// out: -1 small 4 4 5 8
// out: 1
