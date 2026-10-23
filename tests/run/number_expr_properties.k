// a property of an expression kelvinc sees is a number is the number's
// (#297): (n + 1).uchr converts it, and (n + 1).size is its sizeof, where
// both went to C as a struct's member; .hex and .cstr were so already
let main():int32 {
    let n:int64 = 64
    let flag = true
    let x:float64 = 1.5
    println((n + 1).uchr, (n * 2 - 63).uchr, (-n + 131).uchr, (flag ? n + 3 : n).uchr, (n ~ 7).uchr)
    println((n + 1).size, " ", (x + 1.0).size, " ", (n + 1).hex, " ", (n + 1).cstr)
    var s = $""
    for i in 0..<3 {
        s += (n + 1 + i).uchr
    }
    println(s)
    return 0
}
// out: AACCG
// out: 8 8 +0x41 65
// out: ABC
