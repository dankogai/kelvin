// a case that falls through goes on into the next (#386), with what it
// moved moved there (#605)
let eat(s:String) { }
let pick(n:i64, s:String) {
    switch n {
    case 1:
        eat(s)
        fallthrough
    case 2: eat(s)
    default: break
    }
}
let main():int32 { pick(1, $"a"); return 0 }
// error: 's' was moved out and holds nothing now: assign it anew before using it
