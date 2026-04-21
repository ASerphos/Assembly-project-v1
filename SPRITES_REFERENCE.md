# Sprite & Character Reference

All sprites are defined in `src/sprites.asm` using palette indices.
Each pixel is one byte; index 0 = transparent.
Sprites are drawn at **logical resolution** and scaled **2x** on screen.

---

## Color Palette

| Index | Symbol | Color           | Hex (BGRA)  | Used for             |
|-------|--------|-----------------|-------------|----------------------|
| 0     | ` `    | Transparent     | —           | Background           |
| 1     | `#`    | Off-white       | `#D0D0E0`   | Knight body          |
| 2     | `^`    | Light gray      | `#E8E8E8`   | Knight horns         |
| 3     | `*`    | Dark navy       | `#1A1A2E`   | Knight eyes / feet   |
| 4     | `~`    | Gray            | `#8888A0`   | Knight cloak         |
| 5     | `@`    | Dark red-brown  | `#6A3A2A`   | Enemy body           |
| 6     | `O`    | Orange-brown    | `#8B4513`   | Enemy shell          |
| 7     | `o`    | Orange          | `#FF6600`   | Enemy eyes           |
| 8     | `/`    | White           | `#FFFFFF`   | Sword slash          |
| 9     | `M`    | White           | `#E0E0E0`   | HP mask (full)       |
| 10    | `.`    | Dark gray       | `#333344`   | HP mask (empty)      |
| 11    |        | Stone gray      | `#3A3A4A`   | Ground tile          |
| 12    |        | Gray highlight  | `#4E4E66`   | Ground edge          |
| 13    |        | Dark slate      | `#2D2D44`   | Platform tile        |
| 14    |        | Slate highlight | `#3D3D5C`   | Platform edge        |
| 15    |        | Dark blue       | `#1A1A2E`   | Background pillar    |

---

## 1. The Knight (Player) — 16 x 24 px

### Idle (`knight_idle`)
State: standing still, symmetrical pose, cloak hangs down.

```
   ^        ^      row 0
   ^        ^      row 1
   ^^      ^^      row 2
  ^^^      ^^^     row 3
  ^^######^^       row 4
 ^^############^^      row 5
 ^##**####**##^    row 6  (eyes)
 ^##**####**##^    row 7  (eyes)
 ^############^    row 8
  ############     row 9
   ##########      row 10
    ########       row 11
   ~~~~##~~~~      row 12 (cloak starts)
  ~~~~~##~~~~~     row 13
 ~~~~~~##~~~~~~    row 14
 ~~~~~~~~~~~~~~    row 15
 ~~~~~~~~~~~~~~    row 16
  ~~~~~~~~~~~~     row 17
   ~~~~  ~~~~      row 18
   ~~~    ~~~      row 19
   ###    ###      row 20 (legs)
   ##      ##      row 21
  ***      ***     row 22 (feet)
  **        **     row 23
```

### Run Frame 1 (`knight_run1`)
State: slight forward lean, left leg stepping forward, right leg back.

```
    ^        ^     row 0
    ^        ^     row 1
    ^^      ^^     row 2
   ^^^      ^^^    row 3
   ^^######^^      row 4
  ^^############^^ row 5
  ^##**####**##^   row 6
  ^##**####**##^   row 7
  ^############^   row 8
   #############   row 9
    ###########    row 10
     ########      row 11
    ~~~~##~~~~     row 12
   ~~~~~##~~~~~    row 13
  ~~~~~~##~~~~~~   row 14
  ~~~~~~~~~~~~~~   row 15
   ~~~~~~~~~~~~~   row 16
    ~~~~~~~~~~~~   row 17
    ~~~~  ~~~~     row 18
   ###    ~~~      row 19  (left leg forward)
  ###     ###      row 20
 ###      ##       row 21
***       ***      row 22
**         **      row 23
```

### Run Frame 2 (`knight_run2`)
State: mirror leg pose — right leg forward, left leg back.

```
   ^        ^      row 0
   ^        ^      row 1
   ^^      ^^      row 2
  ^^^      ^^^     row 3
  ^^######^^       row 4
 ^^############^^  row 5
 ^##**####**##^    row 6
 ^##**####**##^    row 7
 ^############^    row 8
  ############     row 9
   ##########      row 10
    ########       row 11
   ~~~~##~~~~      row 12
  ~~~~~##~~~~~     row 13
 ~~~~~~##~~~~~~    row 14
 ~~~~~~~~~~~~~~    row 15
 ~~~~~~~~~~~~~~    row 16
  ~~~~~~~~~~~~     row 17
  ~~~~    ~~~      row 18
   ~~~     ~~~~    row 19  (legs swapped)
   ###      ###    row 20
  ###       ###    row 21
 ***         ***   row 22
 **           **   row 23
```

