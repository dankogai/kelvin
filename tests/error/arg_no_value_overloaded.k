// error: this has no value, so it cannot be argument 1 of 'twice': make the call alone, as a line of its own
// a call of an overload with no result is no argument (#593), as a call
// of a function of a name of its own is none (#316)
let note(x:int64) { println("note ", x) }
let note(x:float64):float64 { return x * 2.0 }
let twice(x:int64):int64 { return x * 2 }
let main():int32 {
    println(twice(note(1)))
    return 0
}
