// an attribute is not named as a member of its struct (#131)
struct rect { w: float64; h: f64 }
let rect.w:f64 { 1.0 }
let main():i32 { return 0 }
// error: 'w' is a member of rect already: an attribute is computed, a member stored, so name the attribute otherwise
