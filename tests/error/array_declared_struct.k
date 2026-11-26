// a struct where an array is declared (#772): the array is named as it
// is written, where kelvinc named the pointer it is in C, an i64^
struct pt { x:int64, y:int64 }
let main():int32 {
    var o:pt = {1, 2}
    var a:[int64](2) = o
    return 0
}
// error: 'a' is a [i64](2), and this is pt
