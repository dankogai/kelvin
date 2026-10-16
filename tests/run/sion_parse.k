// modules/SION.k (#152): every value SION has, read from text: nil, bool,
// an integer in decimal, hex, octal and binary, a double in decimal and
// as a hex float, nan and the infinities, a string with JSON's escapes
// and Swift's \0 and \u{...}, .Data and .Ext in base64, .Date, arrays,
// dictionaries keyed by any value, [:], a trailing comma, and comments
#import <SION>
#import <stdio.h> as C
let main():int32 {
    var s = SION.parse("""
        [ "nil": nil, "t": true, "f": false,            // a comment
          "ints": [42, -42, 0x2a, 0o52, 0b101010, +7],
          "doubles": [42.0, 4.2e1, 0x1.5p5, -1.5, nan, inf, -Infinity, 1e3],
          "str": "a\"b\\c\/d\n\t\0\u00e9\u{1F600}\uD83D\uDE00",
          "data": .Data("a2VsdmluCg=="), "ext": .Ext("1NTU"), "when": .Date(0x1p+30),
          0: "zero", 1.5: "one and a half", true: "yes", nil: "nothing", [1, 2]: "a list",
          "empty": [], "none": [:], "trailing": [1, 2,], ]
        """)
    if s.is(error) { println(s.error); return 1 }
    var ints = s["ints"]
    var doubles = s["doubles"]
    var none = s["nil"]
    var t = s["t"]
    var f = s["f"]
    println(none.is(nil), " ", t.boolean, " ", f.boolean, " ", s.count, " ", ints.count)
    for i in 0..<6 { var v = ints[i]; print(v.integer, i < 5 ? " " : "\n") }
    for i in 0..<8 { var v = doubles[i]; print(v.number, i < 7 ? " " : "\n") }
    var str = s["str"]
    print(str.string.count, " ")
    for c in str.string.bytes^ { printf("%02x", c) }   // with the NUL, which no line of text shows
    println()
    var data = s["data"]
    var ext = s["ext"]
    var when = s["when"]
    println(data.data.count, " ", ext.ext.count, " ", when.date, " ", ext.ext[0], " ", ext.ext[2], " ", data.data)
    var empty = s["none"]
    var missing = s["missing"]
    var zero = s[0]
    var emptyArray = s["empty"]
    var trailing = s["trailing"]
    println(zero.string, " ", emptyArray.count, " ", empty.is(dictionary), " ", empty.count, " ", trailing.count)
    var key = SION.parse("[1, 2]")
    let at = SION.find(&s, &key)
    println(at, " ", s.dictionary[at].string, " ", SION.find(&s, &ints), " ", missing.is(nil))
    var e1 = SION.parse("[1 2]")
    var e2 = SION.parse("[\"a\": 1, 2]")
    var e3 = SION.parse(".Data(x)")
    var e4 = SION.parse("\"\\q\"")
    var e5 = SION.parse("[1, 2] 3")
    var e6 = SION.parse("")
    println(e1.error)
    println(e2.error)
    println(e3.error)
    println(e4.error)
    println(e5.error)
    println(e6.error)
    return 0
}
// out: true true false 17 6
// out: 42 -42 42 42 42 7
// out: 42.0 42.0 42.0 -1.5 nan inf -inf 1000.0
// out: 13 6122625c632f640a0900c3a9f09f9880f09f9880
// out: 7 3 1073741824.0 212 212 kelvin
// out: 
// out: zero 0 true 0 2
// out: 27 a list -1 true
// out: ',' or ']' in an array: unexpected '2' at 3
// out: ':' after a key: unexpected ']' at 10
// out: a base64 string after .Data( or .Ext(: unexpected 'x' at 6
// out: an escape in a string: unexpected 'q' at 2
// out: the end of the text: unexpected '3' at 7
// out: a value: unexpected end of text at 0
