// nowhere, and a pointer, where an array is declared (#767)
let main():int32 {
    var a:[int64](2) = nowhere
    return 0
}
// error: an array is not assigned: assign its elements, a[i]
