; ============================================================================
; Hollow Knight Assembly Demo — Player Logic
; Movement, jumping, gravity, attack, dash, animation, collision response
; ============================================================================

%include "constants.inc"

; Externals from main.asm
extern player_x, player_y, player_vx, player_vy
extern player_hp, player_facing, player_on_ground
extern player_state, player_anim_frame, player_anim_timer
extern player_invuln_timer
extern player_dash_timer, player_dash_cooldown
extern player_slash_active, player_slash_timer, player_slash_cooldown
extern player_slash_x, player_slash_y
extern key_left, key_right, key_up, key_down
extern key_jump, key_attack, key_dash
extern key_jump_pressed, key_attack_pressed, key_dash_pressed
extern game_state

; Externals from collision.asm
extern check_tile_collision_x
extern check_tile_collision_y
extern get_tile

global update_player
global respawn_player

section .text

; ============================================================================
; update_player — main player logic run each frame
; ============================================================================
update_player:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8              ; align

    ; ---- Decrement timers ----
    mov eax, [rel player_invuln_timer]
    test eax, eax
    jz .inv_done
    dec eax
    mov [rel player_invuln_timer], eax
.inv_done:

    mov eax, [rel player_dash_timer]
    test eax, eax
    jz .dt_done
    dec eax
    mov [rel player_dash_timer], eax
.dt_done:

    mov eax, [rel player_dash_cooldown]
    test eax, eax
    jz .dc_done
    dec eax
    mov [rel player_dash_cooldown], eax
.dc_done:

    mov eax, [rel player_slash_timer]
    test eax, eax
    jz .st_done
    dec eax
    mov [rel player_slash_timer], eax
    test eax, eax
    jnz .st_done
    mov dword [rel player_slash_active], 0
.st_done:

    mov eax, [rel player_slash_cooldown]
    test eax, eax
    jz .sc_done
    dec eax
    mov [rel player_slash_cooldown], eax
.sc_done:

    ; ---- Handle attack input (Left Click) ----
    cmp byte [rel key_attack_pressed], 0
    je .no_attack
    cmp dword [rel player_slash_cooldown], 0
    jne .no_attack
    mov dword [rel player_slash_active], 1
    mov dword [rel player_slash_timer], SLASH_DURATION
    mov dword [rel player_slash_cooldown], SLASH_COOLDOWN
    ; Position slash hitbox relative to player facing
    mov eax, [rel player_x]
    sar eax, FIXED_SHIFT            ; integer logical x
    cmp dword [rel player_facing], 0
    je .atk_right
    ; facing left: slash at x - SLASH_W
    sub eax, SLASH_W - 4
    jmp .atk_ydone
