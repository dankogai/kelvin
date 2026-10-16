// an Optional's flatMap takes a function that gives an Optional (#81)
let keep(n:int64):Result<int64, int32> { return n }
let main():int32 {
    var a:int64? = 3
    var m = a.flatMap(keep)
    return 0
}
// error: '.flatMap' takes a function that gives an Optional, a U?, and this gives Result<i64, i32>
