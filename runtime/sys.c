/* sys.c - SYS (#94): the program itself, its arguments, its platform
   and its exit, the prelude's (#302), in libkelvin: no import, where it
   came with OS, a module (#145). main gives kv_sys_init its arguments
   where the program names SYS or imports OS. */
#include "kelvin_prelude.h"

#include <stdio.h>
#include <stdlib.h>

static int sys_argc;
static char **sys_argv;

void kv_sys_init(int argc, char **argv) {
    sys_argc = argc;
    sys_argv = argv;
}

int kv_sys_argc_n(void) { return sys_argc; }
char **kv_sys_argv_p(void) { return sys_argv; }

const uint8_t *kv_sys_platform(void) {
#if defined(__APPLE__)
    return (const uint8_t *)"macos";
#elif defined(__linux__)
    return (const uint8_t *)"linux";
#elif defined(__FreeBSD__)
    return (const uint8_t *)"freebsd";
#elif defined(__OpenBSD__)
    return (const uint8_t *)"openbsd";
#elif defined(__NetBSD__)
    return (const uint8_t *)"netbsd";
#elif defined(_WIN32)
    return (const uint8_t *)"windows";
#else
    return (const uint8_t *)"unknown";
#endif
}

void kv_sys_exit(int code) {
    fflush(NULL);
    exit(code);
}

