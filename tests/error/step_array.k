// an array is not a pointer: it does not move (#51)
let main():int32 {
    var a:[int32](2) = [1, 2]
    a++
    return 0
}
// error: '++' is for pointers, and an array does not move: index it, or take a pointer, 'var p := a'
