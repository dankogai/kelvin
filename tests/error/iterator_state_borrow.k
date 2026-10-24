// a named function takes the state by a borrow that may change it (#325)
let inc(s:int64):int64? { none }
let main():int32 {
    var it = Iterator(0, inc)
    return 0
}
// error: an Iterator's function takes its state, i64, by a borrow that may change it, i64^, and this takes i64
