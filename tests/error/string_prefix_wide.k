// a string prefix is C's (#295): a Kelvin source is UTF-8, and a
// literal's one prefix is $, a String's
let main():int32 {
    println(L"wide")
    return 0
}
// error: L"..." is C's prefixed literal: a Kelvin source is UTF-8, and a literal's one prefix is $, a String's, $"..." (#295)
