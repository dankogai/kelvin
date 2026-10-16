// flatMap's function gives the Optional itself (#81)
let twice(n:int64):int64 { return n * 2 }
let main():int32 {
    var a:int64? = 3
    var m = a.flatMap(twice)
    return 0
}
// error: '.flatMap' takes a function that gives an Optional, a U?, and this gives i64
