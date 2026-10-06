// error: sizeof a type needs parentheses: sizeof(point)
struct point { x:i32; };
let main():i32 {
    println(sizeof point);
    return 0;
}
