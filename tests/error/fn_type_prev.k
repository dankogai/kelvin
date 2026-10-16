// error: '.prev' is a property of pointers to data, and (i64):i64 is a function
let main():int32 {
    var f:(int64):int64;
    f := f.prev;
    return 0;
}
