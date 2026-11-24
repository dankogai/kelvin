// a T^ const does not step either (#742): p += 1 and p++ would point
// it elsewhere
let main():int32 {
    var a:[int64](3) = [1, 2, 3]
    var p:int64^ const := &a[0]
    p += 1
    return 0
}
// error: 'p' is an i64^ const, a pointer that does not change: declare it without const to point it elsewhere
