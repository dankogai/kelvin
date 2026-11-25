// nowhere where a number goes is an any^ (#764), where it was C's error
let main():int32 {
    var n:int64 = nowhere
    return 0
}
// error: 'n' is an i64, and this is any^
