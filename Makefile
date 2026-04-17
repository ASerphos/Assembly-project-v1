# Hollow Knight Assembly Demo - Makefile
# Assembler: NASM (Intel syntax, ELF64)
# Linker: GCC (links against X11 and libc)

NASM    = nasm
CC      = gcc
NFLAGS  = -f elf64 -g -F dwarf -I include/
LDFLAGS = -no-pie -Wl,-z,noexecstack -lX11 -lm

SRCDIR  = src
INCDIR  = include
OBJDIR  = obj

SRCS    = $(wildcard $(SRCDIR)/*.asm)
OBJS    = $(patsubst $(SRCDIR)/%.asm,$(OBJDIR)/%.o,$(SRCS))
TARGET  = hollow_knight

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(OBJDIR)/%.o: $(SRCDIR)/%.asm $(wildcard $(INCDIR)/*.inc) | $(OBJDIR)
	$(NASM) $(NFLAGS) -o $@ $<

$(OBJDIR):
	mkdir -p $(OBJDIR)

clean:
	rm -rf $(OBJDIR) $(TARGET)

run: $(TARGET)
	./$(TARGET)
