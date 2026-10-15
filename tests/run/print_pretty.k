// v.pretty (#124): the value's text indented, each item of a [] or {} on a
// line of its own, two spaces a level; a case's () stays on its line and
// holds what it holds; an empty [] or {} stays as it is; a type's own
// T.cstr() is its text on one line; where print shows it, it is printed
// where it stands, and elsewhere it is a String
#import <JSON>
#import <IO>
struct point { x: int64; y: i64 }
struct vector2d { x: f64; y: f64 }
let vector2d.cstr():cstr { `(${.x}, ${.y})` }
struct scene { name: String; points: Array<point>; tags: ${String: i64}; empty: $[i64]; v: vector2d }
let main():i32 {
    var sc:scene = {$"demo", $[{1, 2}, {3, 4}], ${"a": 1}, $[], {0.5, 1.0}}
    println(sc.pretty)
    var grid = $[$[1, 2], $[3]]
    println("grid = ", grid.pretty)
    var j = JSON.parse("""
        {"name": "kelvin", "tags": ["c", 11]}
        """)
    println(j.pretty)
    var text = grid.pretty                   // a String elsewhere
    println(text.count, " ", text.typename)
    var o:point? = {7, 8}
    IO.stdout.println(o.pretty)
    return 0
}
// out: {
// out:   name: "demo",
// out:   points: [
// out:     {
// out:       x: 1,
// out:       y: 2
// out:     },
// out:     {
// out:       x: 3,
// out:       y: 4
// out:     }
// out:   ],
// out:   tags: {
// out:     "a": 1
// out:   },
// out:   empty: [],
// out:   v: (0.5, 1.0)
// out: }
// out: grid = [
// out:   [
// out:     1,
// out:     2
// out:   ],
// out:   [
// out:     3
// out:   ]
// out: ]
// out: object({
// out:   "name": string("kelvin"),
// out:   "tags": array([
// out:     string("c"),
// out:     number(11)
// out:   ])
// out: })
// out: 39 String
// out: some({
// out:   x: 7,
// out:   y: 8
// out: })
