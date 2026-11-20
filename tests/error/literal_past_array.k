// an array literal past its count (#647), where C only warned
let main():int32 {
    var a:[i64](3) = [1, 2, 3, 4]
    println(a[0])
    return 0
}
// error: [i64](3) holds 3 elements, and this gives 4
