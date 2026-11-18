// a file that names the prelude's types and writes no import of them, as
// a module's header does (#601): math's c64, BigInt and RegExp
let quarter(z:c64):c64 { z * 1.0.i }
let doubled(n:lent BigInt):BigInt { n * 2 }
let has_a(r:lent RegExp, s:const String^):bool { r.test(s) }
