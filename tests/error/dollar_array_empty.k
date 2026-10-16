// $[] has no element type to infer, as Array([]) has none (#62)
let main():int32 {
    var xs = $[]
    return 0
}
// error: Array([]) has no element type: write Array<T>()
