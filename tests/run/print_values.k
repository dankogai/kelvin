// print and println show a value whole, on one line (#123): a struct as
// {x: 1}, an enum with values as n(v), an Array as [a, b], a Dictionary
// as {"k": v} in the order added, a Set as {a, b}; a String, a Bytes or a
// cstr inside a value is quoted and escaped, also in .cstr, which is cut
// to its room while print shows everything; f.println too
#import <JSON>
#import <IO>
struct point { x: i64; y: i64 }
struct bag { name: String; at: point; tags: Array<String>; label: cstr; raw: Bytes }
enum shape { none; dot: point; path: Array<point> }
let main():i32 {
    var xs = $[1, 2, 3]
    var empty0:$[i64] = $[]
    var names = $[$"ann", $"bob"]
    var grid = $[$[1, 2], $[3]]
    println(xs, " ", empty0, " ", names, " ", grid)
    var ages = ${"ann": 31, "bob": 42}
    var byId = ${7: $"seven", 1: $"one"}
    var empty:${String: i64} = ${:}
    var s = ${3, 1, 4}
    println(ages, " ", byId, " ", empty, " ", s)
    var raw = Bytes("a\tb")
    raw += 255 as u8
    var b:bag = {$"say \"hi\"\n", {1, 2}, $[$"x", $"y"], "c\\d", raw.copy()}
    println(b)
    println(b.cstr)
    var p = shape.path(Array<point>([{0, 0}, {1, 1}]))
    var q = shape.dot({5, 6})
    var z = shape.none
    println(p, " ", q, " ", z)
    var r:Result<Array<i64>, String> = ok($[1, 2])
    var o:String? = $"x"
    var n:String? = none
    println(r, " ", o, " ", n)
    var j = JSON.parse("""
        {"name": "kelvin", "tags": ["c", 11], "ok": true}
        """)
    println(j)
    IO.stdout.println("to a stream: ", xs, " ", ages)
    return 0
}
// out: [1, 2, 3] [] ["ann", "bob"] [[1, 2], [3]]
// out: {"ann": 31, "bob": 42} {7: "seven", 1: "one"} {} {3, 1, 4}
// out: {name: "say \"hi\"\n", at: {x: 1, y: 2}, tags: ["x", "y"], label: "c\\d", raw: "a\tb\xff"}
// out: {name: "say \"hi\"\n", at: {x: 1, y: 2}, tags: [...], label: "c\\d", raw: "a\tb\xff"}
// out: path([{x: 0, y: 0}, {x: 1, y: 1}]) dot({x: 5, y: 6}) none
// out: ok([1, 2]) some("x") none
// out: object({"name": string("kelvin"), "tags": array([string("c"), number(11)]), "ok": boolean(true)})
// out: to a stream: [1, 2, 3] {"ann": 31, "bob": 42}
// c: _kv_show__kv_array_i64(&(kv_out){.fp = NULL, .width = 2}, &_kv_sv, -1)
