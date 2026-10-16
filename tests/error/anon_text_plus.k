// error: '.hex' text lives in a buffer of this function, which is gone once it returns
let main():int32 {
    let skip:(uint8):cstr := { &$0.hex[1] };
    return 0;
}
