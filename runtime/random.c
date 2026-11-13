/* runtime/random.c - the system's random bits (#547), which runtime/random.k,
   T.random() of the number types and of bool, draws from: arc4random_buf
   on macOS and the BSDs, and getrandom on Linux. Neither has a seed, and
   neither fails once the system is up. */
#include "kelvin_prelude.h"

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__DragonFly__)
void arc4random_buf(void *buf, size_t n); /* stdlib.h's, which -std=c11 hides */

void kv_random_fill(void *buf, size_t n) { arc4random_buf(buf, n); }
#else
#include <errno.h>
#include <sys/types.h>
#include <sys/random.h>

void kv_random_fill(void *buf, size_t n) {
    unsigned char *p = buf;
    while (n) {
        ssize_t got = getrandom(p, n, 0);
        if (got < 0) {
            if (errno == EINTR)
                continue;
            kv_array_fail("the system gave no random bits");
        }
        p += got;
        n -= (size_t)got;
    }
}
#endif
