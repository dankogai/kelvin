// JSON.stringify (#113): a borrowed JSON as text, compact, or with a
// space, text that indents each level; numbers as JS writes them;
// strings escaped; members in the order added
#import <JSON>
let main():int32 {
    var j = JSON.parse("{\"name\": \"kelvin\", \"tags\": [\"c\", 11, -2.5e3, true, null], \"nested\": {\"a\": [], \"b\": {}}, \"esc\": \"q\\\"b\\\\\\n\\u00e9\\t\\u0001\"}")
    var flat = JSON.stringify(&j)
    println(flat)
    var pretty = JSON.stringify(&j, "  ")
    println(pretty)
    var tab = $"\t"
    var tabbed = JSON.stringify(&j.object["nested"], &tab)
    println(tabbed)
    var n = JSON.parse("[0, 3, 3.5, 1e21, 1e-7, 0.000001, 123456789012345678, -0, 1.5e300, 0.1, 100, 1e20, 12345.678]")
    var ns = JSON.stringify(&n)
    println(ns)
    var inf = JSON.array($[JSON.number(1.0 / 0.0), JSON.number(0.0 / 0.0), JSON.null])
    var infs = JSON.stringify(&inf)
    println(infs)
    j.object["tags"].array += JSON.number(12.0)
    j.object["new"] = JSON.string($"added")
    var again = JSON.stringify(&j)
    println(again)
    var back = JSON.parse(&again)
    var once = JSON.stringify(&back)
    println(once == again)
    var e = JSON.parse("{")
    var es = JSON.stringify(&e)
    println(es)
    return 0
}
// out: {"name":"kelvin","tags":["c",11,-2500,true,null],"nested":{"a":[],"b":{}},"esc":"q\"b\\\né\t\u0001"}
// out: {
// out:   "name": "kelvin",
// out:   "tags": [
// out:     "c",
// out:     11,
// out:     -2500,
// out:     true,
// out:     null
// out:   ],
// out:   "nested": {
// out:     "a": [],
// out:     "b": {}
// out:   },
// out:   "esc": "q\"b\\\né\t\u0001"
// out: }
// out: {
// out: 	"a": [],
// out: 	"b": {}
// out: }
// out: [0,3,3.5,1e+21,1e-7,0.000001,123456789012345680,0,1.5e+300,0.1,100,100000000000000000000,12345.678]
// out: [null,null,null]
// out: {"name":"kelvin","tags":["c",11,-2500,true,null,12],"nested":{"a":[],"b":{}},"esc":"q\"b\\\né\t\u0001","new":"added"}
// out: true
// out: "a key in an object: unexpected end of text at 1"
// c: JSON__stringify__const_JSONp(&j)
