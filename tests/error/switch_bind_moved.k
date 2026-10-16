// the value a case binds is a let the enum still owns: not moved (#119)
enum shape { none; name: String }
let take(s:String) { println(s) }
let main():int32 {
    var s = shape.name($"x")
    switch s {
    case name(t): take(t)
    case none: println("none")
    }
    return 0
}
// error: 't' is a value its Array, Dictionary, Optional or Result still owns: pass a borrow
