// compiled alone by kelvinc -c into util.o (#281), which main.o calls:
// RegExp's library, and UnicodeData's after it, come in at the link
#import <RegExp>
let digits(s:String^):bool {
    let re = $/[0-9]+/
    return re.test(s)
}
let ids():Set<int64> { ${7, 8} }
let label(n:int64):String { $`n=${n}` }
