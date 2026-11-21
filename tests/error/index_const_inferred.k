// of an array whose type is inferred from its literal (#661)
let main():int32 {
    let a = [1, 2, 3]
    println(a[3])
    return 0
}
// error: index 3 is past the end of [i64](3): its indices are 0 to 2
