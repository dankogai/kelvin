// a temporary (#187) is freed once its expression is done, so a pointer
// into it would dangle: bind the owner first
struct rec { name: String }
let make():rec { var r:rec = {.name = $"ann"}; return r }
let main():int32 {
    let p := make().name.cstr
    return 0
}
// error: this is a pointer into a struct rec that an expression gives, which is freed once the expression is done: bind it to a variable first
