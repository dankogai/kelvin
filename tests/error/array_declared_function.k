// a function's name where an array is declared (#772)
let twice(x:int64):int64 { x * 2 }
let main():int32 {
    var a:[int64](2) = twice
    return 0
}
// error: 'a' is a [i64](2), and this is (i64):i64
