// a case's value of an owner that an expression gives is bound first, as
// .is is (#99, #154): the copy would be lost with what it holds
#import <SION>
let main():int32 {
    var s = SION.parse("[\"a\": \"text\"]")
    println(s["a"].string)
    return 0
}
// error: '.string' of a struct SION that an expression gives, which nothing would free: bind it to a variable first
