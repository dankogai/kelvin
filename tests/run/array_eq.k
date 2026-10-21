// a0 == a1 (#247): two Arrays of the same element type with as many
// elements, each equal to the one in its place by its own ==: a String
// by its text, an Optional by its case and value, an Array or a
// Dictionary by its own ==; != is the opposite; one an expression gives
// is held
// out: true false false true true
// out: true false
// out: true false
// out: true false
// out: true
// out: true true false
// out: true
enum tree { leaf: int64; kids: Array<tree> }   // an enum and its Array compare each other

let nums():Array<int64> { return $[1, 2, 3] }

let main():int32 {
    var a = $[1, 2, 3]
    var b = $[1, 2, 3]
    let c = $[1, 2]
    println(a == b, " ", a != b, " ", a == c, " ", a == nums(), " ", nums() != $[1, 2, 4])
    var s = $[$"x", $"y"]
    println(s == $[$"x", $"y"], " ", s == $[$"y", $"x"])
    var n = $[$[1], $[2, 3]]
    println(n == $[$[1], $[2, 3]], " ", n == $[$[1], $[2]])
    var o:Array<int64?> = $[1, none]
    var p:Array<int64?> = $[1, 0]
    println(o == o, " ", o == p)
    var d = $[${"a": 1}]
    println(d == $[${"a": 1}])
    var k1 = tree.kids($[tree.leaf(1)])
    var k2 = tree.kids($[tree.leaf(1)])
    var k3 = tree.kids($[tree.leaf(1), tree.leaf(2)])
    println(k1 == k2, " ", $[k1.copy()] == $[k2.copy()], " ", k1 == k3)
    var e:Array<int64> = $[]
    var f:Array<int64> = $[]
    println(e == f)
    return 0
}
