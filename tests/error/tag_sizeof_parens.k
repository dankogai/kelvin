// error: sizeof a type needs parentheses: sizeof(point)
struct point { x:int32; };
let main():int32 {
    println(sizeof point);
    return 0;
}
