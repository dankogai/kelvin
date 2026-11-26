// a String has += alone (#766): -= was C's error, invalid operands to
// binary expression, and kc's an owner is assigned only as a String
let main():int32 {
    var t:String = $"ab"
    t -= "b"
    return 0
}
// error: a String has no '-='
