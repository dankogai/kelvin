// p-- is a statement (#51), not a value, as every assignment is (#26)
// error: '--' is a statement in Kelvin, not a value: step the pointer on a line of its own
let main():i32 {
    var a:[i32](2) = [1, 2];
    var p:i32^ := &a[1];
    println(p--^);
    return 0;
}
