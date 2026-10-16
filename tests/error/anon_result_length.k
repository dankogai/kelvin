// error: the result type, [i64](k)^, has an array length or a .type written in another scope
var g:[[int64](3)](2) = [[1, 2, 3], [4, 5, 6]];
let main():int32 {
    let k = 3;
    let f:(int64):[int64](k)^ := { (i:int64) in &g[i] };
    return 0;
}
