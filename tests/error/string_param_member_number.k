// a member that is a number where a String parameter goes is said by
// its kind (#757), where kc said an owner moves in only as a whole
// variable
struct pair { n:int64, m:int64 }
let greet(s:String):int64 { 1 }
let main():int32 {
    var p:pair = {1, 2}
    println(greet(p.n))
    return 0
}
// error: 's' of 'greet' is a String, and this is i64
