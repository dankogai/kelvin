// flatMap's function gives a Result with the same err (#81)
let parse(s:cstr):Result<int64, String> { return int64(s) }
let keep(n:int64):Result<int64, int32> { return n }
let main():int32 {
    var m = parse("1").flatMap(keep)
    return 0
}
// error: '.flatMap' takes a function that gives a Result<U, String>, and this gives Result<i64, i32>
