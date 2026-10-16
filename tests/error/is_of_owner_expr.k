// .is of a Result that owns, given by an expression, would lose what it holds (#99)
let parse(s:cstr):Result<int64, String> { return i64(s) }
let main():i32 {
    println(parse("1").is(ok))
    return 0
}
// error: '.is' of a Result<i64, String> that an expression gives, which nothing would free: bind it to a variable first
