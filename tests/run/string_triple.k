// """ (#115, #118): a string literal over any number of lines, with the
// text as it is: no escapes, no ${...}; a cstr, as any literal; adjacent
// ones join. Written on its own lines, the line break after the opening
// """ and the one before the closing """ are not text, and the closing
// delimiter's indentation comes off each line; a longer delimiter, """",
// holds a """ inside; the inline form """as it is""" keeps everything
#import <JSON>
let main():i32 {
    let text := """
        {"name": "kelvin",
          "tags": ["c", 11], "esc": "a\"b\\c\n", "q": "what?"}
        """
    println(text)
    var j = JSON.parse(text)
    println(j["esc"].string, " ", j["esc"].string.count, " ", j["q"].string)
    let two := """one""" """two"""
    let lines := """
x
"""
    println(two, " ", lines.count, " ", text.typename)
    let longer := """"
        a """ inside, and "quotes" too
        """"
    let trailing := """"text ending in a quote"""""
    println("[", longer, "] [", trailing, "]")
    let mixed := """
    first, at the delimiter's depth
      second, deeper
    """
    println(mixed)
    let blank := """
        """
    println(blank.count)
    var s = $"""
        raw ${not} `interpolated` and \n stays
        """
    println(s, " ", s.count)
    var b = Bytes("""a "quoted" word""")
    println(b, " ", b.count)
    return 0
}
// out: {"name": "kelvin",
// out:   "tags": ["c", 11], "esc": "a\"b\\c\n", "q": "what?"}
// out: a"b\c
// out:  6 what?
// out: onetwo 1 cstr
// out: [a """ inside, and "quotes" too] [text ending in a quote"]
// out: first, at the delimiter's depth
// out:   second, deeper
// out: 0
// out: raw ${not} `interpolated` and \n stays 38
// out: a "quoted" word 15
// c: "{\"name\": \"kelvin\",\n  \"tags\": [\"c\", 11], \"esc\": \"a\\\"b\\\\c\\n\", \"q\": \"what\?\"}"
