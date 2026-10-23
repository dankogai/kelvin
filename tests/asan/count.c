/* count.c - a counting allocator for tests/asan.sh (#175): the runtime,
   the modules and a test program are compiled with malloc, realloc and
   free renamed to these, so that every block the program takes is counted,
   and what is still live when it exits is reported; a program that frees
   everything, as Kelvin's ownership promises, reports 0. realpath is
   renamed too: its block, which the runtime frees, is counted as one
   malloc gives (#216). calloc is renamed too, which runtime/os.k gives
   its Strings to the caller in (#304). The counts are atomic, as a Task's
   thread allocates beside the program's (#312) */
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#elif !defined(__FreeBSD__) && !defined(__NetBSD__) && !defined(__OpenBSD__) && !defined(__DragonFly__)
#define _XOPEN_SOURCE 700 /* realpath, X/Open's */
#endif
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>

static atomic_long kv_cnt_allocations, kv_cnt_live;

static void kv_cnt_report(void) {
    fflush(stdout);
    fprintf(stderr, "allocations %ld, live at exit %ld\n", atomic_load(&kv_cnt_allocations), atomic_load(&kv_cnt_live));
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

void *kv_cnt_calloc(size_t n, size_t size) {
    kv_cnt_start();
    void *p = calloc(n, size);
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

/* realpath(path, NULL) mallocs the name it gives, out of the count's
   sight, which the caller frees through kv_cnt_free (#216) */
char *kv_cnt_realpath(const char *path, char *resolved) {
    kv_cnt_start();
    char *r = realpath(path, resolved);
    if (r && !resolved) {
        kv_cnt_allocations++;
        kv_cnt_live++;
    }
    return r;
}

#if defined(__APPLE__)
/* macOS's stdlib.h links realpath as realpath$DARWIN_EXTSN, so the
   renamed declaration asks for kv_cnt_realpath by that name too */
char *kv_cnt_realpath_darwin(const char *path, char *resolved) __asm("_kv_cnt_realpath$DARWIN_EXTSN");
char *kv_cnt_realpath_darwin(const char *path, char *resolved) { return kv_cnt_realpath(path, resolved); }
#endif

void kv_cnt_free(void *p) {
    kv_cnt_start();
    if (p)
        kv_cnt_live--;
    free(p);
}
