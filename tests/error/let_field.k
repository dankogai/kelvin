// error: 'p' is a let and cannot change; declare it with var
struct point { x:int32; y:int32; };
let main():int32 {
    let p:struct point = {1, 2};
    p.x = 3;
    return 0;
}
