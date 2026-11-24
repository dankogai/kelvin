// a member that is a T^ const points where its struct was made to
// (#742), a var's too
struct holder { p:int64^ const, n:int64 }
let main():int32 {
    var x:int64 = 1
    var y:int64 = 2
    var h:holder = {&x, 3}
    h.n = 4
    h.p := &y
    return 0
}
// error: '.p' is an i64^ const, a pointer that does not change: declare it without const to point it elsewhere
