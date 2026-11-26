// a member that is an array is not given another (#767)
struct grid { cells:[int64](2) }
let main():int32 {
    var b:[int64](2) = [3, 4]
    var g:grid = {b}
    return 0
}
// error: an array is not assigned: assign its elements, a[i]
