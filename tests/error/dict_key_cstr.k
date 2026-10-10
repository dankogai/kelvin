// a key type is String, which keeps a copy of the text, not cstr (#65)
let main():i32 {
    var d:${cstr: i64}
    return 0
}
// error: a key of a Dictionary is a String, not a cstr: the Dictionary keeps a copy of the text, and is read with a cstr or a String
