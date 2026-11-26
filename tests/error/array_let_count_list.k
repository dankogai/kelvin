// a let's name is no constant of C's (#779): a list given to an array
// it counts was built only where the C compiler folded the const, an
// extension; an enumerator and a constant expression are C's constants
enum { K = 3 }
let N:int64 = 3
let main():int32 {
    var e:[int64](K) = [1, 2, 3]
    var f:[int64](K - 1) = [1, 2]
    var z:[int64](N)
    var v:[int64](N) = [1, 2, 3]
    return 0
}
// error: an array of a count computed at run time takes no elements in C: give them one by one, a[i] = ...
