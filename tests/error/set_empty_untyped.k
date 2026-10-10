// ${} needs the type written (#71)
let main():i32 {
    var x = ${}
    return 0
}
// error: ${} has no element type here: write Set<T>(), or give the variable a type, as in 'var s:${String} = ${}'
