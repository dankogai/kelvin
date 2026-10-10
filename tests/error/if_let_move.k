// the value if let binds is still the Optional's (#74)
let take(s:String) {}
let main():i32 {
    var s:String? = $"x"
    if let x = s { take(x) }
    return 0
}
// error: 'x' is a value its Array, Dictionary, Optional or Result still owns: pass a borrow, '&x', or a copy
