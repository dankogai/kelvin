// for c:uchr in s converts as uchr(x) does, which takes no float (#480)
let main():int32 {
    var f = [f64](2)
    for c:uchr in f {
        println(c)
    }
    return 0
}
// error: for c:uchr in s converts each element as uchr(x) does, which takes an integer, a uchr or text, and these are f64
