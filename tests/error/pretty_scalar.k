// .pretty is of a value with brackets; a number's text is .cstr (#124)
let main():i32 {
    let n:i64 = 3
    println(n.pretty)
    return 0
}
// error: '.pretty' is the text, indented, of a struct, an enum with values, an Optional, a Result, an Array, a Dictionary or a Set; this is i64, whose text is '.cstr'
