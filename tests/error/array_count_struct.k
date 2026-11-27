// a struct's value is no count (#783): named bare, as kc names it
struct pt { x:int64, y:int64 }
let main():int32 {
    var o:pt = {1, 2}
    var w:[int64](o.x)
    var v:[int64](o)
    return 0
}
// error: an array's count is an integer, and this is pt
