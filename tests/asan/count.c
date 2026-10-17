/* count.c - a counting allocator for tests/asan.sh (#175): the runtime,
   the modules and a test program are compiled with malloc, realloc and
   free renamed to these, so that every block the program takes is counted,
   and what is still live when it exits is reported; a program that frees
   everything, as Kelvin's ownership promises, reports 0 */
#include <stdio.h>
#include <stdlib.h>

static long kv_cnt_allocations, kv_cnt_live;

static void kv_cnt_report(void) {
    fflush(stdout);
    fprintf(stderr, "allocations %ld, live at exit %ld\n", kv_cnt_allocations, kv_cnt_live);
}

/* registered before main runs, so that the report runs after every handler
   the program registers, the one that frees its globals (#178) among them */
static void __attribute__((constructor)) kv_cnt_init(void) { atexit(kv_cnt_report); }

static void kv_cnt_start(void) {}

void *kv_cnt_malloc(size_t n) {
    kv_cnt_start();
    void *p = malloc(n);
    if (p) {
        kv_cnt_allocations++;
        kv_cnt_live++;
    }
    return p;
}

void *kv_cnt_realloc(void *p, size_t n) {
    kv_cnt_start();
    void *q = realloc(p, n);
    if (q && !p) {
        kv_cnt_allocations++;
        kv_cnt_live++;
    }
    return q;
}

void kv_cnt_free(void *p) {
    kv_cnt_start();
    if (p)
        kv_cnt_live--;
    free(p);
}
