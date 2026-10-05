// C functions declared by hand in an imported Kelvin file keep their C
// names (#40, #41)
#import "lib/binding.k"

main():i32 {
    puts("hello")
    println(abs(-3))
    return 0
}
// out: hello
// out: 3
// c: int32_t puts(const uint8_t *s);
// c: int32_t abs(int32_t n);
