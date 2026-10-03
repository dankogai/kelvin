// error: sizeof a type needs parentheses: sizeof(point)
struct point { x:i32; };
main():i32 {
    println(sizeof point);
    return 0;
}
