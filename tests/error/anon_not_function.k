// error: an anonymous function cannot be passed here: the parameter is i64, not a function
let add(a:int64, b:int64):int64 { return a + b; }
let main():int32 {
    println(add(1) { $0 });
    return 0;
}
