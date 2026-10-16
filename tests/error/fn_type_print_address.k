// error: println cannot show a function: a function has no text
let add(n:int64):int64 { return n + 1; }
let main():int32 {
    println(&add);
    return 0;
}
