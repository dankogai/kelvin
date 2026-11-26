// an overloaded function's name as a Set's element, no type written
// (#769)
let twice(x:int64):int64 { x * 2 }
let twice(x:float64):float64 { x * 2.0 }
let main():int32 {
    var s = ${twice}
    return 0
}
// error: this element has no type kelvinc sees: write Set<T>({...})
