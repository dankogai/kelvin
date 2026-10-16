// error: '.cstr' of a function: a function has no text
let add(a:int64):int64 { return a; }
let main():int32 {
    println(add.cstr);
    return 0;
}
