// s += v, and insert, has and remove, take a key of the Set (#757): kc
// says kelvinc's sentence, where it was C's error
let main():int32 {
    var s:${int64} = ${1}
    s += "a"
    return 0
}
// error: a key of Set<i64> is an integer
