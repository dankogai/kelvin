// j["key"] and j[i] on a JSON (#117): an enum with values is indexed
// through its Dictionary case with text and its Array case with an
// integer, so j["a"]["b"][0] reads a path, is a place to assign to, and
// is checked as the case and the index are
#import <JSON>
let main():i32 {
    var j = JSON.parse("""{"name": "kelvin", "tags": ["c", 11, {"deep": true}], "n": 3}""")
    println(j["name"].string, " ", j["tags"][1].number, " ", j["tags"][2]["deep"].boolean, " ", j["n"].number)
    j["n"] = JSON.number(4.0)                    // replaces
    j["new"] = JSON.string($"added")             // adds
    j["tags"][0] = JSON.string($"C")             // an element, checked
    j["tags"].array += JSON.null                 // grown through the case
    var text = JSON.stringify(&j)
    println(text)
    var key = $"name"
    println(j[key].string, " ", j["tags"][0].string.count, " ", j["tags"].array.count)
    var a = JSON.parse("[10, 20, 30, 40]")
    var part = a[1..<3]                          // a slice of the Array case, a new Array<JSON>
    println(a[3].number, " ", part.count, " ", part[0].number)
    var sum = 0.0
    for x in a.array { sum += x.number }
    println(sum)
    return 0
}
// out: kelvin 11.0 true 3.0
// out: {"name":"kelvin","tags":["C",11,{"deep":true},null],"n":4,"new":"added"}
// out: kelvin 1 4
// out: 40.0 2 20.0
// out: 100.0
// c: _kv_dict_String_JSON_at(&(*_kv_JSON_at_object(&j)), "name")
