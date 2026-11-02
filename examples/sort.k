// Sorting an Array<T>, $[T]: in place with .sort, or a new one with
// .sorted, by < or by a function, an anonymous one with $0 and $1 or a
// named one; the sort is stable. map, filter, reduce and prefix chain,
// and C's qsort still sorts a fixed array, by a comparator it writes.
#import <stdlib.h> as C
#import <string.h> as C

struct planet {
    name:  cstr
    au:    f64        // its mean distance from the Sun
    moons: i64
}

let more_moons(a:planet, b:planet):bool { a.moons > b.moons }

let main():i32 {
    var xs = $[5, 3, 8, 1, 9, 2, 7, 4]
    xs.sort()                                        // by <
    println(xs)
    xs.sort { $0 > $1 }                              // by a function
    println(xs, " ", xs.sorted { $0 % 2 < $1 % 2 })  // evens first, in the order they were
    println(xs.map { $0 * $0 }.filter { $0 > 20 }.reduce(0) { $0 + $1 }, " ", xs.reversed().prefix(3))

    var planets:$[planet] = $[
        {"Mercury", 0.39, 0}, {"Venus", 0.72, 0}, {"Earth", 1.0, 1}, {"Mars", 1.52, 2},
        {"Jupiter", 5.2, 95}, {"Saturn", 9.54, 146}, {"Uranus", 19.2, 28}, {"Neptune", 30.1, 16},
    ]
    planets.sort(more_moons)                         // a named function
    for p in planets.prefix(3) {
        println(p.name, " has ", p.moons, " moons")
    }
    println(planets.sorted { $0.au > $1.au }.map { $0.name })
    println(planets.filter { $0.moons == 0 }.map { $0.name })

    var names:[cstr](4) = ["kelvin", "celsius", "rankine", "fahrenheit"]
    qsort(names, names.count, sizeof(cstr)) { (a:const any^, b:const any^):i32 in
        strcmp((a as const cstr^)^, (b as const cstr^)^)
    }
    for i in 0..<names.count {
        print(i == 0 ? "" : " ", names[i])
    }
    println()
    return 0
}
// out: [1, 2, 3, 4, 5, 7, 8, 9]
// out: [9, 8, 7, 5, 4, 3, 2, 1] [8, 4, 2, 9, 7, 5, 3, 1]
// out: 219 [1, 2, 3]
// out: Saturn has 146 moons
// out: Jupiter has 95 moons
// out: Uranus has 28 moons
// out: ["Neptune", "Uranus", "Saturn", "Jupiter", "Mars", "Earth", "Venus", "Mercury"]
// out: ["Mercury", "Venus"]
// out: celsius fahrenheit kelvin rankine
