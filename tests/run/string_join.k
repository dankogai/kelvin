// only a String has '+' (#282): $"a" + $"b" is String("ab"), as is a
// String and a cstr either way; adjacent literals are one, as in C
let main():int32 {
    let ab = $"a" + $"b"
    println(ab == String("ab"), " ", $"a" + "b", " ", "a" + $"b", " ", "a" "b")
    return 0
}
// out: true ab ab ab
