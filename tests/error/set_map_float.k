// '.map' of a Set makes a Set (#307), whose elements are integers or
// Strings (#71): an f64 is none, so the message says to map its elements
let main():int32 {
    let s = ${3, 1}
    println(s.map { ($0 as float64) / 2.0 })
    return 0
}
// error: '.map' of a Set makes a Set, whose elements are integers or Strings, and this gives f64: map its elements, 's.elements.map'
