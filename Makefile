# Hollow Knight Assembly Demo - Makefile
# Cross-platform: auto-detects Windows (Win32) vs Linux (X11)

NASM    = nasm
CC      = gcc

SRCDIR  = src
INCDIR  = include
OBJDIR  = obj

# Platform detection
ifeq ($(OS),Windows_NT)
    NFLAGS  = -f win64 -g -I $(INCDIR)/
    LDFLAGS = -lgdi32 -luser32 -lkernel32 -mwindows
    TARGET  = hollow_knight.exe
    MAIN_SRC = $(SRCDIR)/main_win.asm
else
    NFLAGS  = -f elf64 -g -F dwarf -I $(INCDIR)/
    LDFLAGS = -no-pie -Wl,-z,noexecstack -lX11 -lm
    TARGET  = hollow_knight
    MAIN_SRC = $(SRCDIR)/main.asm
endif

SHARED_SRCS = $(SRCDIR)/player.asm $(SRCDIR)/render.asm $(SRCDIR)/enemy.asm \
              $(SRCDIR)/collision.asm $(SRCDIR)/level.asm $(SRCDIR)/sprites.asm
SRCS    = $(MAIN_SRC) $(SHARED_SRCS)
OBJS    = $(patsubst $(SRCDIR)/%.asm,$(OBJDIR)/%.o,$(SRCS))

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(OBJDIR)/%.o: $(SRCDIR)/%.asm $(wildcard $(INCDIR)/*.inc) | $(OBJDIR)
	$(NASM) $(NFLAGS) -o $@ $<

$(OBJDIR):
	mkdir -p $(OBJDIR)

clean:
	rm -rf $(OBJDIR) $(TARGET) $(TARGET).exe

run: $(TARGET)
	./$(TARGET)
