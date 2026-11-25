// a Set has += alone (#763): -= was C's error, invalid operands to
// binary expression, and kc's an owner is assigned only as a String
let main():int32 {
    var s:${String} = ${"a", "b"}
    s -= "a"
    return 0
}
// error: a Set has no '-=': remove an element with s.remove(x)
