// error: 'n' is a value (i32): assign it with '=', not ':='
var x:int32 = 1;
struct inner { p:int32^; v:int32; };
struct inner;
let main():int32 {
    var n:int32 = 1; k = 1, n := 5;
    return 0;
}
