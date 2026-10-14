// an instance attribute is computed: a stored one is a member of the struct (#131)
struct rect { w: f64; h: f64 }
let rect.depth = 1.0
let main():i32 { return 0 }
// error: an instance attribute is computed, 'let rect.depth:R { ... }': a stored one is a member of the struct
