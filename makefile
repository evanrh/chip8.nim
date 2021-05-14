NIMC = nim

NIMFLAGS = -w:on --nimcache:./nimcache
BINDIR = bin
SDIR = src
BINS = chip8

MAIN = $(SDIR)/main.nim
_SRCS := cpu.nim main.nim rendering.nim keyboard.nim
SRCS := $(patsubst %, $(SDIR)/%, $(_SRCS))

all: $(BINDIR)/$(BINS)

$(BINDIR)/chip8: $(MAIN) $(SRCS)
	$(NIMC) c $(NIMFLAGS) -o:$@ $<

$(BINDIR):
	mkdir -p $@

test: all
	./$(BINDIR)/$(BINS) ./roms/PONG

debug: $(MAIN)
	$(NIMC) c $(NIMFLAGS) --debugger:native -o:$(BINDIR)/recovery $(MAIN)

clean:
	rm -rf $(BINDIR) outputs/
