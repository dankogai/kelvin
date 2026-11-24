// a struct's member takes a value of its kind, as a parameter does (#741)
struct point { x: int64; y: int64 }
let main():int32 {
    var p:point = {1, "two"}
    return 0
}
// error: 'y' of point is an i64, and this is text
