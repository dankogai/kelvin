// Array(x) of what is no fixed array and no borrow of an Array, no
// type written (#777): kelvinc's sentence, where kc said 'a' needs a
// type
let main():int32 {
    var a = Array("a")
    return 0
}
// error: Array(x) has no element type: write Array<T>(x), or the elements, Array([...])
