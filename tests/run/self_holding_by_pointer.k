// what #659 leaves as it was: a struct holds itself by a pointer, an
// Optional of a pointer, or in an Array, each of which has a size
struct node { x:i64; next:node^ }
struct tree { x:i64; kids:Array<tree> }
struct link { x:i64; prev:node^? }
let main():int32 {
    var last:node = {3, nowhere}
    let first:node = {1, &last}
    var t:tree = {7, Array<tree>()}
    t.kids.append((tree){8, Array<tree>()})
    let l:link = {5, none}
    println(first.x + first.next^.x, " ", t.kids.count, " ", t.kids[0].x, " ", l.prev == none)
    return 0
}
// out: 4 1 8 true
