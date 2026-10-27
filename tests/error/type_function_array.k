// error: an array type is written '[T]', or '[T](N)' with its count (#49): write '[inc.type](2)' for 'inc.type[2]'
let inc(x:int64):int64 { return x + 1; }
let main():int32 {
    var hs:inc.type[2];
    return 0;
}
