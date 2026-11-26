// Array<T>(&x) copies an Array<T> (#771): &x of a number is none,
// which kelvinc built
let main():int32 {
    var x:int64 = 1
    var a = Array<int64>(&x)
    return 0
}
// error: Array<i64>(&a) copies an Array<i64>, and this lends i64
