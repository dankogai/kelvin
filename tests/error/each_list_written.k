// error: the loop variable of a list is each node's pointer, struct node^, not i32
struct node { value:int32; next:node^; };
let main():int32 {
    var a:node = {1, nullptr};
    for v:int32 in &a {
        println(v);
    }
    return 0;
}
