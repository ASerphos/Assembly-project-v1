; ============================================================================
; Hollow Knight Assembly Demo — Collision Detection
; ============================================================================
; - AABB (rect vs rect) intersection test
; - Tile-based collision resolution for player and enemies
; ============================================================================

%include "constants.inc"

extern level_map
extern get_tile

global aabb_overlap
global check_tile_collision_x
global check_tile_collision_y

section .text

; ============================================================================
; aabb_overlap(ax, ay, aw, ah, bx, by, bw, bh) -> rax: 1 if overlap else 0
; Args:  edi=ax, esi=ay, edx=aw, ecx=ah, r8d=bx, r9d=by, [stack+16]=bw, [stack+24]=bh
; (all integer logical pixels)
; ============================================================================
aabb_overlap:
    push rbp
    mov rbp, rsp

    ; Compute ax + aw (right edge of A)
    mov eax, edi
    add eax, edx
    ; If ax + aw <= bx, no overlap
    cmp eax, r8d
    jle .no

    ; Compute bx + bw
    mov eax, r8d
    add eax, dword [rbp+16]
    ; If ax >= bx + bw, no overlap
    cmp edi, eax
    jge .no

    ; Compute ay + ah
    mov eax, esi
    add eax, ecx
    ; If ay + ah <= by, no overlap
    cmp eax, r9d
    jle .no

    ; Compute by + bh
    mov eax, r9d
    add eax, dword [rbp+24]
    ; If ay >= by + bh, no overlap
    cmp esi, eax
    jge .no

    mov eax, 1
    pop rbp
    ret
.no:
    xor eax, eax
    pop rbp
    ret


; ============================================================================
; check_tile_collision_x(x_new, y, w, h) -> rax: adjusted x (integer logical)
; Sweep horizontally: if moving into a solid tile, snap to tile edge.
; Args: edi = proposed x (int), esi = y (int), edx = w, ecx = h
; Returns: eax = resolved x
; Caller provides old x in r8d so we can detect direction.
; Actually: simpler — check 4 corners of new bbox; if any hits solid, find
; the offending column and snap.
; ============================================================================
check_tile_collision_x:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi           ; r12 = new x
    mov r13d, esi           ; r13 = y
    mov r14d, edx           ; r14 = w
    mov ebx, ecx            ; ebx = h

    ; Check left column (col at x) and right column (col at x+w-1)
    ; For each row from y to y+h-1 (step TILE_SIZE), check tile.

    ; Check right edge first if moving right, left edge if moving left.
    ; We don't know old x here, but we can check both sides.

    ; --- Check RIGHT edge ---
    mov eax, r12d
    add eax, r14d
    dec eax
    mov ecx, TILE_SIZE
    cdq
    idiv ecx
    mov r8d, eax            ; r8 = right_col

    ; row top = y / TILE_SIZE
    mov eax, r13d
    cdq
    idiv ecx
    mov r9d, eax            ; r9 = top row

    ; row bot = (y + h - 1) / TILE_SIZE
    mov eax, r13d
    add eax, ebx
    dec eax
    cdq
    idiv ecx
    mov r10d, eax           ; r10 = bottom row

    ; For each row in [r9, r10], check get_tile(right_col, row)
    mov ecx, r9d
.right_loop:
    cmp ecx, r10d
    jg .right_done
    push rcx
    mov edi, r8d
    mov esi, ecx
    call get_tile
    pop rcx
    cmp al, TILE_SOLID
    jne .right_next
    ; Collision on right — snap new x so right edge is at right_col * TILE_SIZE - 1
    mov eax, r8d
    imul eax, TILE_SIZE
    sub eax, r14d
    mov r12d, eax           ; new x
    jmp .check_left
.right_next:
    inc ecx
    jmp .right_loop
.right_done:

.check_left:
    ; --- Check LEFT edge ---
    mov eax, r12d           ; left x (possibly already adjusted)
    mov ecx, TILE_SIZE
    test eax, eax
    js .left_snap_zero
    cdq
    idiv ecx
    mov r8d, eax            ; r8 = left col

    ; rows
    mov eax, r13d
    cdq
    idiv ecx
    mov r9d, eax
    mov eax, r13d
    add eax, ebx
    dec eax
    cdq
    idiv ecx
    mov r10d, eax

    mov ecx, r9d
.left_loop:
    cmp ecx, r10d
    jg .left_done
    push rcx
    mov edi, r8d
    mov esi, ecx
    call get_tile
    pop rcx
    cmp al, TILE_SOLID
    jne .left_next
    ; Collision on left — snap new x to (left_col + 1) * TILE_SIZE
    mov eax, r8d
    inc eax
    imul eax, TILE_SIZE
    mov r12d, eax
    jmp .left_done
