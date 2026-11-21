// a literal kelvinc reckons an i64, as a method's receiver (#548), is shifted
// as an i64: by 64 or more, the error (#665)
let i64.plus(k:i64):i64 { self + k }
let main():int32 {
    println((1 << 70).plus(1))
    return 0
}
// error: '<< 70' shifts an i64 by 70, its width or more, which C leaves undefined
