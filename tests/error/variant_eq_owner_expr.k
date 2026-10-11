// a Result that owns, given by an expression, is not compared: nothing would free it (#79)
let parse(s:cstr):Result<i64, String> { return i64(s) }
let main():i32 {
    println(parse("1") == parse("1"))
    return 0
}
// error: a Result<i64, String> that an expression gives, which nothing would free: bind it to a variable first
