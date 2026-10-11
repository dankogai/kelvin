// an Optional's flatMap takes a function that gives an Optional (#81)
let keep(n:i64):Result<i64, i32> { return n }
let main():i32 {
    var a:i64? = 3
    var m = a.flatMap(keep)
    return 0
}
// error: '.flatMap' takes a function that gives an Optional, a U?, and this gives Result<i64, i32>