.atk_right:
    ; facing right: slash at x + KNIGHT_W - 4 (so it starts at knight's weapon arm)
    add eax, KNIGHT_W - 4
.atk_ydone:
    mov [rel player_slash_x], eax
    mov eax, [rel player_y]
    sar eax, FIXED_SHIFT
    add eax, 4                      ; roughly mid-body
    mov [rel player_slash_y], eax
.no_attack:

    ; ---- Handle dash input (Right Click) ----
    cmp byte [rel key_dash_pressed], 0
    je .no_dash
    cmp dword [rel player_dash_cooldown], 0
    jne .no_dash
    mov dword [rel player_dash_timer], DASH_DURATION
    mov dword [rel player_dash_cooldown], DASH_COOLDOWN
    ; Grant invuln during dash
    mov eax, [rel player_invuln_timer]
    cmp eax, DASH_DURATION
    jge .no_dash
    mov dword [rel player_invuln_timer], DASH_DURATION
.no_dash:

    ; ---- Compute horizontal velocity ----
    ; If dashing: vx = facing_direction * DASH_SPEED, skip normal movement
    cmp dword [rel player_dash_timer], 0
    je .normal_move

    cmp dword [rel player_facing], 0
    je .dash_right
    mov dword [rel player_vx], -DASH_SPEED
    jmp .move_x
.dash_right:
    mov dword [rel player_vx], DASH_SPEED
    jmp .move_x

.normal_move:
    xor r12d, r12d                  ; moving flag
    cmp byte [rel key_left], 0
    je .nm_check_right
    mov dword [rel player_vx], -MOVE_SPEED
    mov dword [rel player_facing], 1
    mov r12d, 1
    jmp .nm_jump
.nm_check_right:
    cmp byte [rel key_right], 0
    je .nm_stop
    mov dword [rel player_vx], MOVE_SPEED
    mov dword [rel player_facing], 0
    mov r12d, 1
    jmp .nm_jump
.nm_stop:
    mov dword [rel player_vx], 0

.nm_jump:
    ; Jump: only if on ground and jump pressed
    cmp byte [rel key_jump_pressed], 0
    je .apply_gravity
    cmp dword [rel player_on_ground], 0
    je .apply_gravity
    mov dword [rel player_vy], JUMP_VELOCITY
    mov dword [rel player_on_ground], 0

.apply_gravity:
    ; vy += GRAVITY
    mov eax, [rel player_vy]
    add eax, GRAVITY
    ; Cap at terminal velocity
    cmp eax, MAX_FALL_SPEED
    jle .gr_ok
    mov eax, MAX_FALL_SPEED
.gr_ok:
    mov [rel player_vy], eax

    ; Cut jump short if jump key released while going up (variable jump height)
    cmp byte [rel key_jump], 0
    jne .move_x
    mov eax, [rel player_vy]
    test eax, eax
    jns .move_x
    ; If vy is negative (going up) and jump released, halve the upward speed
    ; But only apply this once — simple approach: reduce vy by scaling
    ; (This is a common platformer trick)
    sar eax, 1
    ; Only if still negative (going up) apply
    cmp eax, 0
    jge .move_x
    mov [rel player_vy], eax

.move_x:
    ; ---- Apply horizontal movement ----
    ; player_x += vx; convert to integer, resolve collision, convert back
    mov eax, [rel player_x]
    add eax, [rel player_vx]
    mov [rel player_x], eax

    ; Integer logical x = player_x >> FIXED_SHIFT
    mov edi, eax
    sar edi, FIXED_SHIFT
    mov eax, [rel player_y]
    sar eax, FIXED_SHIFT
    mov esi, eax
    ; Apply hitbox offset
    add edi, KNIGHT_HB_OX
    add esi, KNIGHT_HB_OY
    mov edx, KNIGHT_HITBOX_W
    mov ecx, KNIGHT_HITBOX_H
    call check_tile_collision_x
    ; eax = resolved hitbox x; sub hitbox offset back and store as fixed
    sub eax, KNIGHT_HB_OX
    shl eax, FIXED_SHIFT
    mov [rel player_x], eax

    ; ---- Apply vertical movement ----
    mov eax, [rel player_y]
    mov r13d, eax                   ; save old player_y (fixed-point)
    add eax, [rel player_vy]
    mov [rel player_y], eax

    ; Old y integer with hitbox offset
    mov eax, r13d
    sar eax, FIXED_SHIFT
    add eax, KNIGHT_HB_OY
    mov r14d, eax                   ; old integer y with hitbox offset

    ; New y integer with hitbox offset
    mov edi, [rel player_x]
    sar edi, FIXED_SHIFT
    add edi, KNIGHT_HB_OX

    mov esi, [rel player_y]
    sar esi, FIXED_SHIFT
    add esi, KNIGHT_HB_OY

    mov edx, KNIGHT_HITBOX_W
    mov ecx, KNIGHT_HITBOX_H
    mov r8d, [rel player_vy]        ; vy sign

    ; Push y_old onto stack for collision func
    push r14
    call check_tile_collision_y
    add rsp, 8

    ; Resolved y (integer logical with hitbox offset)
    sub eax, KNIGHT_HB_OY
    shl eax, FIXED_SHIFT
    mov [rel player_y], eax

    ; ---- Ground probe: check tile directly below feet ----
    mov eax, [rel player_y]
    sar eax, FIXED_SHIFT
    add eax, KNIGHT_HB_OY + KNIGHT_HITBOX_H
    cdq
    mov ecx, TILE_SIZE
    idiv ecx
    mov r12d, eax

    mov eax, [rel player_x]
    sar eax, FIXED_SHIFT
    add eax, KNIGHT_HB_OX + (KNIGHT_HITBOX_W / 2)
    cdq
    idiv ecx
    mov edi, eax
    mov esi, r12d
    call get_tile

    cmp al, TILE_SOLID
    je .ground_solid
    cmp al, TILE_PLATFORM
    jne .airborne
    cmp dword [rel player_vy], 0
    jl .airborne
.ground_solid:
    mov dword [rel player_on_ground], 1
    mov dword [rel player_vy], 0
    jmp .update_anim
.airborne:
    mov dword [rel player_on_ground], 0

.update_anim:
    ; ---- Update player state for animation ----
    cmp dword [rel player_slash_active], 0
    jne .state_attack
    cmp dword [rel player_dash_timer], 0
    jne .state_dash
    cmp dword [rel player_on_ground], 0
    je .state_air
    ; on ground: idle or run
    cmp dword [rel player_vx], 0
    jne .state_run
    mov dword [rel player_state], STATE_IDLE
    jmp .anim_done
.state_run:
    mov dword [rel player_state], STATE_RUN
    jmp .anim_done
.state_air:
    mov eax, [rel player_vy]
    test eax, eax
    jns .state_fall
    mov dword [rel player_state], STATE_JUMP
    jmp .anim_done
.state_fall:
    mov dword [rel player_state], STATE_FALL
    jmp .anim_done
.state_attack:
    mov dword [rel player_state], STATE_ATTACK
    jmp .anim_done
.state_dash:
    mov dword [rel player_state], STATE_DASH

.anim_done:
    ; Advance animation frame based on state
    mov eax, [rel player_anim_timer]
    inc eax
    mov [rel player_anim_timer], eax
    cmp eax, 8
    jl .no_anim_tick
    mov dword [rel player_anim_timer], 0
    mov eax, [rel player_anim_frame]
    inc eax
    and eax, 1              ; 2-frame run cycle
    mov [rel player_anim_frame], eax
.no_anim_tick:

    ; ---- Clamp player to window bounds ----
    mov eax, [rel player_x]
    sar eax, FIXED_SHIFT
    cmp eax, 0
    jge .xl_ok
    mov dword [rel player_x], 0
.xl_ok:
    mov eax, [rel player_x]
    sar eax, FIXED_SHIFT
    cmp eax, LOGICAL_W - KNIGHT_W
    jle .xr_ok
    mov eax, LOGICAL_W - KNIGHT_W
    shl eax, FIXED_SHIFT
    mov [rel player_x], eax
.xr_ok:

    ; If player fell below world, kill
    mov eax, [rel player_y]
    sar eax, FIXED_SHIFT
    cmp eax, LOGICAL_H + 32
    jl .end_update
    ; dead
    mov dword [rel player_hp], 0
    call respawn_player

.end_update:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret


; ============================================================================
; respawn_player — reset player to spawn with full HP
; ============================================================================
respawn_player:
    mov dword [rel player_x], 40 * 256
    mov dword [rel player_y], 180 * 256
    mov dword [rel player_vx], 0
    mov dword [rel player_vy], 0
    mov dword [rel player_hp], MAX_HP
    mov dword [rel player_facing], 0
    mov dword [rel player_on_ground], 0
    mov dword [rel player_state], STATE_IDLE
    mov dword [rel player_invuln_timer], 120
    mov dword [rel player_dash_timer], 0
    mov dword [rel player_dash_cooldown], 0
    mov dword [rel player_slash_active], 0
    mov dword [rel player_slash_timer], 0
    mov dword [rel player_slash_cooldown], 0
    ret
