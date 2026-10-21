// a declaration and an assignment check the value's type (#255), as an
// entry of a Dictionary does (#246): a number takes any number, as C
// converts it; a String a String or text; a cstr text; an Optional its
// T or none; a pointer any pointer; anything else its own type
// out: 3 2.0 1 true
// out: lit own text
// out: some(5) none 7
// out: {x: 1} {x: 2} 1
struct pt { x: int64 }

let main():int32 {
    var i:int64 = 3
    var f:float64 = 2
    var u:uint8 = 1
    var b:bool = i > 2
    println(i, " ", f, " ", u, " ", b)
    var s:String = "lit"
    var t:String = $"own"
    var c:cstr := "text"
    println(s, " ", t, " ", c)
    var o:int64? = 5
    var n:int64? = none
    var j:int64 = 0
    j = 7
    println(o, " ", n, " ", j)
    var p:pt = (pt){1}
    var q:pt = p
    q.x = 2
    var r:int64^ := &i
    r := &j
    i = 1
    println(p, " ", q, " ", i)
    return 0
}
