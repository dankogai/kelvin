// error: a template's text lives until this block ends, and 'label' outlives it
let main():i32 {
    let n:i64 = 1
    var label:cstr := "none"
    if n > 0 {
        label := `positive ${n}`
    }
    println(label)
    return 0
}
