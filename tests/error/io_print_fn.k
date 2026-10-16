// f.print cannot show a function (#83)
#import <IO>
let twice(n:int64):int64 { return n * 2 }
let main():int32 {
    IO.stdout.println(twice)
    return 0
}
// error: '.println' cannot show a function: a function has no text
