// each element in turn is the Array's, borrowed by the loop (#57)
let take(s:String) {}
let main():i32 {
    var xs = Array<String>()
    for s in xs { take(s) }
    return 0
}
// error: 's' is a value its Array, Dictionary, Optional or Result still owns: pass a borrow, '&s', or a copy
