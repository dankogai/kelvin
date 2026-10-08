// .uchr converts an integer (#56)
let main():i32 {
    let c = 1.5.uchr
    return 0
}
// error: '.uchr' converts an integer to a codepoint, and this is f64
