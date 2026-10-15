// a function of the type has no self, so no .x (#111, #139)
struct point { x: i64; y: i64 }
static let point.origin():point {
    return {.x, 0}
}
let main():i32 { return 0 }
// error: a function of a type, called as T.name(...), has no self
