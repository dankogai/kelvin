// an array is not declared with another (#767), as it is not assigned
// one (#648): C's error before, array initializer must be an
// initializer list, and kc's an array is not copied by '='
let main():int32 {
    var b:[int64](2) = [3, 4]
    var a:[int64](2) = b
    return 0
}
// error: an array is not assigned: assign its elements, a[i]
