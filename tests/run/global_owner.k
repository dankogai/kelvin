// a global owner is declared with its type alone, empty, and given its
// value in a function (#178); it lives for the program
#import <RegExp>
var journal:String
var seen:Array<int64>
var re:RegExp
let note(what:cstr):() {
    journal += what
    journal += "; "
    seen += journal.count as int64
}
let main():int32 {
    note("start")
    re = RegExp("\\d+", "g")
    note("compiled")
    var m = journal.match(&re)
    println(journal, " ", seen, " ", m.count, " ", re.global)
    return 0
}
// out: start; compiled;  [7, 17] 0 true
