// a call of an overloaded function has the result of the overload it
// calls, in the checks of what has a value (#593): one with no result is
// a line of its own, one with a result is a body's value, and where C
// chooses among overloads that differ in having one, C sees which it is
#import <stdlib.h> as C

let note(x:int64) { println("note ", x) }
let note(x:float64):float64 { return x * 2.0 }

// the program's own log, with no result, beside math's, with one
let log(x:int64) { println("log ", x) }

let doubled(x:float64):float64 { note(x) }            // the overload with a result: the body's value
let chosen():float64 { note(atof("1.5")) }           // C chooses it, of what atof gives
let told(x:int64) { note(x) }                         // the one with none, in a body with none
let natural(x:float64):float64 { log(x) }             // math's log, a value
let logged(x:int64) { log(x) }                        // the program's, none

let main():int32 {
    println(doubled(1.5), " ", chosen())
    told(3)
    note(4)                       // a line of its own
    note(4.5)                     // and its value dropped in main, as any call's
    note(atof("2.5"))
    println(natural(1.0), " ", sqrt(log(1.0)))
    logged(5)
    log(6)
    let y = log(1.0)
    println(y, " ", note(0.25))
    return 0
}
// out: 3.0 3.0
// out: note 3
// out: note 4
// out: 0.0 0.0
// out: log 5
// out: log 6
// out: 0.0 0.5
