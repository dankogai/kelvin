// error: a pointer to a function type, or an array of functions, has no spelling yet
let inc(x:int64):int64 { return x + 1; }
let main():int32 {
    var hs:inc.type[2];
    return 0;
}
