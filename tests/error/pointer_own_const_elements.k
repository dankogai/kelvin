// an array of T^ const has const elements (#742), as [const T] has
// (#733)
let main():int32 {
    var x:int64 = 1
    var a:[int64^ const](2) = [nowhere, nowhere]
    a[0] := &x
    return 0
}
// error: this changes an element of a [i64^ const](2), whose elements are const: declare it without const to change them
