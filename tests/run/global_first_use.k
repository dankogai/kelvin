// a global C cannot initialize (#493), one that owns or of a value that is
// not a constant, is given its value at its first use, once, on any thread:
// a String, an Array, a Dictionary, a RegExp, a call, another such global's
// value; a constant stays C's initializer. It is changed as any global, and
// freed at exit
#import <RegExp>
#import <OS>
let made(what:cstr):String {
    println("made ", what)
    return String(what)
}
let slow():i64 {
    println("slow, once")
    OS.sleep(0.2)
    return 7
}
var names:Array<String> = $["a", "b"]
var counts = ${"x": 1}
let re = $/(\d+)F/g
var first:String = made("first")
var unused:String = made("never")
let twice:f64 = f64(names.count) * 2.0
let limit = 10 * 4
let shared:i64 = slow()
let read(n:i64):i64 { shared + n }
let main():int32 {
    println("main starts")
    println(names, " ", counts, " ", twice, " ", limit)
    println(first, " ", first)
    names += $"c"
    counts["y"] = 2
    first = $"changed"
    println(names.count, " ", counts, " ", first)
    var s = $"20F and 30F"
    println(s.match(&re).count)
    var a = async read(1)
    var b = async read(2)
    println(await a, " ", await b)
    return 0
}
// out: main starts
// out: ["a", "b"] {"x": 1} 4.0 40
// out: made first
// out: first first
// out: 3 {"x": 1, "y": 2} changed
// out: 2
// out: slow, once
// out: 8 9
