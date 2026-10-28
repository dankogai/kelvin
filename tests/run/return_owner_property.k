// a property that makes a new owner is returned, moved out (#280): a
// Set's elements, a Dictionary's keys and values, an IO's string, bytes,
// abspath, basename, dirname and listdir, and a container's pretty, of a
// borrow or a local, with return or as a body's value; none lives in a
// buffer of the function, as .hex's text does
#import <IO>
let elements(s:const Set<int64>^):$[int64] { return s^.elements }
let words(s:const ${String}^):$[String] { s^.elements }
let local():$[int64] {
    let s = ${7, 8}
    return s.elements
}
let keys(d:const ${String: int64}^):$[String] { return d^.keys }
let values(d:const ${String: int64}^):$[int64] { d^.values }
let text(f:IO^):Result<String, i64> { return f^.string }   // a Result (#406)
let raw(f:IO^):Bytes { return f^.bytes }
let full(f:IO^):String { return f^.abspath }
let base(f:IO^):String { return f^.basename }
let dir(f:IO^):String { return f^.dirname }
let names(f:IO^):$[String] { return f^.listdir }
let pretty(a:const $[int64]^):String { return a^.pretty }
let main():int32 {
    let s = ${3, 1, 4}
    let w = ${"to", "be"}
    let d = ${"a": 1, "b": 2}
    let a = $[5, 6]
    println(elements(&s), " ", words(&w), " ", local(), " ", keys(&d), " ", values(&d))
    println(OS.makedirs("return_owner_property.tmpdir"))
    var out = IO("return_owner_property.tmpdir/f.txt", "w")
    out.write("hello\n")
    out.close()
    var f = IO("return_owner_property.tmpdir/f.txt", "r")
    print(text(&f) ?? $"?")
    var g = IO("return_owner_property.tmpdir/f.txt", "r")
    println(raw(&g).count, " ", base(&g), " ", dir(&g), " ", full(&g).count > 0)
    var h = IO("return_owner_property.tmpdir", "r")
    println(names(&h))
    println(pretty(&a))
    println(OS.remove("return_owner_property.tmpdir/f.txt"), " ", OS.rmdir("return_owner_property.tmpdir"))
    return 0
}
// out: [3, 1, 4] ["to", "be"] [7, 8] ["a", "b"] [1, 2]
// out: 0
// out: hello
// out: 6 f.txt return_owner_property.tmpdir true
// out: ["f.txt"]
// out: [
// out:   5,
// out:   6
// out: ]
// out: 0 0
