// a method is declared with let too (#45)
struct point { x: float64; y: f64 }
point.norm():f64 { .x * .x + .y * .y }
let main():i32 { return 0 }
// error: a function is declared with let: write 'let point.norm(...)'
