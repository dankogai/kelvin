// error: println cannot show a function: a function has no text
let add1(x:int64):int64 { return x + 1; }
let mul2(x:int64):int64 { return x * 2; }
let main():int32 {
    let c = true;
    println(c ? add1 : mul2);
    return 0;
}
