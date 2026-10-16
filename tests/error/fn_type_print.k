// error: println cannot show a function: a function has no text
let add(a:int64, b:int64):int64 { return a + b; }
let main():int32 {
    println(add);
    return 0;
}
