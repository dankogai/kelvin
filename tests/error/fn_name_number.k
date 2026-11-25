// a function's own name where a number goes (#764), which kc left to C
let num(f:(int64):int64):int64 { f(1) }
let main():int32 {
    var n:int64 = num
    return 0
}
// error: 'n' is an i64, and this is ((i64):i64):i64
