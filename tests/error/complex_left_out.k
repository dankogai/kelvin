// C99's _Complex is left out on purpose (#404): <math>'s c64 and c32
let main():i32 {
    var z:f64 _Complex
    return 0
}
// error: '_Complex' is C99's complex type, left out on purpose: #import <math> and write c64 or c32, Kelvin's own
