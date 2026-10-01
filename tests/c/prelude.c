/* libkelvin used from C: linked statically and dynamically by tests/run.sh */
#include <kelvin_prelude.h>

int main(void)
{
    long long n = -42;
    /* in C, true is the int 1, so cast it to print true */
    println("from C: ", n, " ", 2.5, " ", (unsigned char)200, " ", (bool)true, " ", true);
    println();
    return 0;
}
// out: from C: -42 2.5 200 true 1
// out: 
