// error: a base is for reading an integer from text; f64(text) reads decimal
let main():i32 {
    println(f64("1.5", 10))
    return 0
}
