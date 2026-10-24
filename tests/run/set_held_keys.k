// A String an expression gives, as an element of a Set<String> or a key
// of a Dictionary<String, V>, is held while its text is copied in (#315):
// s += f(), and ${f()} and ${f(): v} where the type is written, as in a
// declaration, as s.insert(f()) and the literals in a chain held it
let label(n:int64):String { String(n) + "!" }
let made():Set<String> { return ${label(1), label(2)} }
let size(s:Set<String>):int64 { s.count }
let main():int32 {
    var seen:Set<String> = ${}
    seen += label(5)
    seen += label(5)
    seen += "text"
    println(seen, " ", seen.insert(label(6)), " ", seen.has(label(5)), " ", seen.remove(label(6)))
    var typed:Set<String> = ${label(3)}
    var d:Dictionary<String, int64> = ${label(4): 4, label(7): 7}
    d[label(8)] = 8
    println(typed, " ", d, " ", d[label(8)]!, " ", made(), " ", size(${label(9), label(9)}))
    typed = ${label(0)}
    println(typed, " ", Set<String>({label(1)}))
    return 0
}
// out: {"5!", "text"} true true true
// out: {"3!"} {"4!": 4, "7!": 7, "8!": 8} 8 {"1!", "2!"} 1
// out: {"0!"} {"1!"}
