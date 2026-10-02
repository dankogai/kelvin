// FizzBuzz: a range, bool conditions without parentheses, and else if.
main(): i32
{
    for i in 1...15 {
        let fizz = i % 3 == 0;      // a comparison is a bool
        let buzz = i % 5 == 0;
        if fizz && buzz {
            println("FizzBuzz");
        } else if fizz {
            println("Fizz");
        } else if buzz {
            println("Buzz");
        } else {
            println(i);
        }
    }
    return 0;
}
// out: 1
// out: 2
// out: Fizz
// out: 4
// out: Buzz
// out: Fizz
// out: 7
// out: 8
// out: Fizz
// out: Buzz
// out: 11
// out: Fizz
// out: 13
// out: 14
// out: FizzBuzz
