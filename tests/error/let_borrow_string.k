// error: 's' of 'shout' is a String^, which may change what it borrows, and this is const String^, a let's: write const in the type taken, or borrow a var
// &s of a let String is a const borrow (#273): a String^ that may change
// it does not take it, which changed the let before
let shout(s:String^) { s^ += "!" }

let main():int32 {
    let s = $"abc"
    shout(&s)
    println(s)
    return 0
}
