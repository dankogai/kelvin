// a Set of no type written whose element is no key (#774): kelvinc's
// sentence, where kc said a key of Set<f64> is an integer
let main():int32 {
    var s = ${1.5}
    return 0
}
// error: a key of a Dictionary is an integer or a String, not f64
