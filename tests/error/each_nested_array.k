// error: for over an array of arrays: index it
let main():int32 {
    let m:[[int32](2)](2) = [[1, 2], [3, 4]];
    for r in m {
    }
    return 0;
}
