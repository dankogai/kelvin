// error: this has no value, but this function has a result, of type i64: write 'return' with a value after it
// where C chooses the overload, of an argument only C sees the type of,
// the call is no value if none of them has a result (#593)
#import <stdlib.h> as C
let note(x:int64) { println("note ", x) }
let note(x:float64) { println("note ", x) }
let f():int64 { note(atof("1.5")) }
let main():int32 {
    println(f())
    return 0
}
