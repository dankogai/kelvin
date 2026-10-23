// an array parameter is the pointer C makes of it, which async f(x)
// would share with its thread (#312)
let first(a:[int64](3)):int64 { a[0] }
let main():int32 {
    var a:[int64](3)
    let t = async first(a)
    return 0
}
// error: 'async' would share what this points to with the call's thread: the parameter is [i64](3), and the function takes values, copied, and owners, moved
