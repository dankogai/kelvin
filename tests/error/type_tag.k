// error: 'point' is a type already: write 'point', not 'point.type'
struct point { x:int32; };
let main():i32 {
    var p:point.type;
    return 0;
}
