// a $/.../ literal is the prelude's RegExp (#504), which a type of the
// program named RegExp hides
struct RegExp { plain: bool }
let main():int32 {
    let re = $/a+/
    return 0
}
// error: a $/.../ literal is the prelude's RegExp, which a type of this program named RegExp hides: rename that type (#504)
