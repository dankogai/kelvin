// error: a list is followed through a pointer field named next, and struct p has none
struct p { x:i32; };
let main():i32 {
    var a:p;
    for q in &a {
    }
    return 0;
}
