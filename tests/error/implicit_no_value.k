// error: this has no value, but this function has a result, of type i64
let note(x:int64) { println("note ", x) }
let f(x:int64):int64 { note(x) }
let main():int32 {
    println(f(1))
    return 0
}
