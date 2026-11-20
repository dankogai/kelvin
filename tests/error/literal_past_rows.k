// an array of arrays given a row past its count (#647)
let main():int32 {
    let a:[[i64](2)](2) = [[1, 2], [3, 4], [5, 6]]
    println(a[0][0])
    return 0
}
// error: [[i64](2)](2) holds 2 elements, and this gives 3