.left_next:
    inc ecx
    jmp .left_loop
.left_done:

    mov eax, r12d
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.left_snap_zero:
    xor r12d, r12d
    mov eax, r12d
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret


; ============================================================================
; check_tile_collision_y(x, y_new, w, h, vy) -> rax: adjusted y
; If vy > 0 (falling): check bottom; also allow landing on PLATFORM tiles
;                      only if the previous bottom was above the platform top.
; If vy < 0 (rising): check top; only solid tiles block.
; We pass y_old via stack [rbp+16].
; Args: edi=x, esi=y_new, edx=w, ecx=h, r8d=vy (fixed-point), [rbp+16]=y_old
; Returns: eax = resolved y. Sets on_ground flag via r11d (1 if landed).
; Contract: r11d = 1 if landed on floor/platform this call, else r11d unchanged.
; ============================================================================
check_tile_collision_y:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8              ; align

    mov r12d, edi           ; x
    mov r13d, esi           ; y_new
    mov r14d, edx           ; w
    mov ebx, ecx            ; h
    mov r15d, r8d           ; vy (sign-only)

    ; y_old from stack (caller pushed it)
    mov eax, dword [rbp+16]
    mov r8d, eax            ; r8d = y_old

    ; If moving down (vy > 0), check bottom collision
    test r15d, r15d
    jle .check_top_only

    ; --- Bottom check ---
    ; bottom row = (y_new + h - 1) / TILE_SIZE
    mov eax, r13d
    add eax, ebx
    dec eax
    mov ecx, TILE_SIZE
    cdq
    idiv ecx
    mov r9d, eax            ; r9 = bottom row

    ; old bottom row
    mov eax, r8d
    add eax, ebx
    dec eax
    cdq
    idiv ecx
    mov r10d, eax           ; r10 = old bottom row

    ; left col, right col
    mov eax, r12d
    test eax, eax
    jns .bot_lc_ok
    xor eax, eax
.bot_lc_ok:
    cdq
    idiv ecx
    mov esi, eax            ; esi = left col (reusing)

    mov eax, r12d
    add eax, r14d
    dec eax
    cdq
    idiv ecx
    mov edi, eax            ; edi = right col

.bot_col_loop:
    cmp esi, edi
    jg .bot_done
    ; Check tile at (col=esi, row=r9)
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11
    mov edi, esi
    mov esi, r9d
    call get_tile
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi

    cmp al, TILE_SOLID
    je .bot_solid_hit
    cmp al, TILE_PLATFORM
    je .bot_platform_check
    jmp .bot_col_next

.bot_platform_check:
    ; Only collide if old bottom row < current row (we came from above)
    cmp r10d, r9d
    jge .bot_col_next
    ; Also only collide if key_down is NOT pressed (allow drop-through)
    ; For simplicity: snap as if solid
    jmp .bot_snap

.bot_solid_hit:
.bot_snap:
    ; Snap y_new so (y_new + h) = row * TILE_SIZE
    mov eax, r9d
    imul eax, TILE_SIZE
    sub eax, ebx
    mov r13d, eax
    mov r11d, 1             ; landed
    jmp .bot_done

.bot_col_next:
    inc esi
    jmp .bot_col_loop

.bot_done:
    jmp .finalize

.check_top_only:
    test r15d, r15d
    jz .finalize            ; vy == 0: no vertical movement

    ; --- Moving up, check top collision ---
    ; top row = y_new / TILE_SIZE
    mov eax, r13d
    test eax, eax
    js .top_snap_to_zero
    mov ecx, TILE_SIZE
    cdq
    idiv ecx
    mov r9d, eax            ; top row

    ; left col, right col
    mov eax, r12d
    test eax, eax
    jns .top_lc_ok
    xor eax, eax
.top_lc_ok:
    cdq
    idiv ecx
    mov esi, eax

    mov eax, r12d
    add eax, r14d
    dec eax
    cdq
    idiv ecx
    mov edi, eax

.top_col_loop:
    cmp esi, edi
    jg .finalize
    push rdi
    push rsi
    push r9
    mov edi, esi
    mov esi, r9d
    call get_tile
    pop r9
    pop rsi
    pop rdi

    cmp al, TILE_SOLID
    jne .top_col_next
    ; Snap y_new to (row+1) * TILE_SIZE
    mov eax, r9d
    inc eax
    imul eax, TILE_SIZE
    mov r13d, eax
    jmp .finalize

.top_col_next:
    inc esi
    jmp .top_col_loop

.top_snap_to_zero:
    xor r13d, r13d

.finalize:
    mov eax, r13d
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
