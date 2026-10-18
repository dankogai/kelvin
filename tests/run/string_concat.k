// s + t joins text into a new String (#183): either side a String, text or
// a uchr, one a String; a String in a variable is copied and stays, one an
// expression gives is taken, so that a chain frees what it made
let main():int32 {
    var s = $"a"
    var t = $"b"
    var u = s + t + "c" + $"d" + uchr("é")
    var v = "x" + s
    var w = s + ""
    var tpl = $`${1 + 1}` + "!"
    println(u, " ", u.count, " ", v, " ", w, " ", tpl, " ", s, " ", t)
    var big = s.copy()
    big += &t                                  // += still appends in place
    var ab = $"ab"
    var joined = big + t                       // a String an expression gives is compared once bound
    var other = u + "x"
    println(big == ab, " ", joined == other, " ", joined)
    return 0
}
// out: abcdé 5 xa a 2! a b
// out: true false abb
