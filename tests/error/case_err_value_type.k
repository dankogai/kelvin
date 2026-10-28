// err(e) holds what the Result's err holds, in Kelvin's words (#411)
let parse(n:int64):Result<int64, String> {
    if n < 0 { return err(3) }
    return ok(n)
}
let main():int32 {
    println(parse(1))
    return 0
}
// error: case 'err' of Result<i64, String> holds a String, and this is a number
