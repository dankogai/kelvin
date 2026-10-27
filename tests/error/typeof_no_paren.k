// typeof takes its value or type in parentheses (#398), as C23's
let main():i32 {
    let n = 1
    var x:typeof n = 2
    return 0
}
// error: typeof takes a value or a type in parentheses, as C23's: typeof(x)
