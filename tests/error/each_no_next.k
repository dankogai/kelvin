// error: a list is followed through a pointer field named next, and struct p has none
struct p { x:int32; };
let main():int32 {
    var a:p;
    for q in &a {
    }
    return 0;
}
