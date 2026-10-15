CC ?= cc
CFLAGS ?= -std=c11 -O2 -g -Wall -Wextra -Wno-unused-parameter
# The runtime has its own flags: kelvinc may be built with sanitizers or
# -Werror, but every Kelvin program links libkelvin.
RT_CFLAGS ?= -std=c11 -O2 -g -Wall -Wextra -fPIC
PREFIX ?= /usr/local

SRCS := $(wildcard src/*.c)
OBJS := $(SRCS:src/%.c=build/%.o)
RT_SRCS := $(filter-out runtime/io.c runtime/os.c, $(wildcard runtime/*.c))
RT_OBJS := $(RT_SRCS:runtime/%.c=build/runtime/%.o)
# IO and OS are modules (#144, #145): #import <IO> and #import <OS> bring in
# modules/IO.kh and OS.kh, whose C headers are kIO.h and kOS.h, and link
# libkIO and libkOS, the .kh + libkM form of a module (#143)
MOD_LIBS := modules/libkIO.a modules/libkOS.a

# modules/ holds what a Kelvin program uses: the prelude header, libkelvin
# and the Kelvin files of #import <x.k> (#46)
ifeq ($(shell uname -s),Darwin)
SO := dylib
SHLIB_FLAGS = -dynamiclib -install_name @rpath/$(notdir $@)
else
SO := so
SHLIB_FLAGS = -shared -Wl,-soname,$(notdir $@)
endif
SHLIB := libkelvin.$(SO)
MOD_SHLIBS := modules/libkIO.$(SO) modules/libkOS.$(SO)

all: kelvinc modules/libkelvin.a modules/$(SHLIB) $(MOD_LIBS) $(MOD_SHLIBS)

kelvinc: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

build/%.o: src/%.c src/kelvin.h | build
	$(CC) $(CFLAGS) -c -o $@ $<

build/runtime/%.o: runtime/%.c modules/kelvin_prelude.h modules/kIO.h modules/kOS.h | build/runtime
	$(CC) $(RT_CFLAGS) -Imodules -c -o $@ $<

modules/libkelvin.a: $(RT_OBJS)
	rm -f $@
	ar rcs $@ $(RT_OBJS)

modules/$(SHLIB): $(RT_OBJS)
	$(CC) $(SHLIB_FLAGS) -o $@ $(RT_OBJS) -lm

modules/libkIO.a: build/runtime/io.o
	rm -f $@
	ar rcs $@ $<

modules/libkOS.a: build/runtime/os.o
	rm -f $@
	ar rcs $@ $<

modules/libkOS.$(SO): build/runtime/os.o modules/$(SHLIB)
	$(CC) $(SHLIB_FLAGS) -o $@ $< -Lmodules -lkelvin

modules/libkIO.$(SO): build/runtime/io.o modules/libkOS.$(SO) modules/$(SHLIB)
	$(CC) $(SHLIB_FLAGS) -o $@ $< -Lmodules -lkOS -lkelvin

build build/runtime:
	mkdir -p $@

test: all
	./tests/run.sh

install: all
	install -d $(PREFIX)/bin $(PREFIX)/lib/kelvin/modules
	install -m 755 kelvinc $(PREFIX)/bin/kelvinc
	install -m 644 modules/kelvin_prelude.h modules/kIO.h modules/kOS.h modules/libkelvin.a $(MOD_LIBS) modules/*.k modules/*.kh $(PREFIX)/lib/kelvin/modules/
	install -m 755 modules/$(SHLIB) $(MOD_SHLIBS) $(PREFIX)/lib/kelvin/modules/

clean:
	rm -rf build kelvinc modules/libkelvin.a modules/libk*.so modules/libk*.dylib modules/libkIO.a modules/libkOS.a

.PHONY: all test install clean
