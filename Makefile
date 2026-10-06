CC ?= cc
CFLAGS ?= -std=c11 -O2 -g -Wall -Wextra -Wno-unused-parameter
# The runtime has its own flags: kelvinc may be built with sanitizers or
# -Werror, but every Kelvin program links libkelvin.
RT_CFLAGS ?= -std=c11 -O2 -g -Wall -Wextra -fPIC
PREFIX ?= /usr/local

SRCS := $(wildcard src/*.c)
OBJS := $(SRCS:src/%.c=build/%.o)
RT_SRCS := $(wildcard runtime/*.c)
RT_OBJS := $(RT_SRCS:runtime/%.c=build/runtime/%.o)

# modules/ holds what a Kelvin program uses: the prelude header, libkelvin
# and the Kelvin files of #import <x.k> (#46)
ifeq ($(shell uname -s),Darwin)
SHLIB := libkelvin.dylib
SHLIB_FLAGS := -dynamiclib -install_name @rpath/libkelvin.dylib
else
SHLIB := libkelvin.so
SHLIB_FLAGS := -shared -Wl,-soname,libkelvin.so
endif

all: kelvinc modules/libkelvin.a modules/$(SHLIB)

kelvinc: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

build/%.o: src/%.c src/kelvin.h | build
	$(CC) $(CFLAGS) -c -o $@ $<

build/runtime/%.o: runtime/%.c modules/kelvin_prelude.h | build/runtime
	$(CC) $(RT_CFLAGS) -Imodules -c -o $@ $<

modules/libkelvin.a: $(RT_OBJS)
	rm -f $@
	ar rcs $@ $(RT_OBJS)

modules/$(SHLIB): $(RT_OBJS)
	$(CC) $(SHLIB_FLAGS) -o $@ $(RT_OBJS) -lm

build build/runtime:
	mkdir -p $@

test: all
	./tests/run.sh

install: all
	install -d $(PREFIX)/bin $(PREFIX)/lib/kelvin/modules
	install -m 755 kelvinc $(PREFIX)/bin/kelvinc
	install -m 644 modules/kelvin_prelude.h modules/libkelvin.a modules/*.k $(PREFIX)/lib/kelvin/modules/
	install -m 755 modules/$(SHLIB) $(PREFIX)/lib/kelvin/modules/$(SHLIB)

clean:
	rm -rf build kelvinc modules/libkelvin.a modules/libkelvin.so modules/libkelvin.dylib

.PHONY: all test install clean