### Jump (`knight_jump`)
State: body tucked upward, legs pulled in, cloak billows.

```
   ^        ^      row 0
   ^        ^      row 1
   ^^      ^^      row 2
  ^^^      ^^^     row 3
  ^^######^^       row 4
 ^^############^^  row 5
 ^##**####**##^    row 6
 ^##**####**##^    row 7
 ^############^    row 8
  ############     row 9
  ~~~######~~~     row 10 (cloak tighter)
 ~~~~~~##~~~~~~    row 11
 ~~~~~~~~~~~~~~    row 12
 ~~~~~~~~~~~~~~    row 13
 ~~~~~~~~~~~~~~    row 14
  ~~~~~~~~~~~~     row 15
   ~~~~~~~~~~      row 16
    ~~~~~~~~       row 17
   ###    ###      row 18 (legs tucked)
  ###      ###     row 19
  **        **     row 20
  **        **     row 21
                   row 22 (empty)
                   row 23 (empty)
```

### Fall (`knight_fall`)
State: body extended downward, cloak spreads wide.

```
   ^        ^      row 0
   ^        ^      row 1
   ^^      ^^      row 2
  ^^^      ^^^     row 3
  ^^######^^       row 4
 ^^############^^  row 5
 ^##**####**##^    row 6
 ^##**####**##^    row 7
 ^############^    row 8
  ############     row 9
   ##########      row 10
    ########       row 11
   ~~~~##~~~~      row 12
  ~~~~~##~~~~~     row 13
 ~~~~~~##~~~~~~    row 14
~~~~~~~~~~~~~~~~   row 15 (cloak full width!)
~~~~~~~~~~~~~~~~   row 16
 ~~~~~~~~~~~~~~    row 17
  ~~~~~~~~~~~~     row 18
   ~~~~  ~~~~      row 19
   ###    ###      row 20
  ###      ###     row 21
 ***        ***    row 22
 **          **    row 23
```

### Attack (`knight_attack`)
State: leaning forward, arm extended right. Slash drawn separately.

```
   ^        ^      row 0
   ^        ^      row 1
   ^^      ^^      row 2
  ^^^      ^^^     row 3
  ^^######^^       row 4
 ^^############^^  row 5
 ^##**####**##^    row 6
 ^##**####**##^    row 7
 ^############^    row 8
  ##############   row 9  (arm extends right)
   #############   row 10 (arm extends right)
    ##########     row 11
   ~~~~##~~~~      row 12
  ~~~~~##~~~~~     row 13
 ~~~~~~##~~~~~~    row 14
 ~~~~~~~~~~~~~~    row 15
 ~~~~~~~~~~~~~~    row 16
  ~~~~~~~~~~~~     row 17
   ~~~~  ~~~~      row 18
   ~~~    ~~~      row 19
   ###    ###      row 20
  ###      ###     row 21
 ***        ***    row 22
 **          **    row 23
```

### Dash (`knight_dash`)
State: horizontal streaky pose, cloak trails behind, body compact.

```
   ^        ^      row 0
   ^        ^      row 1
   ^^      ^^      row 2
  ^^^      ^^^     row 3
  ^^######^^       row 4
 ^^############^^  row 5
 ^##**####**##^    row 6
 ^##**####**##^    row 7
 ^############^    row 8
  ############     row 9
~~~~~~######~~~~~~ row 10 (cloak streams out!)
~~~~~~~##~~~~~~~~~  row 11
~~~~~~~~~~~~~~~~   row 12
~~~~~~~~~~~~~~~~   row 13
 ~~~~~~~~~~~~~~    row 14
  ~~~~~~~~~~~~     row 15
   ~~~~~~~~~~      row 16
    ~~~~~~~~       row 17
    ~~~  ~~~       row 18
   ###    ###      row 19
  ###      ###     row 20
 ***        ***    row 21
                   row 22 (empty)
                   row 23 (empty)
```

---

## 2. Crawlid Enemy — 16 x 12 px

### Walk Frame 0 (`enemy_sprite0`)
Legs spread wide, stationary pose.

```
    OOOOOOOO       row 0  (shell top)
  OOOOOOOOOOOO     row 1
 OOOOOOOOOOOOOO    row 2
 OOOO@@@@@@OOOO    row 3  (body under shell)
 OO@@@@@@@@@@OO    row 4
 @@@o@@@@@@@@o@@   row 5  (eyes)
 @@@o@@@@@@@@o@@   row 6  (eyes)
@@@@@@@@@@@@@@@@   row 7  (full body)
@@@@@@@@@@@@@@@@   row 8
 @ @@@@  @@@@ @    row 9  (legs — spread)
 @ @      @ @      row 10
@            @     row 11
```

