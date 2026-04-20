# Hollow Knight — Assembly Demo

A 2D Metroidvania-style platformer demo inspired by Hollow Knight, written in
**pure x86_64 assembly language** (NASM, Intel syntax) for Linux/X11.

Year-end final project demonstrating mastery of:
- x86_64 register management and calling conventions (System V AMD64 ABI)
- Memory layout (`.data`, `.bss`, `.text`)
- Stack discipline and alignment
- Direct framebuffer pixel manipulation
- X11 window system interaction from assembly
- Game state machines, fixed-point physics, AABB collision detection

## Features

- Playable knight character with idle / run / jump / fall / attack / dash
  animations
- Tile-based level with solid walls, ground, and one-way platforms
- Three patrolling "Crawlid"-style enemies with 2 HP each
- Sword-slash attack with directional hitbox
- Dash ability with invulnerability frames and cooldown (iconic HK mechanic)
- 5-mask health system with HUD display
- Invulnerability flashing after taking damage
- Knockback on hit, death/respawn system
- Dark atmospheric palette and layered background silhouettes
- 60 FPS fixed-timestep game loop

## Controls

Standard PC-gamer hand layout (left hand on WASD, right hand on mouse):

| Action        | Key / Button       |
| ------------- | ------------------ |
| Move left     | `A`                |
| Move right    | `D`                |
| Look up       | `W`                |
| Look down     | `S`                |
| Jump          | `Space`            |
| Attack (nail) | `Left Mouse`       |
| Dash          | `Right Mouse`      |
| Quit          | `Esc` or `Q`       |

## Build & Run

### Linux / Ubuntu

One-shot build + launch (checks dependencies, installs if missing, builds, runs):

```
./run.sh
```

Or manual:

```
sudo apt-get install nasm gcc make libx11-dev
make
./hollow_knight
```

### Windows

The game runs **natively** on Windows using the Win32 API (no WSL needed).
You need **NASM** and **MinGW-w64 GCC** — the easiest way is via
[MSYS2](https://www.msys2.org/):

1. Download and install MSYS2 from https://www.msys2.org/
2. Open the **MSYS2 MinGW64** terminal and run:
   ```
   pacman -S mingw-w64-x86_64-nasm mingw-w64-x86_64-gcc make
   ```
3. Add MSYS2 to your PATH: `C:\msys64\mingw64\bin`
4. Double-click `run.bat` (or run it from `cmd` / PowerShell)

Or build manually from the MSYS2 MinGW64 terminal:

```
make
./hollow_knight.exe
```

### Headless / CI testing

If there is no display available, run under Xvfb:

```
Xvfb :99 -screen 0 640x480x24 &
DISPLAY=:99 ./run.sh
```

## Project Structure

```
Assembly-project-v1/
├── Makefile                # Build system (NASM + GCC linker)
├── README.md               # You are here
├── include/
│   └── constants.inc       # Shared constants, macros, struct offsets
└── src/
    ├── main.asm            # Entry point — Linux/X11 version
    ├── main_win.asm        # Entry point — Windows/Win32 version
    ├── player.asm          # Player physics, state machine, attack/dash
    ├── render.asm          # Framebuffer ops, sprite blitter, HUD
    ├── enemy.asm           # Enemy AI (patrol), combat interactions
    ├── collision.asm       # AABB overlap, tile collision resolution
    ├── level.asm           # Tilemap data and tile lookup
    └── sprites.asm         # All sprite pixel data + color palette
```

Each `.asm` is assembled to `.o` by NASM, then all object files are linked by
GCC against `libX11` and `libc`.

## Technical Details

### Graphics

- 640×480 window, 32-bit BGRA framebuffer
- Logical resolution is 320×240, scaled 2x for pixel-art aesthetic
- Each frame: clear → background → level tiles → enemies → slash → player → HUD
- Framebuffer blitted to window via `XPutImage`

### Physics

- Fixed-point math with 8 bits of fractional precision (shift by 8)
- Gravity applied each frame, terminal velocity clamped
- Variable-height jump (cut upward velocity on key release)
- Collision detection separates X and Y axis sweeps against tile grid
- One-way platforms only collide from above

### Platform Abstraction

The game has two platform backends sharing the same game logic, renderer,
physics, and sprite code:

**Linux (main.asm)** — X11/Xlib using System V AMD64 ABI:
- `XOpenDisplay`, `XCreateSimpleWindow`, `XMapWindow`, `XSelectInput`
- `XCreateImage`, `XPutImage` for software rendering
- `XPending` / `XNextEvent` (non-blocking) for input
- `clock_gettime` + `nanosleep` for frame timing

**Windows (main_win.asm)** — Win32 API using Microsoft x64 ABI:
- `RegisterClassExA`, `CreateWindowExA` for window creation
- `SetDIBitsToDevice` for software rendering (BGRA framebuffer to window)
- `PeekMessageA` / `WndProc` for keyboard + mouse input
- `QueryPerformanceCounter` + `Sleep` for frame timing

## Assembly Concepts Demonstrated

- **Calling conventions**: every X11 / libc call follows System V AMD64 ABI
  (args in `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`; stack args for 7+)
- **Stack alignment**: manual 16-byte alignment discipline before every `call`
- **Callee-saved registers**: `rbx`, `r12`–`r15` preserved across functions
- **Memory addressing**: `[rip + symbol]` for PIC-safe data access
- **Bitwise operations**: pixel packing, sprite palette indexing
- **Fixed-point arithmetic**: `shl`/`sar` by 8 for position/velocity math
- **Control flow**: state machines via `cmp`/`je` jump tables
- **Manual data structures**: enemy structs with explicit offset constants

