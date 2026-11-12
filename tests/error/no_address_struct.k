// a struct a function gives, which owns nothing, is a value with no
// address (#535)
struct pt { x: i64; y: i64 }
let mk():pt { (pt){1, 2} }
let takep(p:const pt^):i64 { p^.x }
let main():int32 {
    println(takep(&mk()))
    return 0
}
// error: what a function gives is a value, and has no address: '&' takes a variable, a member, an element or 'p^'; bind the value to a variable first
