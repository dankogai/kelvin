// ${:} needs the type written (#65)
let main():i32 {
    var x = ${:}
    return 0
}
// error: ${:} has no key and value types here: write Dictionary<K, V>(), or give the variable a type
