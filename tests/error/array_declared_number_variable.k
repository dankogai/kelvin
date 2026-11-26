// a number's variable where an array is declared is a number (#741,
// #769), as its literal is, where kc named its type
let main():int32 {
    var x:int64 = 1
    var a:[int64](2) = x
    return 0
}
// error: 'a' is a [i64](2), and this is a number
