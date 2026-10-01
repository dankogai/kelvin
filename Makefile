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

ifeq ($(shell uname -s),Darwin)
SHLIB := libkelvin.dylib
SHLIB_FLAGS := -dynamiclib -install_name @rpath/libkelvin.dylib
else
SHLIB := libkelvin.so
SHLIB_FLAGS := -shared -Wl,-soname,libkelvin.so
endif

all: kelvinc libkelvin.a $(SHLIB)

kelvinc: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

build/%.o: src/%.c src/kelvin.h | build
	$(CC) $(CFLAGS) -c -o $@ $<

build/runtime/%.o: runtime/%.c runtime/kelvin_prelude.h | build/runtime
	$(CC) $(RT_CFLAGS) -c -o $@ $<

libkelvin.a: $(RT_OBJS)
	rm -f $@
	ar rcs $@ $(RT_OBJS)

$(SHLIB): $(RT_OBJS)
	$(CC) $(SHLIB_FLAGS) -o $@ $(RT_OBJS) -lm

build build/runtime:
	mkdir -p $@

test: all
	./tests/run.sh

install: all
	install -d $(PREFIX)/bin $(PREFIX)/lib $(PREFIX)/include
	install -m 755 kelvinc $(PREFIX)/bin/kelvinc
	install -m 644 libkelvin.a $(PREFIX)/lib/libkelvin.a
	install -m 755 $(SHLIB) $(PREFIX)/lib/$(SHLIB)
	install -m 644 runtime/kelvin_prelude.h $(PREFIX)/include/kelvin_prelude.h

clean:
	rm -rf build kelvinc libkelvin.a libkelvin.so libkelvin.dylib

.PHONY: all test install clean
