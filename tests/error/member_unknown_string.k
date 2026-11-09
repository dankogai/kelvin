// a member a String does not have was C's error, of its struct (#497)
let main():int32 {
    let s = String("ab")
    println(s.first)
    return 0
}
// error: a String has no member 'first': see its properties and methods in documents/strings.md
