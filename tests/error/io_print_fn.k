// f.print cannot show a function (#83)
#import <IO>
let twice(n:int64):i64 { return n * 2 }
let main():i32 {
    IO.stdout.println(twice)
    return 0
}
// error: '.println' cannot show a function: a function has no text
