// a fixed array has no methods: an Array's sum is Array's (#736)
let main():int32 {
    var a:[int64](3) = [1, 2, 3]
    println(a.sum())
    return 0
}
// error: [i64](3) has no member 'sum'
