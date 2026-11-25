// xs += v, append and insert take an element of the Array's kind
// (#757): kc says kelvinc's sentence, where it was C's error
let main():int32 {
    var xs:$[int64] = $[1]
    xs += "x"
    return 0
}
// error: an element of Array<i64> is an i64, and this is text
