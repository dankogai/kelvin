// s.escape(&re) and s.escape($/.../) of RegExp (#164): each codepoint of
// what the pattern matches as \u{...}, a backslash as \\ anywhere, the
// literal moved into the call; s.unescape() reads it back, and
// s.unescape(&re) (#165) reads back what the pattern matches alone
#import <RegExp>
let main():int32 {
    var s = $"café 😀 a\\b 🇯🇵 x"
    let emoji = $/\p{Emoji_Presentation}/
    var e1 = s.escape(&emoji)
    var e2 = s.escape($/[é]|x/g)
    var e3 = s.escape($/\X/g)
    var e4 = s.escape($/nothing/)
    var all = s.escape()
    println(e1)
    println(e2)
    println(e3)
    println(e4)
    var u1 = e1.unescape()
    var u3 = e3.unescape()
    println(u1 == s, " ", u3 == s, " ", all.count, " ", e3.count)
    let emojiEsc = $/\\u\{1F[0-9A-F]+\}/g
    var p1 = all.unescape(&emojiEsc)
    var p2 = all.unescape($/\\u\{E9\}|\\\\/)
    var p3 = all.unescape($/x/)
    println(p1)
    println(p2)
    println(p3 == all)
    return 0
}
// out: café \u{1F600} a\\b \u{1F1EF}\u{1F1F5} x
// out: caf\u{E9} 😀 a\\b 🇯🇵 \u{78}
// out: \u{63}\u{61}\u{66}\u{E9}\u{20}\u{1F600}\u{20}\u{61}\u{5C}\u{62}\u{20}\u{1F1EF}\u{1F1F5}\u{20}\u{78}
// out: café 😀 a\\b 🇯🇵 x
// out: true true 45 99
// out: caf\u{E9} 😀 a\\b 🇯🇵 x
// out: café \u{1F600} a\b \u{1F1EF}\u{1F1F5} x
// out: true
