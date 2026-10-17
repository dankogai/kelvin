// RegExp (#160): split with a function of each piece, a String it owns,
// the pieces that split gives in an Array, on a String and on a RegExp
#import <RegExp>
let main():int32 {
    let comma = $/\s*,\s*/
    var list = $"212F , 32F,-40F"
    list.split(&comma) { println("[", $0, "] ", $0.count) }
    let each = $//
    var word = $"héllo"
    word.split(&each) { print($0, "|") }
    println()
    let bare = $/,/
    var edged = $",a,,b,"
    bare.split(&edged) { print("<", $0, ">") }
    println()
    var empty = $""
    empty.split(&bare) { println("empty: [", $0, "]") }
    empty.split(&each) { println("never") }
    let blanks = $/\s+/
    var padded = $" a b "
    padded.split(&blanks) { print("(", $0, ")") }
    println()
    return 0
}
// out: [212F] 4
// out: [32F] 3
// out: [-40F] 4
// out: h|é|l|l|o|
// out: <><a><><b><>
// out: empty: []
// out: ()(a)(b)()
