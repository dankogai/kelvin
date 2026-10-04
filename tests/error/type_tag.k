// error: 'point' is a type already: write 'point', not 'point.type'
struct point { x:i32; };
main():i32 {
    var p:point.type;
    return 0;
}
