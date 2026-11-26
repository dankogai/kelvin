// a Set's element that is a struct is named with its word (#769)
struct pt { x:int64, y:int64 }
let main():int32 {
    var s = Set<pt>()
    return 0
}
// error: a key of a Dictionary is an integer or a String, not struct pt
