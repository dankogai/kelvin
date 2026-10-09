// an Array an expression gives is never freed, so it is not indexed (#57, #64)
let rows():$[i64] {
    var r = $[1, 2]
    return r
}
let main():i32 {
    println(rows()[0])
    return 0
}
// error: '[]' of an Array that an expression gives, which nothing would free: bind it to a variable first
