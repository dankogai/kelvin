// flatMap's function gives a Result with the same err (#81)
let parse(s:cstr):Result<i64, String> { return i64(s) }
let keep(n:i64):Result<i64, i32> { return n }
let main():i32 {
    var m = parse("1").flatMap(keep)
    return 0
}
// error: '.flatMap' takes a function that gives a Result<U, String>, and this gives Result<i64, i32>
