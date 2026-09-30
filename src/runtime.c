/* runtime.c - the Kelvin runtime, embedded as C source.

   It is compiled as its own translation unit so that its libc headers can
   never clash with the prototypes a Kelvin program declares via `extern fn`. */
#include "kelvin.h"

const char kelvin_runtime_c[] =
    "#include <stdint.h>\n"
    "#include <stdio.h>\n"
    "#include <stdlib.h>\n"
    "\n"
    "_Noreturn void kv_trap(const char *loc, const char *msg)\n"
    "{\n"
    "    fflush(stdout);\n"
    "    fprintf(stderr, \"%s: kelvin trap: %s\\n\", loc, msg);\n"
    "    if (getenv(\"KELVIN_ABORT\"))\n"
    "        abort();\n"
    "    _Exit(134);\n"
    "}\n"
    "\n"
    "_Noreturn void kv_trap_index(const char *loc, int64_t i, uint64_t n)\n"
    "{\n"
    "    char msg[96];\n"
    "    if (i < 0)\n"
    "        snprintf(msg, sizeof msg, \"index %lld out of bounds for length %llu\", (long long)i, (unsigned long long)n);\n"
    "    else\n"
    "        snprintf(msg, sizeof msg, \"index %llu out of bounds for length %llu\", (unsigned long long)i, (unsigned long long)n);\n"
    "    kv_trap(loc, msg);\n"
    "}\n";
