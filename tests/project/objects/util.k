// compiled alone by kelvinc -c into util.o (#281), which main.o calls:
// RegExp's library, and UnicodeData's after it, come in at the link. It
// names math's c64 and abs, as main.k does: math is the prelude's, which
// libkelvin holds, so the two objects link (#591)
#import <RegExp>
let digits(s:String^):bool {
    let re = $/[0-9]+/
    return re.test(s)
}
let ids():Set<int64> { ${7, 8} }
let label(n:int64):String { $`n=${n}` }
let size(z:c64):f64 { abs(z) + sqrt(4.0) }
