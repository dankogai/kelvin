// error: the loop variable of a list is each node's pointer, struct node^, not i32
struct node { value:i32; next:node^; };
let main():i32 {
    var a:node = {1, nullptr};
    for v:i32 in &a {
        println(v);
    }
    return 0;
}
