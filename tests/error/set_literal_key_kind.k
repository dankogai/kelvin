// a Set's literal of a written type holds keys of it (#757): kc says
// kelvinc's sentence, where it asked the elements' one type first
let main():int32 {
    var s:${String} = ${"a", 5}
    return 0
}
// error: a key of Set<String> is text: a cstr, a template, or a String