### Walk Frame 1 (`enemy_sprite1`)
Legs shifted inward, walking motion.

```
    OOOOOOOO       row 0  (shell top)
  OOOOOOOOOOOO     row 1
 OOOOOOOOOOOOOO    row 2
 OOOO@@@@@@OOOO    row 3
 OO@@@@@@@@@@OO    row 4
 @@@o@@@@@@@@o@@   row 5  (eyes)
 @@@o@@@@@@@@o@@   row 6  (eyes)
@@@@@@@@@@@@@@@@   row 7
@@@@@@@@@@@@@@@@   row 8
  @@  @ @  @@      row 9  (legs — shifted)
@ @        @ @     row 10
@            @     row 11
```

---

## 3. Slash Effect — 20 x 16 px

Curved arc, drawn in front of the knight during attack.
Rendered on the **right** side when facing right; mirrored when facing left.

```
                       row 0
                       row 1
              ///      row 2
             /////     row 3
            ///////    row 4
           ////  ////  row 5
          ///      /// row 6
         ///        // row 7
        ///         // row 8
       ///         //  row 9
      ///         ///  row 10
     ///         ///   row 11
    ///         ///    row 12
   ///       ///       row 13
   //       //         row 14
                       row 15
```

---

## 4. HP Masks (HUD) — 10 x 10 px

### Full Mask (`hp_mask_full`)
Bright white oval with dark eye holes. Represents 1 HP.

```
  MMMMMM       row 0
 MMMMMMMM      row 1
MM*MMMM*MM     row 2  (eye holes)
MM*MMMM*MM     row 3  (eye holes)
MMMMMMMMMM     row 4
MMMMMMMMMM     row 5
MMMMMMMMMM     row 6
 MMMMMMMM      row 7
  MMMMMM       row 8
   MMMM        row 9
```

### Empty Mask (`hp_mask_empty`)
Dark silhouette, same shape. Represents lost HP.

```
  ......       row 0
 ........      row 1
..........     row 2
..........     row 3
..........     row 4
..........     row 5
..........     row 6
 ........      row 7
  ......       row 8
   ....        row 9
```

---

## 5. Background Pillar — 24 x 120 px

Simple tall column silhouette (palette index 15, dark blue).
Repeats the same row 120 times:

```
 ||||||||||||||||||||||
 ||||||||||||||||||||||   (x120 rows)
 ||||||||||||||||||||||
```

---

## Summary Table

| Sprite           | Size (px) | Frames | File location              |
|------------------|-----------|--------|----------------------------|
| Knight idle      | 16 x 24   | 1      | `sprites.asm:54`           |
| Knight run       | 16 x 24   | 2      | `sprites.asm:90, 117`      |
| Knight jump      | 16 x 24   | 1      | `sprites.asm:144`          |
| Knight fall      | 16 x 24   | 1      | `sprites.asm:171`          |
| Knight attack    | 16 x 24   | 1      | `sprites.asm:198`          |
| Knight dash      | 16 x 24   | 1      | `sprites.asm:225`          |
| Crawlid enemy    | 16 x 12   | 2      | `sprites.asm:254, 269`     |
| Slash effect     | 20 x 16   | 1      | `sprites.asm:287`          |
| HP mask (full)   | 10 x 10   | 1      | `sprites.asm:308`          |
| HP mask (empty)  | 10 x 10   | 1      | `sprites.asm:320`          |
| Background pillar| 24 x 120  | 1      | `sprites.asm:336`          |

**Total animation frames**: 7 (knight) + 2 (enemy) + 1 (slash) + 2 (HUD) + 1 (BG) = **13 sprites**

---

## How Sprites Work in the Code

1. Each sprite is a flat byte array — **row-major**, left-to-right, top-to-bottom
2. Each byte is a **palette index** (0–15)
3. The blitter in `render.asm` looks up each index in the `palette` table to get a 32-bit BGRA color
4. Index 0 is skipped (transparent) — the background shows through
5. Sprites can be **horizontally flipped** for left-facing direction (the blitter reads columns in reverse)
6. Everything is drawn at logical resolution (320x240) and scaled 2x to the 640x480 window

## Notes for Redesigning

If you want to send new sprite designs:
- Keep the same grid sizes (16x24 for knight, 16x12 for enemy, etc.) or tell me the new sizes
- Use the same palette index scheme, or describe new colors you want added
- Each frame is a flat grid of numbers — you can sketch on graph paper or in a pixel art tool and I'll convert it
- If you change sprite dimensions, I'll also update the hitbox constants in `constants.inc`
