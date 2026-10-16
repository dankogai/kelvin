// a method is declared with let too (#45)
struct point { x: float64; y: float64 }
point.norm():float64 { .x * .x + .y * .y }
let main():int32 { return 0 }
// error: a function is declared with let: write 'let point.norm(...)'
