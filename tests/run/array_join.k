// xs.join(sep) and xs.joined(sep), one method (#461): a new String of the
// elements, each as a template shows it, ${x}, with sep between them, ""
// where none is given; sep is a cstr, a String or a uchr, evaluated once
struct pt { x: int64; y: int64 }
var seps = 0
let sep():cstr {
    seps += 1
    return "/"
}
let words():$[String] { $[$"to", $"be"] }
let csv(xs:const $[int64]^):String { return xs^.join(",") }
let main():int32 {
    let ns = $[1, 2, 3]
    let ss = $[$"a", $"b", $"c"]
    let cs:$[cstr] = $["x", "y"]
    let bs = $[true, false]
    let us = $[uchr("k"), uchr("é")]
    let ps:$[pt] = $[{1, 2}, {3, 4}]
    let nest = $[$[1, 2], $[3]]
    let os:$[int64?] = $[5, none]
    let none_here:$[int64] = $[]
    var comma = $", "
    let dash = uchr("-")
    println(ns.join(", "), "|", ns.joined(), "|", ss.join(comma), "|", cs.joined("+"), "|", bs.join(sep()), " ", seps)
    println(us.join(dash), "|", ps.join("; "), "|", nest.join(" & "), "|", os.join(","), "|[", none_here.join(","), "]")
    let line = words().joined(" ")
    println(line, "|", line.count, "|", csv(&ns), "|", `<${ns.join("+")}>`, "|", $[0.5, 2.0].join(" "))
    return 0
}
// out: 1, 2, 3|123|a, b, c|x+y|true/false 1
// out: k-é|{x: 1, y: 2}; {x: 3, y: 4}|[1, 2] & [3]|some(5),none|[]
// out: to be|5|1,2,3|<1+2+3>|0.5 2.0
