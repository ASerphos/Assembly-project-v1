; ============================================================================
; Hollow Knight Assembly Demo — Rendering
; Framebuffer ops, sprite blitting with 2x scaling, level/HUD draw
; ============================================================================

%include "constants.inc"

; Externals
extern framebuffer
extern level_map
extern palette
extern knight_idle, knight_run1, knight_run2, knight_jump, knight_fall
extern knight_attack, knight_dash
extern enemy_sprite0, enemy_sprite1
extern slash_sprite
extern hp_mask_full, hp_mask_empty
extern bg_pillar

extern player_x, player_y, player_facing, player_state
extern player_anim_frame, player_invuln_timer
extern player_hp, player_slash_active, player_slash_x, player_slash_y
extern player_dash_timer
extern enemies, num_enemies
extern frame_count

global render_frame
global clear_screen
global draw_rect
global blit_sprite

section .text

; ============================================================================
; clear_screen(color) — fill entire framebuffer with given BGRA color
; Args: edi = color (BGRA dword)
; ============================================================================
clear_screen:
    push rdi                ; preserve color (caller didn't save it)
    mov rdi, [rel framebuffer]
    mov ecx, WINDOW_W * WINDOW_H
    mov eax, [rsp]          ; color back
    rep stosd
    add rsp, 8
    ret

; ============================================================================
; draw_rect(x, y, w, h, color)  — screen-pixel coordinates
; Args: edi=x, esi=y, edx=w, ecx=h, r8d=color
; ============================================================================
draw_rect:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Clip to window
    ; Compute x2 = x + w, y2 = y + h
    mov r9d, edi
    add r9d, edx        ; r9d = x2
    mov r10d, esi
    add r10d, ecx       ; r10d = y2

    ; Clip x
    test edi, edi
    jns .cx_ok
    xor edi, edi
.cx_ok:
    cmp r9d, WINDOW_W
    jle .cx2_ok
    mov r9d, WINDOW_W
.cx2_ok:
    ; Clip y
    test esi, esi
    jns .cy_ok
    xor esi, esi
.cy_ok:
    cmp r10d, WINDOW_H
    jle .cy2_ok
    mov r10d, WINDOW_H
.cy2_ok:
    ; If x >= x2 or y >= y2, nothing to draw
    cmp edi, r9d
    jge .done
    cmp esi, r10d
    jge .done

    mov r11, [rel framebuffer]
    mov r12d, edi           ; x1
    mov r13d, r9d           ; x2
    mov r14d, esi           ; y
    mov r15d, r10d          ; y2
    mov ebx, r8d            ; color

.row:
    ; base = fb + (y * WINDOW_W + x1) * 4
    mov eax, r14d
    imul eax, WINDOW_W
    add eax, r12d
    lea rax, [r11 + rax*4]

    ; count = x2 - x1
    mov ecx, r13d
    sub ecx, r12d

    mov rdi, rax
    mov eax, ebx
    rep stosd

    inc r14d
    cmp r14d, r15d
    jl .row

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; ============================================================================
; blit_sprite(sprite_ptr, x, y, w, h, flip_h) — draws at logical coords,
; scaled 2x to screen pixels. palette[0] is transparent.
; Args:  rdi=sprite_ptr, esi=logical_x, edx=logical_y, ecx=w, r8d=h, r9d=flip_h
; ============================================================================
blit_sprite:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24             ; locals

    mov [rbp-40], rdi       ; sprite_ptr
    mov [rbp-44], esi       ; logical_x
    mov [rbp-48], edx       ; logical_y
    mov [rbp-52], ecx       ; w
    mov [rbp-56], r8d       ; h
    mov [rbp-60], r9d       ; flip

    xor r12d, r12d          ; row = 0
.row_loop:
    cmp r12d, [rbp-56]      ; row < h ?
    jge .blit_done

    xor r13d, r13d          ; col = 0
.col_loop:
    cmp r13d, [rbp-52]      ; col < w ?
    jge .next_row

    ; idx = sprite[row * w + col]
    mov eax, r12d
    imul eax, [rbp-52]
    add eax, r13d
    mov rcx, [rbp-40]
    movzx eax, byte [rcx + rax]

    test eax, eax
    jz .skip_pixel

    ; color = palette[idx]
    lea rcx, [rel palette]
    mov r14d, [rcx + rax*4]  ; color

    ; Compute effective col (flip if needed)
    mov eax, r13d
    cmp dword [rbp-60], 0
    je .noflip
    mov eax, [rbp-52]
    dec eax
    sub eax, r13d
.noflip:
    mov ebx, eax            ; effective col

    ; screen_x = (logical_x + col_eff) * PIXEL_SCALE
    mov eax, [rbp-44]
    add eax, ebx
    imul eax, PIXEL_SCALE
    mov r15d, eax           ; screen_x

    ; screen_y = (logical_y + row) * PIXEL_SCALE
    mov eax, [rbp-48]
    add eax, r12d
    imul eax, PIXEL_SCALE   ; screen_y in eax

    ; Bounds check
    cmp eax, 0
    jl .skip_pixel
    cmp eax, WINDOW_H - 1
    jg .skip_pixel
    cmp r15d, 0
    jl .skip_pixel
    cmp r15d, WINDOW_W - 1
    jg .skip_pixel

    ; Write 2x2 block
    ; offset = (y * WINDOW_W + x) * 4
    mov ecx, eax
    imul ecx, WINDOW_W
    add ecx, r15d
    mov rdi, [rel framebuffer]
    mov [rdi + rcx*4], r14d         ; pixel (x, y)
    mov [rdi + rcx*4 + 4], r14d     ; pixel (x+1, y)
    ; Next row
    add ecx, WINDOW_W
    mov [rdi + rcx*4], r14d         ; pixel (x, y+1)
    mov [rdi + rcx*4 + 4], r14d     ; pixel (x+1, y+1)

.skip_pixel:
    inc r13d
    jmp .col_loop
.next_row:
    inc r12d
    jmp .row_loop
.blit_done:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret


; ============================================================================
; draw_background — gradient + distant pillars
; ============================================================================
draw_background:
    push rbp
    mov rbp, rsp
    push rbx

    ; Fill top half with dark color, bottom with slightly lighter (gradient effect)
    ; We'll do 4 horizontal bands
    xor edi, edi
    xor esi, esi
    mov edx, WINDOW_W
    mov ecx, 120
    mov r8d, COLOR_BG_DARK
    call draw_rect

    xor edi, edi
    mov esi, 120
    mov edx, WINDOW_W
    mov ecx, 120
    mov r8d, COLOR_BG_MID
    call draw_rect

    xor edi, edi
    mov esi, 240
    mov edx, WINDOW_W
    mov ecx, 120
    mov r8d, 0xFF181830
    call draw_rect

    xor edi, edi
    mov esi, 360
    mov edx, WINDOW_W
    mov ecx, 120
    mov r8d, COLOR_BG_HORIZON
    call draw_rect

    ; Draw distant pillar silhouettes (fill rectangles in darker hue)
    ; Pillar 1
    mov edi, 80
    mov esi, 80
    mov edx, 30
    mov ecx, 320
    mov r8d, 0xFF1A1A30
    call draw_rect

    ; Pillar 2
    mov edi, 300
    mov esi, 60
    mov edx, 34
    mov ecx, 340
    mov r8d, 0xFF15152A
    call draw_rect

    ; Pillar 3
    mov edi, 520
    mov esi, 90
    mov edx, 30
    mov ecx, 310
    mov r8d, 0xFF1A1A30
    call draw_rect

    pop rbx
    pop rbp
    ret


; ============================================================================
; draw_level — iterate tilemap, render each solid/platform tile
; ============================================================================
draw_level:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14

    xor r12d, r12d              ; row
.row_loop:
    cmp r12d, MAP_ROWS
    jge .done

    xor r13d, r13d              ; col
.col_loop:
    cmp r13d, MAP_COLS
    jge .next_row

    ; tile = level_map[row * MAP_COLS + col]
    mov eax, r12d
    imul eax, MAP_COLS
    add eax, r13d
    lea rcx, [rel level_map]
    movzx eax, byte [rcx + rax]

    test eax, eax
    jz .skip_tile

    ; Compute screen x, y
    mov edi, r13d
    imul edi, TILE_DRAW_SIZE
    mov esi, r12d
    imul esi, TILE_DRAW_SIZE
    mov edx, TILE_DRAW_SIZE
    mov ecx, TILE_DRAW_SIZE

    cmp al, TILE_SOLID
    je .draw_solid
    cmp al, TILE_PLATFORM
    je .draw_platform
    jmp .skip_tile

.draw_solid:
    mov r8d, COLOR_TILE_GROUND
    call draw_rect
    ; highlight top row of tile (2 screen pixels)
    mov edi, r13d
    imul edi, TILE_DRAW_SIZE
    mov esi, r12d
    imul esi, TILE_DRAW_SIZE
    mov edx, TILE_DRAW_SIZE
    mov ecx, 2
    mov r8d, COLOR_TILE_HILITE
    call draw_rect
    jmp .skip_tile

.draw_platform:
    mov r8d, COLOR_TILE_PLATFORM
    call draw_rect
    ; highlight top row
    mov edi, r13d
    imul edi, TILE_DRAW_SIZE
    mov esi, r12d
    imul esi, TILE_DRAW_SIZE
    mov edx, TILE_DRAW_SIZE
    mov ecx, 2
    mov r8d, COLOR_TILE_PLAT_HI
    call draw_rect

.skip_tile:
    inc r13d
    jmp .col_loop
.next_row:
    inc r12d
    jmp .row_loop
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret


; ============================================================================
; draw_enemies
; ============================================================================
draw_enemies:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    lea rbx, [rel enemies]
    xor r12d, r12d
.loop:
    cmp r12d, [rel num_enemies]
    jge .done
    cmp dword [rbx + ENM_ALIVE], 0
    je .next

    ; Choose frame based on animation counter
    mov eax, [rbx + ENM_ANIM]
    shr eax, 3                  ; change frame every 8 ticks
    and eax, 1
    test eax, eax
    lea rdi, [rel enemy_sprite0]
    jz .have_sprite
    lea rdi, [rel enemy_sprite1]
.have_sprite:

    ; Flash white when hit — override with white-ish rendering
    cmp dword [rbx + ENM_HIT_TIMER], 0
    je .normal
    ; Draw a white rectangle for hit flash
    mov edi, [rbx + ENM_X]
    sar edi, FIXED_SHIFT
    imul edi, PIXEL_SCALE
    mov esi, [rbx + ENM_Y]
    sar esi, FIXED_SHIFT
    imul esi, PIXEL_SCALE
    mov edx, ENEMY_W * PIXEL_SCALE
    mov ecx, ENEMY_H * PIXEL_SCALE
    mov r8d, 0xFFFFFFFF
    call draw_rect
    jmp .next

.normal:
    ; logical x, y
    mov esi, [rbx + ENM_X]
    sar esi, FIXED_SHIFT
    mov edx, [rbx + ENM_Y]
    sar edx, FIXED_SHIFT
    mov ecx, ENEMY_W
    mov r8d, ENEMY_H
    mov r9d, [rbx + ENM_DIR]    ; flip if facing left
    call blit_sprite

.next:
    add rbx, ENEMY_STRUCT_SIZE
    inc r12d
    jmp .loop
.done:
    pop r12
    pop rbx
    pop rbp
    ret


; ============================================================================
; draw_player — choose sprite by state, apply facing flip, handle invuln blink
; ============================================================================
draw_player:
    push rbp
    mov rbp, rsp
    push rbx

    ; Invuln blink: skip drawing on alternating frames
    mov eax, [rel player_invuln_timer]
    test eax, eax
    jz .do_draw
    mov ecx, eax
    and ecx, 4              ; blink every 4 frames
    jnz .do_draw
    jmp .done

.do_draw:
    ; Determine sprite based on state
    mov eax, [rel player_state]

    cmp eax, STATE_ATTACK
    je .use_attack
    cmp eax, STATE_DASH
    je .use_dash
    cmp eax, STATE_JUMP
    je .use_jump
    cmp eax, STATE_FALL
    je .use_fall
    cmp eax, STATE_RUN
    je .use_run
    ; else idle
    lea rdi, [rel knight_idle]
    jmp .have

.use_run:
    cmp dword [rel player_anim_frame], 0
    jne .use_run2
    lea rdi, [rel knight_run1]
    jmp .have
.use_run2:
    lea rdi, [rel knight_run2]
    jmp .have

.use_jump:
    lea rdi, [rel knight_jump]
    jmp .have

.use_fall:
    lea rdi, [rel knight_fall]
    jmp .have

.use_attack:
    lea rdi, [rel knight_attack]
    jmp .have

.use_dash:
    lea rdi, [rel knight_dash]

.have:
    mov esi, [rel player_x]
    sar esi, FIXED_SHIFT
    mov edx, [rel player_y]
    sar edx, FIXED_SHIFT
    mov ecx, KNIGHT_W
    mov r8d, KNIGHT_H
    mov r9d, [rel player_facing]
    call blit_sprite

.done:
    pop rbx
    pop rbp
    ret


; ============================================================================
; draw_slash — render slash sprite if active
; ============================================================================
draw_slash:
    cmp dword [rel player_slash_active], 0
    je .done
    ; Draw slash at (slash_x - 4, slash_y - 4)
    lea rdi, [rel slash_sprite]
    mov esi, [rel player_slash_x]
    sub esi, 4
    mov edx, [rel player_slash_y]
    sub edx, 4
    mov ecx, 20             ; slash w
    mov r8d, 16             ; slash h
    mov r9d, [rel player_facing]
    call blit_sprite
.done:
    ret


; ============================================================================
; draw_hud — 5 mask icons at top-left
; ============================================================================
draw_hud:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    xor r12d, r12d              ; i = 0
.loop:
    cmp r12d, MAX_HP
    jge .done

    ; If i < player_hp, draw full, else empty
    lea rdi, [rel hp_mask_full]
    cmp r12d, [rel player_hp]
    jl .have
    lea rdi, [rel hp_mask_empty]
.have:
    ; screen x = 4 + i * 12 (logical), y = 4
    mov esi, r12d
    imul esi, 12
    add esi, 4
    mov edx, 4
    mov ecx, 10
    mov r8d, 10
    xor r9d, r9d
    call blit_sprite

    inc r12d
    jmp .loop
.done:
    pop r12
    pop rbx
    pop rbp
    ret


; ============================================================================
; render_frame — main render pipeline, called once per frame
; ============================================================================
render_frame:
    push rbp
    mov rbp, rsp

    ; 1. Clear with deep background
    mov edi, COLOR_BG_DARK
    call clear_screen

    ; 2. Background atmosphere
    call draw_background

    ; 3. Level tiles
    call draw_level

    ; 4. Enemies
    call draw_enemies

    ; 5. Slash (in front of player)
    call draw_slash

    ; 6. Player
    call draw_player

    ; 7. HUD (on top)
    call draw_hud

    pop rbp
    ret
