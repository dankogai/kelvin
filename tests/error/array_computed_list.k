// an array of a count C computes takes no elements where it is declared
// (#779): C's error before, variable-sized object may not be
// initialized; zeros, [T](n), are taken
let main():int32 {
    var n:int64 = 3
    var z:[int64](n) = [int64](n)
    var v:[int64](n) = [1, 2, 3]
    return 0
}
// error: an array of a count computed at run time takes no elements in C: give them one by one, a[i] = ...
