CC ?= cc
CFLAGS ?= -std=c11 -O2 -g -Wall -Wextra -Wno-unused-parameter
PREFIX ?= /usr/local

SRCS := $(wildcard src/*.c)
OBJS := $(SRCS:src/%.c=build/%.o)

all: kelvinc

kelvinc: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

build/%.o: src/%.c src/kelvin.h | build
	$(CC) $(CFLAGS) -c -o $@ $<

build:
	mkdir -p build

test: kelvinc
	./tests/run.sh

install: kelvinc
	install -d $(PREFIX)/bin
	install -m 755 kelvinc $(PREFIX)/bin/kelvinc

clean:
	rm -rf build kelvinc

.PHONY: all test install clean
