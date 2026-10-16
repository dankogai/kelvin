// error: expected 'in' after the parameters
let main():int32 {
    let f := { (a:int64):int64 in a };
    let g := { (a:int64):int64 a };
    return 0;
}
