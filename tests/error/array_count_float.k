// an array's count is an integer (#783): a float written is none, said
// where the type is read, before its elements are, where it was C's
// error, size of array has non-integer type
let main():int32 {
    var v:[int64](3.0) = [1, 2, 3]
    return 0
}
// error: an array's count is an integer, and this is f64
