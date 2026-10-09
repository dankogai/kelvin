// the C tag of a struct with no tag is kelvinc's, not a Kelvin type (#59)
let main():i32 {
    var f:{x:f64} = {1.0}
    var u:{x:_kv_anon1} = {f}
    return 0
}
// error: names starting with _kv_ are kelvinc's own, in the C it writes: rename '_kv_anon1'
