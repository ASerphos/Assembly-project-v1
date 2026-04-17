; ============================================================================
; Hollow Knight Assembly Demo — Shared Constants & Macros
; ============================================================================

; ---- Window / Display ----
%define WINDOW_W        640
%define WINDOW_H        480
%define LOGICAL_W       320
%define LOGICAL_H       240
%define PIXEL_SCALE     2
%define BPP             4                       ; bytes per pixel (BGRA)
%define FB_STRIDE       (WINDOW_W * BPP)        ; 2560
%define FB_SIZE         (WINDOW_W * WINDOW_H * BPP)

; ---- Tile system ----
%define TILE_SIZE       16          ; logical pixels per tile
%define TILE_DRAW_SIZE  32          ; screen pixels per tile (16 * 2)
%define MAP_COLS        20          ; 320 / 16
%define MAP_ROWS        15          ; 240 / 16
%define MAP_SIZE        (MAP_COLS * MAP_ROWS)

; Tile types
%define TILE_EMPTY      0
%define TILE_SOLID      1
%define TILE_PLATFORM   2

; ---- Color palette (0xAARRGGBB in memory as little-endian BGRA) ----
%define COLOR_BG_DARK       0xFF0F0A1A  ; deep dark navy background
%define COLOR_BG_MID        0xFF1A1A2E  ; mid-tone dark blue
%define COLOR_BG_HORIZON    0xFF222240  ; slightly lighter near bottom
%define COLOR_TILE_GROUND   0xFF3A3A4A  ; stone gray ground
%define COLOR_TILE_HILITE   0xFF4E4E66  ; ground highlight edge
%define COLOR_TILE_PLATFORM 0xFF2D2D44  ; platform dark slate
%define COLOR_TILE_PLAT_HI  0xFF3D3D5C  ; platform highlight
%define COLOR_KNIGHT_BODY   0xFFD0D0E0  ; off-white knight body
%define COLOR_KNIGHT_HORN   0xFFE8E8E8  ; light horns
%define COLOR_KNIGHT_EYES   0xFF1A1A2E  ; dark eye voids
%define COLOR_KNIGHT_CLOAK  0xFF8888A0  ; gray cloak
%define COLOR_ENEMY_BODY    0xFF6A3A2A  ; dark red-brown crawlid
%define COLOR_ENEMY_SHELL   0xFF8B4513  ; orange-brown shell
%define COLOR_ENEMY_EYE     0xFFFF6600  ; orange eye
%define COLOR_SLASH         0xFFFFFFFF  ; white sword slash
%define COLOR_HP_FULL       0xFFE0E0E0  ; mask full (white)
%define COLOR_HP_EMPTY      0xFF333344  ; mask empty (dark)
%define COLOR_DASH_TRAIL    0x80A0A0C0  ; semi-transparent dash ghost

; ---- Physics (fixed-point: 8 bits fractional, multiply by 256) ----
%define GRAVITY         40          ; ~0.16 px/frame
%define JUMP_VELOCITY   -900        ; strong upward impulse
%define MOVE_SPEED      384         ; ~1.5 px/frame
%define MAX_FALL_SPEED  768         ; terminal velocity
%define DASH_SPEED      1536        ; ~6 px/frame
%define DASH_DURATION   10          ; frames
%define DASH_COOLDOWN   30          ; frames between dashes
%define FIXED_SHIFT     8

; ---- Player ----
%define KNIGHT_W        16          ; logical pixels
%define KNIGHT_H        24
%define KNIGHT_HITBOX_W 12          ; slightly smaller for fairness
%define KNIGHT_HITBOX_H 20
%define KNIGHT_HB_OX    2           ; hitbox offset x from sprite origin
%define KNIGHT_HB_OY    4           ; hitbox offset y
%define MAX_HP          5           ; 5 masks
%define INVULN_FRAMES   90          ; 1.5 sec invulnerability after hit

