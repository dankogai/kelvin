// error: 'int' is not a Kelvin type; use i32 or u32
let f(x:int32, n:uint64) {
    var y:int32 = int(x);
}
