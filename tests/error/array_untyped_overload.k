// an overloaded function's name in an Array's literal of no type
// written (#769): no type says which it is
let twice(x:int64):int64 { x * 2 }
let twice(x:float64):float64 { x * 2.0 }
let main():int32 {
    var a = $[twice, twice]
    return 0
}
// error: the elements have no one type kelvinc sees here: write Array<T>([...])
