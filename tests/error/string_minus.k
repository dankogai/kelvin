// a String has no - (#769): said before the variable's type is asked,
// where kc said 'u' needs a type
let main():int32 {
    var t:String = $"ab"
    var u = t - "b"
    return 0
}
// error: a String has no operator '-': compare with == and !=, append with .append or +=, join with +
