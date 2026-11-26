// an overloaded function's name as a Dictionary's value, no type
// written (#769)
let twice(x:int64):int64 { x * 2 }
let twice(x:float64):float64 { x * 2.0 }
let main():int32 {
    var d = ${"double": twice}
    return 0
}
// error: the value of this entry has no type kelvinc sees: write Dictionary<K, V>({...})
