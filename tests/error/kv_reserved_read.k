// an unnamed parameter is _kv_arg0 in the C (#388), a name of kelvinc's
// own that the program cannot read, as it cannot declare one
let second(_:int64, y:int64):int64 {
    return _kv_arg0 + y
}
let main():int32 {
    println(second(1, 2))
    return 0
}
// error: names starting with _kv_ are kelvinc's own, in the C it writes: '_kv_arg0' is none of the program's
