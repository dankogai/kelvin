// a var's [const T](N) keeps its elements (#425, #733)
let main():int32 {
    var a:[const int64](3) = [1, 2, 3]
    a[2] = 5
    return 0
}
// error: this changes an element of a [const i64](3), whose elements are const: declare it without const to change them
