// a switch ends where every case ends, and one case here goes on (#625)
let name(a:i64):cstr {
    switch a {
    case 0: return "zero"
    default: println(a)
    }
}
let main():int32 {
    println(name(2))
    return 0
}
// error: 'name' can reach the end of its body with no value: every path of a function with a result returns one
