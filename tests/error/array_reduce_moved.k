// an owner xs.reduce starts from (#184) moves in, as into a function
let main():int32 {
    var names = $[$"a", $"b"]
    var start = $""
    var all = names.reduce(start) { (s:String, n:String):String in s + n }
    println(start)
    return 0
}
// error: 'start' was moved out and holds nothing now: assign it anew before using it
