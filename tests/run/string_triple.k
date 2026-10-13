// """text""" (#115): a string literal over any number of lines, with the
// text as it is: no escapes, no ${...}; a cstr, as any literal; adjacent
// ones join; the lines' indentation is kept
#import <JSON>
let main():i32 {
    let text := """{"name": "kelvin",
  "tags": ["c", 11], "esc": "a\"b\\c\n", "q": "what?"}"""
    println(text)
    var j = JSON.parse(text)
    println(j.object["esc"].string, " ", j.object["esc"].string.count, " ", j.object["q"].string)
    let two := """one""" """two"""
    let empty := """"""
    let lines := """
x
"""
    println(two, " ", empty.count, " ", lines.count, " ", text.typename)
    var s = $"""raw ${not} `interpolated` and \n stays"""
    println(s, " ", s.count)
    var b = Bytes("""a "quoted" word""")
    println(b, " ", b.count)
    return 0
}
// out: {"name": "kelvin",
// out:   "tags": ["c", 11], "esc": "a\"b\\c\n", "q": "what?"}
// out: a"b\c
// out:  6 what?
// out: onetwo 0 3 cstr
// out: raw ${not} `interpolated` and \n stays 38
// out: a "quoted" word 15
// c: "{\"name\": \"kelvin\",\n  \"tags\": [\"c\", 11], \"esc\": \"a\\\"b\\\\c\\n\", \"q\": \"what\?\"}"
