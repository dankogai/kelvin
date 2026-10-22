// only a String has '+' (#282): two literals, or two cstrs, do not join,
// where C refused "a" + "b"; $"a" + "b" is a String
let main():int32 {
    println("a" + "b")
    return 0
}
// error: '+' joins Strings, and a cstr is not one (#282): make one a String, as in '$"a" + "b"'
