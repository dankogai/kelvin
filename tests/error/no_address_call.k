// what a function gives is a value with no address (#535); an owner it
// gives, a String, is held and has one
let f():i64 { 1 }
let take(p:const i64^):i64 { p^ }
let main():int32 {
    println(take(&f()))
    return 0
}
// error: what a function gives is a value, and has no address: '&' takes a variable, a member, an element or 'p^'; bind the value to a variable first
