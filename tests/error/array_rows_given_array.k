// a row of an array of arrays is not given another array (#767)
let main():int32 {
    var b:[int64](2) = [3, 4]
    var m:[[int64](2)](2) = [[1, 2], b]
    return 0
}
// error: an array is not assigned: assign its elements, a[i]
