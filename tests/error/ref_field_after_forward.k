// error: this target is a reference (i32^): assign it with ':=', not '='
var x:int32 = 1;
struct inner { p:int32^; v:int32; };
struct inner;
let main():int32 {
    var s:struct inner; s.p = &x;
    return 0;
}
