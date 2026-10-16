// an attribute is read without parentheses (#131)
struct rect { w: float64; h: f64 }
let rect.area:f64 { .w * .h }
let main():i32 {
    let r:rect = {2.0, 3.0}
    println(r.area())
    return 0
}
// error: 'area' is an attribute of rect: read it as '.area', with no parentheses
