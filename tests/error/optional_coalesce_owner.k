// ?? copies the value, so not of an owner (#72)
let main():i32 {
    var s:String? = none
    var y = s ?? $"x"
    return 0
}
// error: '??' would copy the value, and String owns: switch on it, or test '.is(some)' and read '.some'
