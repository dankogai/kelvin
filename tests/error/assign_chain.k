// error: assignment is a statement in Kelvin, not a value
let main():int32 {
    var a:int32 = 0, b:int32 = 0;
    a = b = 1;
    return 0;
}
