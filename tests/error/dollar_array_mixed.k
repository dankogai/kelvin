// $[1, "a"] of no type written (#774): kelvinc's sentence at its [,
// where kc said its own
let main():int32 {
    var a = $[1, "a"]
    return 0
}
// error: the elements have no one type kelvinc sees here: write Array<T>([...])
