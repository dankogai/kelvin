// JSON.parse (#113): text, a cstr or a borrowed String, into a JSON, an
// enum with values: null, boolean, number, string, array, object; a text
// that is not JSON gives the case error with the message and the offset
#import <JSON>
let main():i32 {
    var j = JSON.parse("{\"name\": \"kelvin\", \"tags\": [\"c\", 11, -2.5e3, true, null], \"ok\": false, \"nested\": {\"a\": [], \"b\": {}}}")
    println(j.is(object), " ", j.object.count, " ", j.object["name"].string, " ", j.object["tags"].array.count)
    println(j.object["tags"].array[1].number, " ", j.object["tags"].array[2].number, " ", j.object["tags"].array[3].boolean, " ", j.object["tags"].array[4].is(null))
    println(j.object["nested"].object["a"].array.count, " ", j.object["nested"].object["b"].object.count, " ", j.object["ok"].cstr)
    var s = JSON.parse("\"q\\\"b\\\\s\\/n\\n\\u00e9\\ud83d\\ude00\\t\"")
    println(s.string, " ", s.string.count)
    var text = $" [1, 2, 3] "
    var a = JSON.parse(&text)
    println(a.array.count, " ", a.array[2].number, " ", a.typename)
    var dup = JSON.parse("{\"k\": 1, \"k\": 2}")
    println(dup.object.count, " ", dup.object["k"].number)
    var n = JSON.parse("-0.5e+2")
    var t = JSON.parse("true")
    var nul = JSON.parse("null")
    println(n.number, " ", t.boolean, " ", nul.is(null))
    var bad = JSON.parse("[1, 2,")
    var bad2 = JSON.parse("{\"a\" 1}")
    var bad3 = JSON.parse("[1] x")
    var bad4 = JSON.parse("[01]")
    var bad5 = JSON.parse("\"\\ud800\"")
    var bad6 = JSON.parse("")
    println(bad.error, " | ", bad2.error, " | ", bad3.error)
    println(bad4.error, " | ", bad5.error, " | ", bad6.error)
    var deep = $""
    for k in 0..<600 { deep += "[" }
    var toodeep = JSON.parse(&deep)
    println(toodeep.is(error), " ", toodeep.error)
    return 0
}
// out: true 4 kelvin 5
// out: 11.0 -2500.0 true true
// out: 0 0 boolean(false)
// out: q"b\s/n
// out: é😀	 11
// out: 3 3.0 JSON
// out: 1 2.0
// out: -50.0 true true
// out: a value: unexpected end of text at 6 | ':' after a key: unexpected '1' at 5 | the end of the text: unexpected 'x' at 4
// out: ',' or ']' in an array: unexpected '1' at 2 | a lone surrogate at 7 | a value: unexpected end of text at 0
// out: true nesting deeper than 512 at 512
// c: JSON__parse__cstr(
