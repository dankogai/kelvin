// T^ const is a pointer that is itself const, C's T *const (#742): what
// it points to changes through it, and it points nowhere else
let main():int32 {
    var x:int64 = 1
    var y:int64 = 2
    var p:int64^ const := &x
    p^ += 1
    p := &y
    return 0
}
// error: 'p' is an i64^ const, a pointer that does not change: declare it without const to point it elsewhere
