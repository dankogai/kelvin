// rows of owners of a count C computes are an array of owners (#787),
// as kelvinc says it: kc said its own sentence of a fixed array in
// another type
let N:int64 = 3

let main():int32 {
    var g:[[String](N)](2)
    return 0
}
// error: an array of owners is not here yet: a struct may hold them
