// a list where a v.type of an array of a count C computes is declared
// (#779), where kelvinc said the type is v.type: write a value
let main():int32 {
    var n:int64 = 3
    var v:[int64](n)
    var w:v.type = [1, 2, 3]
    return 0
}
// error: an array of a count computed at run time takes no elements in C: give them one by one, a[i] = ...
