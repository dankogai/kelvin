// an owner a case of a switch moved is moved after the switch (#605),
// where that case goes on
let eat(s:String) { }
let pick(n:i64, s:String):String {
    switch n {
    case 1: eat(s)
    default: break
    }
    return s
}
let main():int32 { println(pick(1, $"a")); return 0 }
// error: 's' was moved out and holds nothing now: assign it anew before using it
