// a thread_local holds no owner, which no thread's end would free (#641)
thread_local var name:String = $""
let main():int32 {
    println(name)
    return 0
}
// error: a thread_local holds no owner (#641): 'name' is String, which no thread's end frees; keep a pointer to one, or give each Task its own
