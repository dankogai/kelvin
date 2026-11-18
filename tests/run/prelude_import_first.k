// A module of the prelude that an #import writes is read where the
// prelude's is, before all else (#601), and not where the import stands:
// lib/turns.k names c64, BigInt and RegExp and imports none of them, as
// a module's header does not, and the imports written after it put each
// after it, whose type C then did not know, "unknown type name 'c64'".
// <BigNum>'s header writes #import <math>, so any header that named c64
// and was imported before <BigNum> met it
#import "lib/turns.k"
#import <math>
#import <BigInt>
#import <RegExp>
let main():int32 {
    let s = $"caat"
    println(quarter(c64(1.0, 2.0)), " ", doubled(21n), " ", has_a($/a+/, &s))
    return 0
}
// out: (-2.0+1.0.i) 42n true
