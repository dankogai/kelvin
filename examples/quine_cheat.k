// A cheating quine, Perl's `open 0; print while <0>` in Kelvin: it reads
// its own source and prints it. kelvinc writes #line directives, so C's
// __FILE__ is this file's path as it was given to kelvinc; the program
// prints itself while that path still leads here, as from where it was
// built. The IO is held for the loop and closed after it (#466). A true
// quine, which reads nothing, is examples/quine.k.
// quine: prints its own source
#import <IO>
let main():i32 {
    for line in IO(__FILE__).lines { println(line.ok) }
    return 0
}
