// the rows of [[T]] count alike, as C needs one inner count (#49)
let main():i32 {
    var m:[[i64]] = [[1, 2, 3], [4, 5]]
    return 0
}
// error: every row of an array of arrays has the count of the first, 3, which C needs in the type
