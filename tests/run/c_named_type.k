// a Kelvin struct, enum or variable named C keeps C.x (#416), a header's
// names bare beside it
#import <ctype.h> as C
struct C { n: int64 }
extend C {
    static let make(n:int64):C { (C){n} }
}
let main():int32 {
    let c = C.make(3)
    println(c.n, " ", toupper(97))
    return 0
}
// out: 3 65
