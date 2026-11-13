// an integer type's random takes nothing or one range (#547): two bounds
// are written as a range
let main():int32 {
    println(i64.random(1, 6))
    return 0
}
// error: i64.random takes nothing, for any i64, or a range, as in 'i64.random(1...6)'
