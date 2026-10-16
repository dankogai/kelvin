// error: 'a' is a let and cannot change; declare it with var
let main():int32 {
    let a:[int32](2) = [1, 2];
    a[0] = 3;
    return 0;
}
