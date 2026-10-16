// a setter changes the var it is called on: a let cannot change (#132)
struct temp { kelvin: float64 }
var temp.celsius:f64 {
    get { .kelvin - 273.15 }
    set(v) { .kelvin = v + 273.15 }
}
let main():i32 {
    let t:temp = {300.0}
    t.celsius = 1.0
    return 0
}
// error: 't' is a let and cannot change; declare it with var
