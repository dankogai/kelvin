// c ? a : b of owners (#203): returned, it moves whichever arm it gives,
// a local or a parameter, and a value an expression gives as itself, so
// nothing is freed twice; two places are read where they are, as each
// alone would be; appending one appends an element
let pick(paren:bool):String {
    var s = $"abc"
    return paren ? $"(" + s + ")" : s
}
let either(c:bool):String {
    var s = $"left"
    var t = $"right"
    return c ? s : t
}
let nested(n:int64):String {
    var a = $"one"
    var b = $"two"
    return n == 1 ? a : n == 2 ? b : $"many"
}
let given(c:bool, s:String, t:String):String { c ? s : t }   // a body of one expression returns it
let main():int32 {
    println(pick(false), " ", pick(true), " ", either(true), " ", either(false))
    println(nested(1), " ", nested(2), " ", nested(3), " ", given(true, $"p", $"q"), " ", given(false, $"p", $"q"))
    var s = $"abc"
    var t = $"de"
    var c = true
    println(c ? s : t, " ", (c ? s : t).count, " ", s, " ", t)
    var xs:$[String] = $[]
    xs += c ? s.copy() : t.copy()
    xs += c ? $"x" : $"y"
    println(xs)
    return 0
}
// out: abc (abc) left right
// out: one two many p q
// out: abc 3 abc de
// out: ["abc", "x"]
// c: return paren ? ({
// c: kv_string_take(&s)
