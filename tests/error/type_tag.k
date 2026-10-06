// error: 'point' is a type already: write 'point', not 'point.type'
struct point { x:i32; };
let main():i32 {
    var p:point.type;
    return 0;
}
