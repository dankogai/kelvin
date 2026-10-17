// the text s.find seeks (#177) is a cstr or a String borrowed: a String
// given by value would move, or copy, for nothing
let main():int32 {
    var s = $"abc"
    var t = $"b"
    println(s.find(t))
    return 0
}
// error: '.find' takes text, a cstr, or a String borrowed, '&t', and this is a String: write '&'
