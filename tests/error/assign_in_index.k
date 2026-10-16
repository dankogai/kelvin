// error: assignment is a statement in Kelvin, not a value
let main():int32 {
    var a:[int32](3);
    var i:int32 = 0;
    a[i += 1] = 2;
    return 0;
}