; ---- Slash / Attack ----
%define SLASH_W         20          ; hitbox width
%define SLASH_H         16          ; hitbox height
%define SLASH_DURATION  10          ; frames
%define SLASH_COOLDOWN  16          ; frames between attacks

; ---- Enemy ----
%define ENEMY_W         16
%define ENEMY_H         12
%define ENEMY_HITBOX_W  14
%define ENEMY_HITBOX_H  10
%define ENEMY_HP_MAX    2
%define ENEMY_SPEED     128         ; ~0.5 px/frame
%define MAX_ENEMIES     3
%define ENEMY_STRUCT_SIZE 40        ; bytes per enemy struct

; Enemy struct offsets
%define ENM_X           0           ; dd fixed-point x
%define ENM_Y           4           ; dd fixed-point y
%define ENM_VX          8           ; dd velocity x
%define ENM_HP          12          ; dd hit points
%define ENM_ALIVE       16          ; dd 1=alive 0=dead
%define ENM_DIR         20          ; dd 0=right 1=left
%define ENM_HIT_TIMER   24          ; dd flash frames
%define ENM_PLAT_LEFT   28          ; dd patrol left bound (fixed)
%define ENM_PLAT_RIGHT  32          ; dd patrol right bound (fixed)
%define ENM_ANIM        36          ; dd animation counter

; ---- Player states ----
%define STATE_IDLE      0
%define STATE_RUN       1
%define STATE_JUMP      2
%define STATE_FALL      3
%define STATE_ATTACK    4
%define STATE_DASH      5
%define STATE_DEATH     6

; ---- X11 event types ----
%define X11_KeyPress        2
%define X11_KeyRelease      3
%define X11_ButtonPress     4
%define X11_ButtonRelease   5
%define X11_Expose          12
%define X11_ClientMessage   33

; ---- X11 event masks ----
%define KeyPressMask        (1 << 0)
%define KeyReleaseMask      (1 << 1)
%define ButtonPressMask     (1 << 2)
%define ButtonReleaseMask   (1 << 3)
%define ExposureMask        (1 << 15)
%define StructureNotifyMask (1 << 17)

%define EVENT_MASK (KeyPressMask | KeyReleaseMask | ButtonPressMask | ButtonReleaseMask | ExposureMask | StructureNotifyMask)

; ---- X11 constants ----
%define ZPixmap             2
%define Button1             1       ; left mouse button
%define Button2             2       ; middle mouse button
%define Button3             3       ; right mouse button

; ---- XEvent offsets ----
%define XEVENT_TYPE         0

; XKeyEvent: type(4) serial(8) send_event(4) display(8) window(8) root(8) subwindow(8) time(8) x(4) y(4) x_root(4) y_root(4) state(4) keycode(4)
; Offset of keycode in XKeyEvent = 84
%define XKEY_KEYCODE        84

; XButtonEvent: same layout as XKeyEvent but 'button' at offset 84
%define XBUTTON_BUTTON      84

; ---- Keysyms ----
%define XK_Escape   0xFF1B
%define XK_space    0x0020
%define XK_a        0x0061
%define XK_d        0x0064
%define XK_w        0x0077
%define XK_s        0x0073
%define XK_q        0x0071

; ---- Timing ----
%define CLOCK_MONOTONIC 1
%define FRAME_NS    16666667        ; ~60fps (1/60 second in nanoseconds)
%define BILLION     1000000000

; ---- Sprite palette indices ----
%define PAL_TRANSPARENT 0
%define PAL_BODY        1
%define PAL_HORN        2
%define PAL_EYES        3
%define PAL_CLOAK       4
%define PAL_ENEMY_BODY  5
%define PAL_ENEMY_SHELL 6
%define PAL_ENEMY_EYE   7
%define PAL_WHITE       8
%define PAL_HP_FULL     9
%define PAL_HP_EMPTY    10
%define PAL_GROUND      11
%define PAL_GROUND_HI   12
%define PAL_PLAT        13
%define PAL_PLAT_HI     14
%define PAL_BG_PILLAR   15
%define PAL_COUNT       16
