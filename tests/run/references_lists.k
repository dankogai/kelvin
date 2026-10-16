// declaration lists and globals with := (review of #19); a list either
// declares, with let or var, or assigns (#27)
var x:int32 = 7;
var y:int32 = 1;
var g := 0 as int32^;                     // a global reference, inferred
static var h := 0 as int32^;

let main():int32 {
    g := &x;
    h := g;
    var p:int32^ := &y;
    var n:int32 = 7;
    p := &x, n = 0;                         // a list of assignments
    for (var i = 0; i < 3; i += 1)
        n = n + 1;
    println(g^, " ", h^, " ", p^, " ", n);
    var k = 1, m = 40;
    println(k, " ", m);
    return 0;
}
// out: 7 7 7 3
// out: 1 40
