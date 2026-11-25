// a function where an element that is a pointer goes (#764)
let twice(x:int64):int64 { x * 2 }
let main():int32 {
    let f:(int64):int64 := twice
    var a:[any^](1) = [f]
    return 0
}
// error: an element of [any^](1) is an any^, and this is (i64):i64
