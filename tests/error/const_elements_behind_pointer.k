// an element of a [const T](N) is const behind a pointer too (#425, #733)
let main():int32 {
    var two:[[int64](3)](2) = [[1, 2, 3], [4, 5, 6]]
    let r:[const int64](3)^ := &two[0]
    r[1][2] = 5
    return 0
}
// error: this changes an element of a [const i64](3), whose elements are const: declare it without const to change them
