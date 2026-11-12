// a literal has no address (#535)
let take(p:const i64^):i64 { p^ }
let main():int32 {
    println(take(&5))
    return 0
}
// error: a literal is a value, and has no address: '&' takes a variable, a member, an element or 'p^'; bind the value to a variable first
