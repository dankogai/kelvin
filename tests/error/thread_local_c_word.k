// C11's _Thread_local is written thread_local in Kelvin (#641)
_Thread_local var n:i64 = 0
let main():int32 {
    println(n)
    return 0
}
// error: '_Thread_local' is C's spelling: Kelvin writes 'thread_local var x' (#641)
