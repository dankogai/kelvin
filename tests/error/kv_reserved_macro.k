// error: names starting with kv_ or KV_ are kelvinc's runtime's: rename 'KV_CSTR_SCALAR'
let main():int32 {
    let KV_CSTR_SCALAR:int64 = 1
    println(KV_CSTR_SCALAR)
    return 0
}
