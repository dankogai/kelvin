// RegExp (#159): match with a function of each Match, every match with g
// and the first alone without, on a String and on a RegExp; replace with
// a function (#158), Fahrenheit to Celsius
#import <RegExp>
let main():int32 {
    let temp = $/(-?\d+(?:\.\d+)?)F\b/g
    var s = $"water boils at 212F and freezes at 32F; -40F is -40C"
    s.match(&temp) { println($0.text[1], " at ", $0.start, "..<", $0.end) }
    var c = s.replace(&temp) { $`${(f64($0.text[1]) - 32.0) * 5.0 / 9.0}C` }
    println(c)
    temp.match(&s) { print("[", $0.text[0], "]") }
    println()
    let first = $/\d+/
    s.match(&first) { println("first: ", $0.text[0]) }
    let none = $/x+/
    s.match(&none) { println("never") }
    var empty = $"ab"
    let nothing = $//g
    empty.match(&nothing) { print($0.start, " ") }
    println()
    return 0
}
// out: 212 at 15..<19
// out: 32 at 35..<38
// out: -40 at 40..<44
// out: water boils at 100.0C and freezes at 0.0C; -40.0C is -40C
// out: [212F][32F][-40F]
// out: first: 212
// out: 0 1 2 
