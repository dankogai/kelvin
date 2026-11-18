// an owner one branch of an if moved is moved after the if (#605), where
// that branch goes on: the other branch not moving it does not mend it
let eat(s:String) { }
let pick(c:bool, s:String):String {
    if c { eat(s) } else { println("kept") }
    return s
}
let main():int32 { println(pick(true, $"a")); return 0 }
// error: 's' was moved out and holds nothing now: assign it anew before using it
