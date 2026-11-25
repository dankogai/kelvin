// a function where a pointer goes (#764), an any^ too, which kc built
let twice(x:int64):int64 { x * 2 }
let main():int32 {
    let f:(int64):int64 := twice
    var p:any^ := f
    return 0
}
// error: 'p' is an any^, and this is (i64):i64
