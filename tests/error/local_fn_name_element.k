// a function of two types defined inside a function is named as it is
// written in an error (#764), where kc named its hidden one, _kv_main_t1
let main():int32 {
    let t(x:int64):int64 { x }
    let t(x:float64):float64 { x }
    var a:[(String):int64](1) = [t]
    return 0
}
// error: no function 't' is (String):i64
