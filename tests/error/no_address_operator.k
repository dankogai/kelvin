// what an operator gives has no address (#535)
let take(p:const i64^):i64 { p^ }
let main():int32 {
    var x = 1
    println(take(&(x + 1)))
    return 0
}
// error: what '+' gives is a value, and has no address: '&' takes a variable, a member, an element or 'p^'; bind the value to a variable first
