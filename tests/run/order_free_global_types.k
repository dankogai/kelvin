// a global named before it is written is moved up to before what names
// it (#626), and with it the types it names that are written between
// (#734): a struct after main whose members give a later global's
// functions their types, and one that holds another
let main():int32 {
    println(table[1].run(4), " ", table[0].name, " ", g.p.x, " ", k, " ", shade, " ", w.typename)
    return 0
}
struct entry { name:[uint8](8); run:(int64):int64 }
let table:[entry](2) = [{"inc", { $0 + 1 }}, {"dbl", { $0 * 2 }}]
struct point { x:int64; y:int64 }
struct holder { p:point; n:int64 }
let k:int64 = g.n + 1
let g:holder = {{1, 2}, 3}
enum color { red, green }
typealias width = int64
let shade:color = green
var w:width = 4
// out: 8 inc 1 4 1 i64
