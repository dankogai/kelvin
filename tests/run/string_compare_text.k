// a String compares with text and a character (#522), == and != on
// either side, by the bytes: a grapheme of for c in s with " " or ' '
let main():int32 {
    var s = $"a b́ c"
    var spaces = 0
    var marked = 0
    for c in s {
        if c == ' ' { spaces += 1 }
        if c == "b́" { marked += 1 }
    }
    let t:cstr := "abc"
    println(spaces, " ", marked, " ", $"abc" == t, " ", t != $"abd", " ", "x" == $"x")
    println($"é" == "é", " ", "é" == $"é", " ", 'a' == $"a", " ", $"ab" != 'a')
    return 0
}
// out: 2 1 true true true
// out: true false true true
