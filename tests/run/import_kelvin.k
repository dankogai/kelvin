// #import of Kelvin files (#40): "x.k" is next to the importing file, and
// each file is compiled once, however often it is imported. Imported
// functions are named by their parameter types in C (#41).
#import "lib/shapes.k"
#import "lib/units.k"
#import "lib/shapes.k"

main():i32 {
    let s:square = {2.0}
    println(area(s), " ", area((circle){1.0}) == PI, " ", twice(1.5))
    describe(s)
    return 0
}
// out: 4.0 true 3.0
// out: a square of side 2
// c: double area__square(const struct square s)
// c: double area__circle(const struct circle c)
// c: void describe__square(const struct square s)
// c: double twice__f64(const double x)
