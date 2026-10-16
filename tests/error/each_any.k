// error: an any^ has no elements to walk
let main():int32 {
    var v:any^;
    for x in v {
    }
    return 0;
}
