// inline (#392), before or after static: a function, a method, an
// operator, a function of the type, an attribute, in extend too, written
// as C's static inline, which one C file means exactly
struct point { x:f64, y:f64 }
inline let sq(x:i64):i64 { return x * x }
inline let point.norm2():f64 { return .x * .x + .y * .y }
static inline let point.origin():point { return {0.0, 0.0} }
inline static let point.unit():point { return {1.0, 0.0} }
inline let +(a:point, b:point):point { return {a.x + b.x, a.y + b.y} }
inline let point.sum:f64 { .x + .y }
extend point {
    inline let twice():point { return self + self }
}
static inline let hidden(n:i64):i64 { return n - 1 }
let main():i32 {
    let p:point = {3.0, 4.0}
    println(sq(7), " ", p.norm2(), " ", point.origin(), " ", point.unit(), " ", p + p)
    println(p.twice(), " ", p.sum, " ", hidden(3))
    return 0
}
// out: 49 25.0 {x: 0.0, y: 0.0} {x: 1.0, y: 0.0} {x: 6.0, y: 8.0}
// out: {x: 6.0, y: 8.0} 7.0 2
// c: static inline int64_t sq(const int64_t x)
// c: static inline double point__norm2(const struct point self)
// c: static inline struct point point__origin(void)
// c: static inline struct point point__twice(const struct point self)
