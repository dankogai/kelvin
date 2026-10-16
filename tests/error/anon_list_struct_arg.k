// error: a list is not a value here: the parameter is struct point, so write a compound literal
struct point { x:int32; y:int32; };
let show(p:point) { println(p.x); }
let main():int32 {
    show({1, 2});
    return 0;
}
